param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$AppDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class FactorGolfClubSelectorCalNative {
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
 public struct POINT { public int X; public int Y; }
 public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$out=Join-Path $Root 'UltimateCoach';try{New-Item -ItemType Directory -Path $out -Force|Out-Null}catch{}
$localStatus=Join-Path $AppDir 'club_selector_calibration_status.json'
$legacyStatus=Join-Path $out 'club_selector_calibration_status.json'
$configPath=Join-Path $AppDir 'config.json';$defaultPath=Join-Path $AppDir 'config.default.json'
$logPath=Join-Path $AppDir 'club_selector_calibration.log'
function Log([string]$m){try{Add-Content -LiteralPath $logPath -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+' '+$m) -Encoding UTF8}catch{}}
function Save-Status([string]$state,[string]$msg,$extra=$null){
 $o=[ordered]@{state=$state;message=$msg;updated=(Get-Date).ToString('o')};if($extra){foreach($p in $extra.PSObject.Properties){$o[$p.Name]=$p.Value}}
 $json=$o|ConvertTo-Json -Depth 6
 try{$json|Set-Content $localStatus -Encoding UTF8}catch{}
 try{$json|Set-Content $legacyStatus -Encoding UTF8}catch{}
 Log ($state+': '+$msg)
}
function Fail([string]$msg,[int]$code){Save-Status 'failed' $msg;try{[System.Windows.MessageBox]::Show($msg,'Factor Golf Club Selector Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)|Out-Null}catch{};exit $code}
function Get-GSPro {Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1}
function Get-Rect($p){$r=New-Object FactorGolfClubSelectorCalNative+RECT;if([FactorGolfClubSelectorCalNative]::GetWindowRect($p.MainWindowHandle,[ref]$r)){return [pscustomobject]@{Left=$r.Left;Top=$r.Top;Right=$r.Right;Bottom=$r.Bottom;Width=($r.Right-$r.Left);Height=($r.Bottom-$r.Top)}};return $null}
function In-Rect($pt,$r){return ($pt.X-ge$r.Left -and $pt.X-lt$r.Right -and $pt.Y-ge$r.Top -and $pt.Y-lt$r.Bottom)}
function Wait-Click($p,[int]$timeoutSec=90){
 $deadline=(Get-Date).AddSeconds($timeoutSec);$was=$false
 while((Get-Date)-lt$deadline){
  Start-Sleep -Milliseconds 12
  $down=(([FactorGolfClubSelectorCalNative]::GetAsyncKeyState(0x01)-band 0x8000)-ne0)
  if($down -and -not$was){
   $pt=New-Object FactorGolfClubSelectorCalNative+POINT;[FactorGolfClubSelectorCalNative]::GetCursorPos([ref]$pt)|Out-Null
   $r=Get-Rect $p
   if($r -and (In-Rect $pt $r)){
    while((([FactorGolfClubSelectorCalNative]::GetAsyncKeyState(0x01)-band 0x8000)-ne0)){Start-Sleep -Milliseconds 12}
    return [pscustomobject]@{X=$pt.X;Y=$pt.Y;Rect=$r}
   }
  }
  $was=$down
 }
 return $null
}
try{
 Log 'Calibration worker started.'
 $p=Get-GSPro;if(-not$p){Fail 'GSPro is not open. Open GSPro to the Practice Range and run Club Selector calibration again.' 2}
 Save-Status 'armed' 'Calibration armed. Click OK, then click directly on the CURRENT CLUB NAME / CLUB SELECTOR inside GSPro.'
 [System.Windows.MessageBox]::Show('Calibration is armed. After you click OK, Factor Golf will bring GSPro forward. Click directly on the CURRENT CLUB NAME / CLUB SELECTOR in GSPro.','Factor Golf Club Selector Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null
 try{[FactorGolfClubSelectorCalNative]::ShowWindowAsync($p.MainWindowHandle,9)|Out-Null;Start-Sleep -Milliseconds 250;[FactorGolfClubSelectorCalNative]::SetForegroundWindow($p.MainWindowHandle)|Out-Null}catch{}
 Save-Status 'waiting_selector' 'Waiting for your click on the GSPro club selector...'
 try{[System.Media.SystemSounds]::Asterisk.Play()}catch{}
 $c=Wait-Click $p 90;if(-not$c){Fail 'Timed out waiting for a click inside the GSPro window. Run calibration again and click directly on the club selector.' 3}
 if($c.Rect.Width -le 0 -or $c.Rect.Height -le 0){Fail 'GSPro window size could not be read during calibration.' 4}
 $x=($c.X-$c.Rect.Left)/[double]$c.Rect.Width;$y=($c.Y-$c.Rect.Top)/[double]$c.Rect.Height
 if($x-lt0 -or $x-gt1 -or $y-lt0 -or $y-gt1){Fail 'Captured selector click was outside the GSPro window.' 5}
 $cfg=if(Test-Path $configPath){Get-Content $configPath -Raw|ConvertFrom-Json}else{Get-Content $defaultPath -Raw|ConvertFrom-Json}
 foreach($kv in @(@('ClubSelectorX',[math]::Round($x,6)),@('ClubSelectorY',[math]::Round($y,6)),@('ClubSelectorCalibrated',$true),@('ClubSelectorCalibrationDate',(Get-Date).ToString('o')),@('ClubSelectorCropWidthRatio',0.28),@('ClubSelectorCropHeightRatio',0.16))){if($cfg.PSObject.Properties.Name -contains $kv[0]){$cfg.($kv[0])=$kv[1]}else{$cfg|Add-Member -NotePropertyName $kv[0] -NotePropertyValue $kv[1]}}
 $cfg|ConvertTo-Json -Depth 8|Set-Content $configPath -Encoding UTF8
 Save-Status 'success' 'Club Selector saved successfully. Return to Settings and click TEST CLUB DETECTION.' ([pscustomobject]@{selector_x=$x;selector_y=$y;click_x=$c.X;click_y=$c.Y})
 [System.Windows.MessageBox]::Show('Club Selector saved successfully. Return to Factor Golf Settings and click TEST CLUB DETECTION.','Factor Golf Club Selector Calibration',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)|Out-Null
 exit 0
}catch{
 Fail ('Club Selector calibration failed: '+$_.Exception.Message) 10
}
