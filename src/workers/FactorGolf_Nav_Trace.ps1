# Read-only navigation instrumentation. No focus, cursor, input or DPI changes here.
function Initialize-FGNavNative {
 if('FGNavObservation' -as [type]){return}
 Add-Type -ErrorAction Stop @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class FGNavObservation {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint id);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
 [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int size);
 public struct RECT { public int Left,Top,Right,Bottom; }
}
'@ | Out-Null
}
function Get-FGWindowObservation([IntPtr]$Handle){
 if($Handle -eq [IntPtr]::Zero){return $null}
 $result=[ordered]@{handle=$Handle.ToInt64()}
 try{
  [uint32]$owner=0;[void][FGNavObservation]::GetWindowThreadProcessId($Handle,[ref]$owner)
  $title=New-Object Text.StringBuilder 512;[void][FGNavObservation]::GetWindowText($Handle,$title,512)
  $result.process_id=$owner;$result.title=$title.ToString()
  $r=New-Object FGNavObservation+RECT
  if([FGNavObservation]::GetWindowRect($Handle,[ref]$r)){$result.reported_bounds=$r}
  $physical=New-Object FGNavObservation+RECT
  if([FGNavObservation]::DwmGetWindowAttribute($Handle,9,[ref]$physical,16) -eq 0){$result.physical_visible_bounds=$physical}
  # DWM visible bounds exclude invisible resize borders; they are not an exact
  # interchangeable replacement for the navigator's GetWindowRect coordinates.
  $result.window_dpi=[FGNavObservation]::GetDpiForWindow($Handle)
  $result.window_awareness=[FGNavObservation]::GetAwarenessFromDpiAwarenessContext([FGNavObservation]::GetWindowDpiAwarenessContext($Handle))
  $result.caller_awareness=[FGNavObservation]::GetAwarenessFromDpiAwarenessContext([FGNavObservation]::GetThreadDpiAwarenessContext())
 }catch{$result.error=$_.Exception.Message}
 return [pscustomobject]$result
}
function Write-FGNavEvent([string]$Directory,[string]$RunId,[int]$Sequence,[string]$Kind,$Data,$Foreground,$Target){
 $row=[ordered]@{run_id=$RunId;sequence=$Sequence;utc=[datetime]::UtcNow.ToString('o');kind=$Kind;data=$Data;foreground=$Foreground;target=$Target}
 $line=$row|ConvertTo-Json -Depth 12 -Compress
 [IO.File]::AppendAllText((Join-Path $Directory 'events.jsonl'),$line+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
}
function Send-FGNavTrace([string]$Kind,$Data){
 try{
  if(-not$script:FGNavRun){return}
  $script:FGNavSequence++
  $fg=Get-FGWindowObservation ([FGNavObservation]::GetForegroundWindow())
  $gp=Get-GSProProcess;$target=$null
  if($gp){$target=Get-FGWindowObservation $gp.MainWindowHandle}
  Write-FGNavEvent $script:FGNavRun.directory $script:FGNavRun.id $script:FGNavSequence $Kind $Data $fg $target
 }catch{} # Evidence failure must not alter navigation outcomes.
}
function Start-FGNavTrace([string]$AppDirectory,[string]$RuntimeRoot){
 try{
  Initialize-FGNavNative
  $id=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
  $dir=Join-Path $AppDirectory ('diagnostics\navigation\'+$id)
  New-Item -ItemType Directory $dir -Force -ErrorAction Stop|Out-Null
  $script:FGNavRun=[pscustomobject]@{id=$id;directory=$dir};$script:FGNavSequence=0
  $hashes=[ordered]@{}
  foreach($name in @('Halliseum_Control_Center.ps1','workers\Halliseum_Range_Nav.ps1','workers\FactorGolf_Nav_Trace.ps1','workers\FactorGolf_Nav_Recorder.ps1')){
   $hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $AppDirectory $name) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
  }
  $build=$null;try{$build=Get-Content (Join-Path $AppDirectory 'candidate_build.json') -Raw -ErrorAction Stop|ConvertFrom-Json}catch{}
  [ordered]@{run_id=$id;started_utc=[datetime]::UtcNow.ToString('o');navigator_pid=$PID;app_version=(Get-Content (Join-Path $AppDirectory 'app_version.txt') -Raw).Trim();build=$build;actual_hashes=$hashes}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $dir 'run.json') -Encoding UTF8
  $recorder=Join-Path $AppDirectory 'workers\FactorGolf_Nav_Recorder.ps1'
  Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$recorder`" -AppDir `"$AppDirectory`" -Root `"$RuntimeRoot`" -RunDir `"$dir`" -NavigatorPid $PID" -WindowStyle Hidden -ErrorAction Stop|Out-Null
 }catch{
  try{Add-Content (Join-Path $AppDirectory 'navigation_diagnostic_errors.log') $_.Exception.Message}catch{}
 }
}
