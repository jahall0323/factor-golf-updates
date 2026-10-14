param([string]$AppDir,[string]$Root,[string]$RunDir,[int]$NavigatorPid,[int]$DurationSeconds=900)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'FactorGolf_Nav_Trace.ps1')
Initialize-FGNavNative
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class FGNavCapture {
 [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
 public struct RECT {public int Left,Top,Right,Bottom;}
 public static RECT Capture(IntPtr h, string path) {
  // Scope physical coordinates to this recorder's thread, never the navigator.
  IntPtr old=SetThreadDpiAwarenessContext(new IntPtr(-4));
  if(old==IntPtr.Zero) throw new InvalidOperationException("Physical DPI context unavailable");
  try {
   RECT r;if(!GetWindowRect(h,out r)) throw new InvalidOperationException("Window bounds unavailable");
   int w=r.Right-r.Left, hgt=r.Bottom-r.Top;
   if(w<1 || hgt<1 || w>10000 || hgt>10000) throw new InvalidOperationException("Invalid capture dimensions");
   using(Bitmap b=new Bitmap(w,hgt)) {
    using(Graphics g=Graphics.FromImage(b)) {g.CopyFromScreen(r.Left,r.Top,0,0,b.Size);}
    b.Save(path,ImageFormat.Jpeg);
   }
   return r;
  } finally {SetThreadDpiAwarenessContext(old);}
 }
}
'@ | Out-Null
$runId=Split-Path $RunDir -Leaf
$cloud=Join-Path $Root ('UltimateCoach\Diagnostics\'+$runId)
$runtime=Join-Path $Root 'UltimateCoach'
$start=Get-Date;$deadline=$start.AddSeconds($DurationSeconds);$nextCapture=$start;$nextStatus=$start
$frame=0;$lastEventCount=0;$lastForeground=0;$observerSequence=0;$navEnded=$null;$seen=@{}
function Sync-Evidence([string]$Path){
 try{New-Item $cloud -ItemType Directory -Force|Out-Null;Copy-Item -LiteralPath $Path -Destination $cloud -Force}catch{}
}
function Record-Observer([string]$Kind,$Data){
 $script:observerSequence++
 $row=[ordered]@{run_id=$runId;sequence=$script:observerSequence;utc=[datetime]::UtcNow.ToString('o');kind=$Kind;data=$Data}
 $row|ConvertTo-Json -Depth 12 -Compress|Add-Content (Join-Path $RunDir 'observer.jsonl') -Encoding UTF8
}
try{
 Sync-Evidence (Join-Path $RunDir 'run.json')
 while((Get-Date) -lt $deadline){
  $now=Get-Date
  $alive=$null -ne (Get-Process -Id $NavigatorPid -ErrorAction SilentlyContinue)
  if(-not$alive -and -not$navEnded){$navEnded=$now}
  $fg=[FGNavObservation]::GetForegroundWindow()
  if($fg.ToInt64() -ne $lastForeground){Record-Observer 'foreground_change' (Get-FGWindowObservation $fg);$lastForeground=$fg.ToInt64()}
  $events=@();try{$events=@(Get-Content (Join-Path $RunDir 'events.jsonl') -ErrorAction Stop)}catch{}
  $changed=$events.Count -ne $lastEventCount;$lastEventCount=$events.Count
  # Capture only the GSPro window, during navigation and five seconds afterward.
  if(($alive -or ($navEnded -and ($now-$navEnded).TotalSeconds -le 5)) -and $frame -lt 160 -and ($changed -or $now -ge $nextCapture)){
   $gp=Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -match '(?i)^GSPro' -and $_.MainWindowHandle -ne 0}|Select-Object -First 1
   if($gp){
    $frame++;$file=('frame_{0:D4}.jpg' -f $frame);$path=Join-Path $RunDir $file
    $at=[datetime]::UtcNow.ToString('o')
    try{$bounds=[FGNavCapture]::Capture($gp.MainWindowHandle,$path);Record-Observer 'screenshot' @{file=$file;capture_started_utc=$at;latest_event_count=$events.Count;physical_window_bounds=$bounds;window=(Get-FGWindowObservation $gp.MainWindowHandle)};Sync-Evidence $path}
    catch{Record-Observer 'screenshot_error' @{message=$_.Exception.Message}}
   }
   $nextCapture=$now.AddSeconds(2)
  }
  if($now -ge $nextStatus){
   foreach($name in @('range_nav_status.json','range_nav_debug.json','range_nav_ocr.txt','worker_launch_status.log','club_cheat_status.json','club_detection_debug.json','club_detection_events.log','club_selector_latest.png','coach_runtime.json','voice_recognition_status.json','latest_followup.json')){
    $path=Join-Path $runtime $name
    if(Test-Path -LiteralPath $path){
     $item=Get-Item -LiteralPath $path
     if($item.LastWriteTime -ge $start.AddSeconds(-5) -and $item.Length -le 8MB){
      $sig="$($item.LastWriteTimeUtc.Ticks):$($item.Length)"
      if($seen[$name] -ne $sig){
       $snapshot=Join-Path $RunDir ((Get-Date -Format 'HHmmssfff')+'_'+$name)
       try{Copy-Item -LiteralPath $path -Destination $snapshot -Force;Sync-Evidence $snapshot;$seen[$name]=$sig}catch{}
      }
     }
    }
   }
   foreach($file in @('events.jsonl','observer.jsonl')){if(Test-Path (Join-Path $RunDir $file)){Sync-Evidence (Join-Path $RunDir $file)}}
   $nextStatus=$now.AddSeconds(5)
  }
  Start-Sleep -Milliseconds 250
 }
 Record-Observer 'recorder_complete' @{duration_seconds=$DurationSeconds;frames=$frame}
}catch{try{Record-Observer 'recorder_error' @{message=$_.Exception.Message}}catch{}}
finally{foreach($file in @('events.jsonl','observer.jsonl')){if(Test-Path (Join-Path $RunDir $file)){Sync-Evidence (Join-Path $RunDir $file)}}}
