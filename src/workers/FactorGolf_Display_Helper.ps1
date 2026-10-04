# Factor Golf display discovery/routing helper.
# Uses Windows display-device + EDID/PnP information so UI choices are based on the real monitor name,
# not the arbitrary Screen.AllScreens order.
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

if(-not ('FactorGolfDisplayNative' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FactorGolfDisplayNative {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DISPLAY_DEVICE {
    public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DeviceName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceString;
    public int StateFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceID;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceKey;
  }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DEVMODE {
    private const int CCHDEVICENAME = 32;
    private const int CCHFORMNAME = 32;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=CCHDEVICENAME)] public string dmDeviceName;
    public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
    public int dmFields; public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
    public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=CCHFORMNAME)] public string dmFormName;
    public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight; public int dmDisplayFlags; public int dmDisplayFrequency;
    public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType; public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
  }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
'@ -ErrorAction SilentlyContinue
}

function Convert-FGEdidText($bytes){
  try{
    if($null -eq $bytes){return ''}
    $vals=@($bytes|Where-Object{[int]$_ -gt 0})
    if($vals.Count -eq 0){return ''}
    return ([Text.Encoding]::ASCII.GetString([byte[]]$vals)).Trim([char]0).Trim()
  }catch{return ''}
}

function Get-FGMonitorCatalog{
  $screens=@([System.Windows.Forms.Screen]::AllScreens)
  $wmi=@();$pnp=@()
  try{$wmi=@(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop)}catch{try{$wmi=@(Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction Stop)}catch{}}
  try{$pnp=@(Get-CimInstance -ClassName Win32_PnPEntity -Filter "PNPClass='Monitor'" -ErrorAction Stop)}catch{}
  $result=@()
  for($i=0;$i -lt $screens.Count;$i++){
    $s=$screens[$i]
    $monitorId='';$monitorString='';$hwid='';$friendly='';$serial='';$edidInstance=''
    try{
      $dd=New-Object FactorGolfDisplayNative+DISPLAY_DEVICE;$dd.cb=[Runtime.InteropServices.Marshal]::SizeOf([type]'FactorGolfDisplayNative+DISPLAY_DEVICE')
      if([FactorGolfDisplayNative]::EnumDisplayDevices($s.DeviceName,0,[ref]$dd,0)){
        $monitorId=[string]$dd.DeviceID;$monitorString=[string]$dd.DeviceString
        if($monitorId -match '^[^\\]+\\([^\\]+)\\'){$hwid=$matches[1]}
      }
    }catch{}
    if($monitorId){
      try{
        $pe=$pnp|Where-Object{[string]$_.PNPDeviceID -ieq $monitorId}|Select-Object -First 1
        if($pe -and [string]$pe.Name -and [string]$pe.Name -notmatch 'Generic.*Monitor'){$friendly=[string]$pe.Name}
      }catch{}
    }
    if($hwid){
      try{
        $wm=$wmi|Where-Object{[string]$_.InstanceName -imatch ('^DISPLAY\\'+[regex]::Escape($hwid)+'\\')}|Select-Object -First 1
        if($wm){
          $edidInstance=[string]$wm.InstanceName
          $edidName=Convert-FGEdidText $wm.UserFriendlyName
          $serial=Convert-FGEdidText $wm.SerialNumberID
          if($edidName){$friendly=$edidName}
        }
      }catch{}
    }
    if(-not$friendly -and $monitorString -and $monitorString -notmatch 'Generic.*Monitor'){$friendly=$monitorString}
    if(-not$friendly){$friendly=$s.DeviceName.Replace('\\.\','')}
    $pw=$s.Bounds.Width;$ph=$s.Bounds.Height;$hz=0
    try{
      $dm=New-Object FactorGolfDisplayNative+DEVMODE;$dm.dmSize=[Runtime.InteropServices.Marshal]::SizeOf([type]'FactorGolfDisplayNative+DEVMODE')
      if([FactorGolfDisplayNative]::EnumDisplaySettings($s.DeviceName,-1,[ref]$dm)){$pw=[int]$dm.dmPelsWidth;$ph=[int]$dm.dmPelsHeight;$hz=[int]$dm.dmDisplayFrequency}
    }catch{}
    $stableKey=''
    if($monitorId){$stableKey='PNP|'+$monitorId.ToUpperInvariant()}
    elseif($edidInstance){$stableKey='EDID|'+$edidInstance.ToUpperInvariant()}
    else{$stableKey='GDI|'+$s.DeviceName.ToUpperInvariant()}
    $winId=$s.DeviceName.Replace('\\.\','')
    # Keep normal UI labels human-readable and ASCII-only. Windows' low-level DISPLAY# id stays in diagnostics only.
    $suffix=if($s.Primary){' | Primary'}else{''}
    $label=('{0} | {1} x {2}{3}' -f $friendly,$pw,$ph,$suffix)
    $diagnosticsLabel=('{0} | {1} x {2} | {3}{4}' -f $friendly,$pw,$ph,$winId,$suffix)
    $result += [pscustomobject]@{Index=$i;Screen=$s;StableKey=$stableKey;FriendlyName=$friendly;DeviceName=$s.DeviceName;WindowsId=$winId;PhysicalWidth=$pw;PhysicalHeight=$ph;RefreshRate=$hz;Primary=[bool]$s.Primary;MonitorDeviceId=$monitorId;EdidSerial=$serial;Label=$label;DiagnosticsLabel=$diagnosticsLabel}
  }
  return @($result)
}

function Resolve-FGScreen{
  param($Config,[string]$KeyProperty,[string]$IndexProperty,[bool]$AllowAuto=$false)
  $catalog=@(Get-FGMonitorCatalog)
  $key='';try{if($Config.PSObject.Properties.Name -contains $KeyProperty){$key=[string]$Config.$KeyProperty}}catch{}
  if($AllowAuto -and $key -eq 'AUTO'){return $null}
  if($key){$m=$catalog|Where-Object{$_.StableKey -eq $key}|Select-Object -First 1;if($m){return $m.Screen}}
  $idx=0;try{$idx=[int]$Config.$IndexProperty}catch{}
  if($idx -lt 0 -or $idx -ge $catalog.Count){$idx=0}
  if($catalog.Count -gt 0){return $catalog[$idx].Screen}
  return [System.Windows.Forms.Screen]::PrimaryScreen
}

function Show-FGDisplayIdentify{
  param([int]$Seconds=5)
  $catalog=@(Get-FGMonitorCatalog);$forms=@()
  foreach($m in $catalog){
    try{
      $f=New-Object System.Windows.Forms.Form
      $f.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::None;$f.StartPosition='Manual';$f.Bounds=$m.Screen.Bounds;$f.TopMost=$true;$f.ShowInTaskbar=$false;$f.BackColor=[System.Drawing.Color]::FromArgb(7,16,12);$f.Opacity=.94
      $lab=New-Object System.Windows.Forms.Label;$lab.Dock='Fill';$lab.TextAlign='MiddleCenter';$lab.ForeColor=[System.Drawing.Color]::FromArgb(230,198,91);$lab.BackColor=$f.BackColor;$lab.Font=New-Object System.Drawing.Font('Segoe UI',28,[System.Drawing.FontStyle]::Bold)
      $primaryText=if($m.Primary){"`r`nPrimary display"}else{''}
      $lab.Text="FACTOR GOLF DISPLAY`r`n`r`n$($m.FriendlyName)`r`n$($m.PhysicalWidth) x $($m.PhysicalHeight)$primaryText"
      $f.Controls.Add($lab);$f.Show();$forms+=$f
    }catch{}
  }
  $until=(Get-Date).AddSeconds([math]::Max(2,$Seconds));while((Get-Date) -lt $until){[System.Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 50};foreach($f in $forms){try{$f.Close();$f.Dispose()}catch{}}
}

function Move-FGProcessToConfiguredScreen{
  param([string]$ProcessName,$Config,[string]$KeyProperty,[string]$IndexProperty)
  $key='';try{if($Config.PSObject.Properties.Name -contains $KeyProperty){$key=[string]$Config.$KeyProperty}}catch{}
  if(-not$key -or $key -eq 'AUTO'){return $false}
  try{$p=Get-Process -Name $ProcessName -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1}catch{$p=$null}
  if(-not$p){return $false}
  $screen=Resolve-FGScreen -Config $Config -KeyProperty $KeyProperty -IndexProperty $IndexProperty
  if(-not$screen){return $false}
  try{
    $b=$screen.WorkingArea;$hwnd=[IntPtr]$p.MainWindowHandle
    [FactorGolfDisplayNative]::ShowWindowAsync($hwnd,9)|Out-Null
    Start-Sleep -Milliseconds 120
    [FactorGolfDisplayNative]::SetWindowPos($hwnd,[IntPtr]::Zero,$b.Left,$b.Top,$b.Width,$b.Height,0x0040)|Out-Null
    Start-Sleep -Milliseconds 120
    [FactorGolfDisplayNative]::ShowWindowAsync($hwnd,3)|Out-Null
    return $true
  }catch{return $false}
}

