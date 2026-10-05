param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$AppDir,[switch]$TestOnce,[ValidatePattern('^([a-f0-9]{32})?$')][string]$TestRequestId='')
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
try { Add-Type -AssemblyName System.Runtime.WindowsRuntime } catch {}
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class FactorGolfClubKeyNative {
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
 public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$cfgPath=Join-Path $AppDir 'config.json';$defPath=Join-Path $AppDir 'config.default.json'
$config=if(Test-Path $cfgPath){Get-Content $cfgPath -Raw|ConvertFrom-Json}else{Get-Content $defPath -Raw|ConvertFrom-Json}
if(-not [bool]$config.ClubCheatSheetEnabled -and -not$TestOnce){exit}
$out=Join-Path $Root 'UltimateCoach';New-Item -ItemType Directory -Path $out -Force|Out-Null
$status=Join-Path $out 'club_cheat_status.json';$actionPath=Join-Path $out 'coach_action_request.json';$debugPath=Join-Path $out 'club_detection_debug.json';$eventLog=Join-Path $out 'club_detection_events.log';$statePath=Join-Path $out 'session_state.json'
if($TestOnce -and $TestRequestId){$status=Join-Path $AppDir ("club_detection_test_$TestRequestId.json")}
$shown=New-Object 'System.Collections.Generic.HashSet[string]';$script:last='';$script:lastKeyChange=[datetime]::MinValue;$script:nextUiPoll=Get-Date;$script:hasUserClubChange=$false;$script:watchStarted=Get-Date;$script:pendingShortcut='';$script:pendingShortcutAt=[datetime]::MinValue
function Log-Event([string]$m){try{Add-Content $eventLog ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$m) -Encoding UTF8}catch{}}
function Normalize([string]$s){
 if(-not$s){return ''};$u=($s.Trim().ToUpper() -replace '[^A-Z0-9]','')
 switch -Regex($u){'^(DR|D|DRIVER)$'{return 'DR'};'^(3W|W3|3WOOD)$'{return '3W'};'^(5W|W5|5WOOD)$'{return '5W'};'^(7W|W7|7WOOD)$'{return '7W'};'^(2H|H2|2HYBRID)$'{return '2H'};'^(3H|H3|3HYBRID)$'{return '3H'};'^(4H|H4|4HYBRID)$'{return '4H'};'^(5H|H5|5HYBRID)$'{return '5H'};'^(I?([3-9]))$'{return 'I'+$matches[2]};'^([3-9])I$'{return 'I'+$matches[1]};'^(3IRON|4IRON|5IRON|6IRON|7IRON|8IRON|9IRON)$'{return 'I'+$u.Substring(0,1)};'^(PW|PITCHINGWEDGE)$'{return 'PW'};'^(GW|AW|GAPWEDGE|APPROACHWEDGE)$'{return 'GW'};'^(SW|SANDWEDGE)$'{return 'SW'};'^(LW|LOBWEDGE)$'{return 'LW'};'^(PT|PUTTER|PUTT)$'{return 'PT'};default{return ''}}
}
function Get-StateClub{try{if(Test-Path $statePath){$s=Get-Content $statePath -Raw|ConvertFrom-Json;return (Normalize([string]$s.current_club))}}catch{};return ''}
function Get-GSProProcess{Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1}
function Get-GSProWindowRect($proc){
 try{$r=New-Object FactorGolfClubKeyNative+RECT;if([FactorGolfClubKeyNative]::GetWindowRect($proc.MainWindowHandle,[ref]$r)){$w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top;if($w-ge400 -and $h-ge300){return [pscustomobject]@{Left=$r.Left;Top=$r.Top;Width=$w;Height=$h}}}}catch{};return $null
}
$script:AsTaskGeneric=$null
try{$script:AsTaskGeneric=([System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name-eq'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count-eq1 -and $_.GetParameters()[0].ParameterType.Name-eq'IAsyncOperation`1'}|Select-Object -First 1)}catch{}
function Await-WinRt($op,[Type]$resultType){if(-not$script:AsTaskGeneric -or -not$op){return $null};try{$m=$script:AsTaskGeneric.MakeGenericMethod($resultType);$task=$m.Invoke($null,@($op));$task.Wait()|Out-Null;return $task.Result}catch{return $null}}
function Get-ClubOcrLines($proc){
 if(-not$script:AsTaskGeneric){return $null};$wr=Get-GSProWindowRect $proc;if(-not$wr){return $null};$tmp=Join-Path $env:TEMP ("factor_gspro_club_ocr_"+$PID+'.png')
 try{
  $bmp=New-Object System.Drawing.Bitmap -ArgumentList @($wr.Width,$wr.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($wr.Left,$wr.Top,0,0,$bmp.Size);$g.Dispose()
  $scale=1.0;$maxDim=[math]::Max($wr.Width,$wr.Height);if($maxDim-gt2200){$scale=2200.0/$maxDim;$sw=[int]($wr.Width*$scale);$sh=[int]($wr.Height*$scale);$small=New-Object System.Drawing.Bitmap -ArgumentList @($sw,$sh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$sg=[System.Drawing.Graphics]::FromImage($small);$sg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;$sg.DrawImage($bmp,0,0,$sw,$sh);$sg.Dispose();$bmp.Dispose();$bmp=$small}
  $ocrW=$bmp.Width;$ocrH=$bmp.Height;$bmp.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png);$bmp.Dispose();$file=Await-WinRt ([Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]);if(-not$file){return $null};$stream=Await-WinRt ($file.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]);if(-not$stream){return $null};$decoder=Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]);if(-not$decoder){return $null};$soft=Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]);if(-not$soft){return $null};$engine=[Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]::TryCreateFromUserProfileLanguages();if(-not$engine){return $null};$result=Await-WinRt ($engine.RecognizeAsync($soft)) ([Windows.Media.Ocr.OcrResult,Windows.Media.Ocr,ContentType=WindowsRuntime]);if(-not$result){return $null}
  $lines=@();foreach($line in $result.Lines){$words=@($line.Words);if(-not$words.Count){continue};$left=999999;$top=999999;$right=0;$bottom=0;foreach($word in $words){$br=$word.BoundingRect;$left=[math]::Min($left,$br.X);$top=[math]::Min($top,$br.Y);$right=[math]::Max($right,$br.X+$br.Width);$bottom=[math]::Max($bottom,$br.Y+$br.Height)};$lines += [pscustomobject]@{text=[string]$line.Text;left=[double]$left;top=[double]$top;width=[double]($right-$left);height=[double]($bottom-$top);rel_x=[double](($left+$right)/2/$ocrW);rel_y=[double](($top+$bottom)/2/$ocrH)}}
  return $lines
 }catch{return $null}finally{try{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}catch{}}
}
function Extract-ClubFromText([string]$text){
 if(-not$text){return ''};$n=Normalize $text;if($n){return $n}
 $t=$text.ToUpper()
 foreach($pair in @(@('DR','\bDRIVER\b'),@('3W','\b3\s*WOOD\b'),@('5W','\b5\s*WOOD\b'),@('7W','\b7\s*WOOD\b'),@('2H','\b2\s*(HYBRID|H)\b'),@('3H','\b3\s*(HYBRID|H)\b'),@('4H','\b4\s*(HYBRID|H)\b'),@('5H','\b5\s*(HYBRID|H)\b'),@('PW','\b(PW|PITCHING\s*WEDGE)\b'),@('GW','\b(GW|AW|GAP\s*WEDGE|APPROACH\s*WEDGE)\b'),@('SW','\b(SW|SAND\s*WEDGE)\b'),@('LW','\b(LW|LOB\s*WEDGE)\b'),@('PT','\b(PUTTER|PUTT|PT)\b'))){if($t-match$pair[1]){return [string]$pair[0]}}
 if($t-match'\b([3-9])\s*(IRON|I)\b'){return 'I'+$matches[1]};return ''
}
function Get-ClubFromSelectorCrop{
 try{
  if(-not($config.PSObject.Properties.Name -contains 'ClubSelectorCalibrated') -or -not[bool]$config.ClubSelectorCalibrated){return $null}
  $sx=[double]$config.ClubSelectorX;$sy=[double]$config.ClubSelectorY;if($sx-le0 -or $sx-ge1 -or $sy-le0 -or $sy-ge1){return $null}
  $p=Get-GSProProcess;if(-not$p){return $null};$wr=Get-GSProWindowRect $p;if(-not$wr){return $null}
  $rw=0.28;$rh=0.16;try{if([double]$config.ClubSelectorCropWidthRatio-gt0){$rw=[double]$config.ClubSelectorCropWidthRatio};if([double]$config.ClubSelectorCropHeightRatio-gt0){$rh=[double]$config.ClubSelectorCropHeightRatio}}catch{}
  $cw=[int][math]::Max(280,[math]::Min(900,$wr.Width*$rw));$ch=[int][math]::Max(120,[math]::Min(420,$wr.Height*$rh))
  $cx=[int]($wr.Left+($wr.Width*$sx));$cy=[int]($wr.Top+($wr.Height*$sy));$left=[int][math]::Max($wr.Left,[math]::Min($wr.Left+$wr.Width-$cw,$cx-($cw/2)));$top=[int][math]::Max($wr.Top,[math]::Min($wr.Top+$wr.Height-$ch,$cy-($ch/2)))
  $bmp=New-Object System.Drawing.Bitmap -ArgumentList @($cw,$ch,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($left,$top,0,0,$bmp.Size);$g.Dispose()
  $scale=3;$sw=$cw*$scale;$sh=$ch*$scale;$big=New-Object System.Drawing.Bitmap -ArgumentList @($sw,$sh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$bg=[System.Drawing.Graphics]::FromImage($big);$bg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;$bg.DrawImage($bmp,0,0,$sw,$sh);$bg.Dispose();$bmp.Dispose()
  $tmp=Join-Path $env:TEMP ("factor_gspro_selector_"+$PID+'.png');$big.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png);try{$debugImg=Join-Path $out 'club_selector_latest.png';Copy-Item $tmp $debugImg -Force -ErrorAction SilentlyContinue}catch{};$big.Dispose()
  if(-not$script:AsTaskGeneric){return $null};$file=Await-WinRt ([Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]);if(-not$file){return $null};$stream=Await-WinRt ($file.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]);if(-not$stream){return $null};$decoder=Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]);if(-not$decoder){return $null};$soft=Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]);if(-not$soft){return $null};$engine=[Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]::TryCreateFromUserProfileLanguages();if(-not$engine){return $null};$result=Await-WinRt ($engine.RecognizeAsync($soft)) ([Windows.Media.Ocr.OcrResult,Windows.Media.Ocr,ContentType=WindowsRuntime]);if(-not$result){return $null}
  $cand=@();foreach($line in $result.Lines){$txt=[string]$line.Text;$club=Normalize $txt;if($club){$exact=if($txt.Trim()-match'(?i)^(DRIVER|[357]\s*WOOD|[2-7]\s*(HYBRID|H)|[1-9]\s*(IRON|I)|PW|GW|AW|SW|LW|PUTTER|PT|PITCHING\s*WEDGE|GAP\s*WEDGE|APPROACH\s*WEDGE|SAND\s*WEDGE|LOB\s*WEDGE)$'){0}else{1};$cand += [pscustomobject]@{club=$club;text=$txt;score=$exact}}}
  [ordered]@{updated=(Get-Date).ToString('o');selector_x=$sx;selector_y=$sy;crop_left=$left;crop_top=$top;crop_width=$cw;crop_height=$ch;ocr_text=[string]$result.Text;candidates=$cand}|ConvertTo-Json -Depth 6|Set-Content $debugPath -Encoding UTF8
  if(@($cand.club|Sort-Object -Unique).Count -eq 1){$best=$cand[0];return [pscustomobject]@{club=$best.club;time=(Get-Date).ToString('o');source='calibrated GSPro selector OCR'}}
 }catch{}finally{try{if($tmp){Remove-Item $tmp -Force -ErrorAction SilentlyContinue}}catch{}}
 return $null
}
function Get-ClubFromGSProScreen{
 try{$p=Get-GSProProcess;if(-not$p){return $null};$lines=Get-ClubOcrLines $p;if(-not$lines){return $null};$cand=@();foreach($line in $lines){$club=Extract-ClubFromText ([string]$line.text);if(-not$club){continue};$exact=if(([string]$line.text).Trim()-match'(?i)^(DRIVER|[357]\s*WOOD|[2-5]\s*(HYBRID|H)|[3-9]\s*(IRON|I)|PW|GW|AW|SW|LW|PUTTER|PT|PITCHING\s*WEDGE|GAP\s*WEDGE|SAND\s*WEDGE|LOB\s*WEDGE)$'){0}elseif(([string]$line.text)-match'(?i)club'){1}else{2};$cand += [pscustomobject]@{club=$club;text=[string]$line.text;score=$exact;rel_x=$line.rel_x;rel_y=$line.rel_y;height=$line.height}}
  if(-not$cand.Count){return $null};$best=@($cand|Sort-Object score,@{Expression={$_.height};Descending=$true}|Select-Object -First 1)[0];[ordered]@{updated=(Get-Date).ToString('o');ocr_candidates=$cand}|ConvertTo-Json -Depth 6|Set-Content $debugPath -Encoding UTF8;return [pscustomobject]@{club=$best.club;time=(Get-Date).ToString('o');source='GSPro screen OCR'}
 }catch{return $null}
}
function Get-ActualClubNow{ $info=Get-ClubFromSelectorCrop;if($info){return $info};$info=Get-ClubFromGSProUI;if($info){return $info};return $null }
function Sync-ClubSilently($info){if(-not$info -or -not$info.club){return};$club=Normalize([string]$info.club);if(-not$club){return};if($club-ne$script:last){Set-StateClub $club;$script:last=$club;Log-Event ("Silent club sync: $club via $($info.source)")}}
function Get-ClubFromShotLog{
 $log=Join-Path $env:LOCALAPPDATA 'SwingNerdsClip\gspro_shots.log';if(-not(Test-Path $log)){return $null}
 try{$lines=Get-Content $log -Tail 60;for($i=$lines.Count-1;$i-ge0;$i--){if($lines[$i] -match '^\[(?<ts>[0-9\-: .]+)\].*"club"\s*:\s*"([^"]+)"'){ $c=Normalize $matches[2];if($c){$t=[datetime]::Parse($matches['ts']);return [pscustomobject]@{club=$c;time=$t.ToString('o');source='latest GSPro shot'}}}}}catch{};return $null
}
function Get-ClubFromGSProUI{
 try{$p=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1;if(-not$p){return $null};$rootEl=[System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle);if(-not$rootEl){return $null};$candidates=@();$all=$rootEl.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
  foreach($el in $all){try{if($el.Current.IsOffscreen){continue};$name=[string]$el.Current.Name;$aid=[string]$el.Current.AutomationId;$ct=[string]$el.Current.ControlType.ProgrammaticName;$val='';$vp=$null;if($el.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern,[ref]$vp)){$val=[string]$vp.Current.Value};$pick='';$raw=$(if($val){$val}else{$name});if($aid -match '(?i)club'){$pick=Extract-ClubFromText $raw};if(-not$pick -and $ct -match 'ComboBox'){$pick=Extract-ClubFromText $raw};if(-not$pick -and $ct -match 'Button' -and $raw -match '(?i)(driver|wood|hybrid|iron|wedge|putter|\b[357]W\b|\b[2-5]H\b|\b(PW|GW|AW|SW|LW|PT)\b)'){$pick=Extract-ClubFromText $raw};if(-not$pick){$sp=$null;if($el.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern,[ref]$sp)){if($sp.Current.IsSelected){$pick=Extract-ClubFromText $name}}};if($pick){$r=$el.Current.BoundingRectangle;$candidates += [pscustomobject]@{club=$pick;name=$name;value=$val;automation_id=$aid;control_type=$ct;top=$r.Top;left=$r.Left;width=$r.Width;height=$r.Height}}}catch{}}
  if(@($candidates.club|Sort-Object -Unique).Count -eq 1){$best=@($candidates|Sort-Object @{Expression={if($_.automation_id -match '(?i)club'){0}elseif($_.control_type -match 'ComboBox'){1}else{2}}},top|Select-Object -First 1)[0];[ordered]@{updated=(Get-Date).ToString('o');candidates=$candidates}|ConvertTo-Json -Depth 6|Set-Content $debugPath -Encoding UTF8;return [pscustomobject]@{club=$best.club;time=(Get-Date).ToString('o');source='GSPro UI'}}
 }catch{};return $null
}
function Is-GSProForeground{
 try{$h=[FactorGolfClubKeyNative]::GetForegroundWindow();if($h-eq[IntPtr]::Zero){return $false};[uint32]$fgPid=0;[FactorGolfClubKeyNative]::GetWindowThreadProcessId($h,[ref]$fgPid)|Out-Null;$p=Get-Process -Id $fgPid -ErrorAction SilentlyContinue;return ([string]$p.ProcessName -match '(?i)^GSPro')}catch{return $false}
}
function Is-KeyDown([int]$vk){return (([FactorGolfClubKeyNative]::GetAsyncKeyState($vk) -band 0x8000) -ne 0)}
function Get-ClubOrder{
 $default=@('DR','3W','5W','7W','2H','3H','4H','5H','I3','I4','I5','I6','I7','I8','I9','PW','GW','SW','LW','PT')
 try{if($config.PSObject.Properties.Name -contains 'ClubOrder' -and @($config.ClubOrder).Count -gt 1){$o=@();foreach($x in @($config.ClubOrder)){$n=Normalize([string]$x);if($n -and -not($o-contains$n)){$o+=$n}};if($o.Count-gt1){return $o}}}catch{};return $default
}
$clubOrder=@(Get-ClubOrder)
function Step-Club([string]$current,[int]$delta){$c=Normalize $current;if(-not$c){return ''};$idx=[array]::IndexOf($clubOrder,$c);if($idx-lt0){return ''};$n=$idx+$delta;if($n-lt0){$n=0};if($n-ge$clubOrder.Count){$n=$clubOrder.Count-1};return [string]$clubOrder[$n]}
function Should-Show([string]$club){if(-not$club){return $false};$mode=[string]$config.ClubCheatSheetShowMode;if($mode -eq 'EveryChange'){return ($club -ne $script:last)};return (-not $shown.Contains($club))}
function Notify-ClubChange($info){if(-not$info -or -not$info.club){return};[ordered]@{action='club_change';club=[string]$info.club;source=[string]$info.source;detected_at=[string]$info.time;requested=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $actionPath -Encoding UTF8}
function Set-StateClub([string]$club){try{if(Test-Path $statePath){$st=Get-Content $statePath -Raw|ConvertFrom-Json;$st.current_club=$club;$st.updated=(Get-Date).ToString('o');$st|ConvertTo-Json -Depth 6|Set-Content $statePath -Encoding UTF8}}catch{}}
function Show-Club($info){
 $club=[string]$info.club;if(-not(Should-Show $club)){return}
 $shown.Add($club)|Out-Null
 # One presentation lane: a confirmed club change means the golfer is moving on.
 # Dismiss an existing Coach Card and any older Cheat Sheet before showing the new club reference.
 try{Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object{$_.CommandLine -match 'Halliseum_Coach_Card\.ps1|Halliseum_Club_Cheat_Sheet\.ps1'}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}}catch{}
 Start-Sleep -Milliseconds 120
 $scriptPath=Join-Path $AppDir 'workers\Halliseum_Club_Cheat_Sheet.ps1'
 $args="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Root `"$Root`" -AppDir `"$AppDir`" -Club `"$club`""
 Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden|Out-Null
 [ordered]@{club=$club;source=$info.source;message="Club Cheat Sheet shown for verified GSPro club $club";updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8
 Log-Event ("Cheat Sheet shown: $club via $($info.source)")
}
function Apply-ClubInfo($info){if(-not$info -or -not$info.club){return};$club=Normalize([string]$info.club);if(-not$club -or $club-eq$script:last){return};Set-StateClub $club;Notify-ClubChange $info;Show-Club $info;$script:last=$club}
function Queue-Shortcut([string]$kind){
 $script:hasUserClubChange=$true
 $script:lastKeyChange=Get-Date
 $script:pendingShortcut=$kind
 $script:pendingShortcutAt=Get-Date
 Log-Event ("$kind shortcut detected; waiting for club selection to settle before reading GSPro.")
 [ordered]@{state='club_change_pending';message='Club change detected. Waiting for GSPro to settle on the selected club.';updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8
}
function Resolve-PendingShortcut{
 if(-not$script:pendingShortcut){return}
 if(((Get-Date)-$script:pendingShortcutAt).TotalMilliseconds -lt 700){return}
 $kind=$script:pendingShortcut
 $script:pendingShortcut=''
 # A pedal/key press is only a trigger. It is NOT trusted as club identity.
 # Repeated presses at GSPro's first/last selectable club may produce no club change at all.
 for($attempt=0;$attempt-lt7;$attempt++){
  if($attempt-gt0){Start-Sleep -Milliseconds 260}
  $actual=Get-ActualClubNow
  if($actual){
   $club=Normalize([string]$actual.club)
   if(-not$club){continue}
   if($club-eq$script:last){
    Log-Event ("$kind shortcut settled with GSPro still on $club via $($actual.source); boundary/no-change respected.")
    [ordered]@{state='verified_no_change';club=$club;source=$actual.source;message="GSPro stayed on $club. No extra Cheat Sheet opened.";updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8
    return
   }
   Log-Event ("$kind shortcut settled on verified actual club $club via $($actual.source)")
   Apply-ClubInfo $actual
   return
  }
 }
 # v0.8.11 safety rule: never invent the next club from pedal count.
 # If GSPro cannot be read, show no card rather than a confidently wrong one.
 Log-Event ("$kind shortcut settled, but GSPro club could not be verified. Inference disabled; no Cheat Sheet shown.")
 [ordered]@{state='unverified_club';message=$(if([bool]$config.ClubSelectorCalibrated){'Club change detected, but Factor Golf could not read the calibrated GSPro selector. No incorrect Cheat Sheet was opened.'}else{'Club change detected, but Factor Golf could not verify GSPro club. Calibrate the Club Selector once in Settings for focused OCR.'});updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8
}
if($TestOnce){
 $info=Get-ActualClubNow
 if($info -and $info.club){[ordered]@{request_id=$TestRequestId;state='club_detection_test_success';club=[string]$info.club;source=[string]$info.source;message=("Detected GSPro club: "+[string]$info.club+" via "+[string]$info.source);updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8;exit 0}
 [ordered]@{request_id=$TestRequestId;state='club_detection_test_failed';message=$(if([bool]$config.ClubSelectorCalibrated){'Could not read a club from the calibrated GSPro selector. Keep GSPro on the range with the club selector visible and try calibration again.'}else{'Club Selector is not calibrated. Open GSPro on the range and use CALIBRATE CLUB SELECTOR in Settings.'});updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8;exit 6
}
# v0.8.8: No automatic startup Driver card. The watcher starts quietly and only shows a Cheat Sheet after a real club change.
[ordered]@{state='started';message='Club Cheat Sheet watcher is running. Startup Driver sheet is disabled; waiting for a club change.';updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $status -Encoding UTF8
Log-Event 'Club Cheat Sheet watcher started. No startup Driver sheet; waiting for a club change.'
Start-Sleep -Milliseconds 350
$script:last=Get-StateClub
$prevI=$false;$prevK=$false;$prevU=$false
while($true){
 Start-Sleep -Milliseconds 10
 $fg=Is-GSProForeground;$i=Is-KeyDown 0x49;$k=Is-KeyDown 0x4B;$u=Is-KeyDown 0x55
 if($fg -and $k -and -not$prevK){Queue-Shortcut 'club_up'}
 if($fg -and $i -and -not$prevI){Queue-Shortcut 'club_down'}
 if($fg -and $u -and -not$prevU){Queue-Shortcut 'putter'}
 $prevI=$i;$prevK=$k;$prevU=$u
 Resolve-PendingShortcut
 if((Get-Date)-ge$script:nextUiPoll){
  $script:nextUiPoll=(Get-Date).AddMilliseconds(1800);$sinceKey=((Get-Date)-$script:lastKeyChange).TotalSeconds;$info=$null
  if($fg){$info=Get-ActualClubNow}
  if($info){if(-not$script:hasUserClubChange){Sync-ClubSilently $info}else{Apply-ClubInfo $info}}
  elseif($script:hasUserClubChange -and $sinceKey-gt7){$shot=Get-ClubFromShotLog;if($shot){try{$shotTime=[datetime]::Parse([string]$shot.time);if($shotTime-ge$script:watchStarted.AddSeconds(-2)){Apply-ClubInfo $shot}}catch{}}}
 }
}
