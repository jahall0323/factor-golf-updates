param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$AppDir)
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class FactorGolfCalNative {
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
 public struct POINT { public int X; public int Y; }
 public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$out=Join-Path $Root 'UltimateCoach';New-Item -ItemType Directory -Path $out -Force|Out-Null
$status=Join-Path $out 'range_calibration_status.json'
$configPath=Join-Path $AppDir 'config.json';$defaultPath=Join-Path $AppDir 'config.default.json'
function Save-Status([string]$state,[string]$msg,$extra=$null){$o=[ordered]@{state=$state;message=$msg;updated=(Get-Date).ToString('o')};if($extra){foreach($p in $extra.PSObject.Properties){$o[$p.Name]=$p.Value}};$o|ConvertTo-Json -Depth 6|Set-Content $status -Encoding UTF8}
function Get-GSPro {Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1}
function Get-Rect($p){try{$r=New-Object FactorGolfCalNative+RECT;if([FactorGolfCalNative]::GetWindowRect($p.MainWindowHandle,[ref]$r)){return [pscustomobject]@{Left=$r.Left;Top=$r.Top;Right=$r.Right;Bottom=$r.Bottom;Width=($r.Right-$r.Left);Height=($r.Bottom-$r.Top)}}}catch{};return $null}
function In-Rect($pt,$r){return ($pt.X-ge$r.Left -and $pt.X-lt$r.Right -and $pt.Y-ge$r.Top -and $pt.Y-lt$r.Bottom)}
function Wait-Click($p,[int]$timeoutSec=60){
 $deadline=(Get-Date).AddSeconds($timeoutSec);$was=$false
 while((Get-Date)-lt$deadline){
  Start-Sleep -Milliseconds 12
  $down=(([FactorGolfCalNative]::GetAsyncKeyState(0x01) -band 0x8000)-ne0)
  if($down -and -not$was){$pt=New-Object FactorGolfCalNative+POINT;[FactorGolfCalNative]::GetCursorPos([ref]$pt)|Out-Null;$r=Get-Rect $p;if($r -and (In-Rect $pt $r)){while((([FactorGolfCalNative]::GetAsyncKeyState(0x01) -band 0x8000)-ne0)){Start-Sleep -Milliseconds 12};return [pscustomobject]@{X=$pt.X;Y=$pt.Y;Rect=$r}}}
  $was=$down
 }
 return $null
}
$p=Get-GSPro;if(-not$p){Save-Status 'failed' 'GSPro is not open. Open GSPro to its main screen and run calibration again.';exit 2}
try{[FactorGolfCalNative]::ShowWindowAsync($p.MainWindowHandle,9)|Out-Null;[FactorGolfCalNative]::SetForegroundWindow($p.MainWindowHandle)|Out-Null}catch{}
Save-Status 'waiting_practice' 'Click PRACTICE inside the GSPro main screen. Factor Golf will record that click.'
$c1=Wait-Click $p 75;if(-not$c1){Save-Status 'failed' 'Timed out waiting for the Practice click.';exit 3}
$x1=($c1.X-$c1.Rect.Left)/[double]$c1.Rect.Width;$y1=($c1.Y-$c1.Rect.Top)/[double]$c1.Rect.Height
Save-Status 'waiting_range' 'Practice captured. Now click GS PRO PRACTICE RANGE. Factor Golf will record that click.' ([pscustomobject]@{practice_x=$x1;practice_y=$y1})
Start-Sleep -Milliseconds 550
$c2=Wait-Click $p 75;if(-not$c2){Save-Status 'failed' 'Timed out waiting for the GS Pro Practice Range click.';exit 4}
$x2=($c2.X-$c2.Rect.Left)/[double]$c2.Rect.Width;$y2=($c2.Y-$c2.Rect.Top)/[double]$c2.Rect.Height
try{$cfg=if(Test-Path $configPath){Get-Content $configPath -Raw|ConvertFrom-Json}else{Get-Content $defaultPath -Raw|ConvertFrom-Json};$cfg.RangeNavHomePracticeX=[math]::Round($x1,6);$cfg.RangeNavHomePracticeY=[math]::Round($y1,6);$cfg.RangeNavPracticeRangeX=[math]::Round($x2,6);$cfg.RangeNavPracticeRangeY=[math]::Round($y2,6);if(-not($cfg.PSObject.Properties.Name -contains 'RangeNavCalibrated')){$cfg|Add-Member -NotePropertyName RangeNavCalibrated -NotePropertyValue $true}else{$cfg.RangeNavCalibrated=$true};if(-not($cfg.PSObject.Properties.Name -contains 'RangeNavCalibrationDate')){$cfg|Add-Member -NotePropertyName RangeNavCalibrationDate -NotePropertyValue (Get-Date).ToString('o')}else{$cfg.RangeNavCalibrationDate=(Get-Date).ToString('o')};$cfg|ConvertTo-Json -Depth 8|Set-Content $configPath -Encoding UTF8}catch{Save-Status 'failed' 'Clicks were captured but Factor Golf could not save the calibration.';exit 5}
Save-Status 'success' 'GSPro range calibration saved. Coach Mode will use these positions relative to the GSPro window on whichever monitor it is on.' ([pscustomobject]@{practice_x=$x1;practice_y=$y1;range_x=$x2;range_y=$y2})
exit 0
