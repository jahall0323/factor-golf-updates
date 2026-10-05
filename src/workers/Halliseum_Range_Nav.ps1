param(
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$AppDir = ""
)
$ErrorActionPreference="SilentlyContinue"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
try { Add-Type -AssemblyName System.Runtime.WindowsRuntime } catch {}
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class FactorGolfRangeNative {
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$statusDir=Join-Path $Root "UltimateCoach";New-Item -ItemType Directory -Path $statusDir -Force|Out-Null
$statusPath=Join-Path $statusDir "range_nav_status.json"
$debugPath=Join-Path $statusDir "range_nav_debug.json"
$ocrDumpPath=Join-Path $statusDir "range_nav_ocr.txt"
# FGDIAG-BEGIN
try{. (Join-Path $PSScriptRoot 'FactorGolf_Nav_Trace.ps1');Start-FGNavTrace $AppDir $Root}catch{}
# FGDIAG-END
function Save([string]$state,[string]$msg,[string]$method=''){
    # FGDIAG-BEGIN
    try{Send-FGNavTrace 'status' @{state=$state;message=$msg;method=$method}}catch{}
    # FGDIAG-END
    [ordered]@{state=$state;message=$msg;method=$method;updated=(Get-Date).ToString("o")} | ConvertTo-Json -Depth 4 | Set-Content $statusPath -Encoding UTF8
}
function Save-Debug($obj){try{$obj|ConvertTo-Json -Depth 8|Set-Content $debugPath -Encoding UTF8}catch{}}
function Get-GSProProcess {
    Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -match '(?i)^GSPro' -and $_.MainWindowHandle -ne 0}|Select-Object -First 1
}
function Restore-GSProFocus {
    try{$g=Get-GSProProcess;if($g){[FactorGolfRangeNative]::ShowWindowAsync($g.MainWindowHandle,9)|Out-Null;Start-Sleep -Milliseconds 140;[FactorGolfRangeNative]::SetForegroundWindow($g.MainWindowHandle)|Out-Null;$w=New-Object -ComObject WScript.Shell;[void]$w.AppActivate($g.Id)}}catch{}
}
function Get-WindowRectObject($proc){
    try{$r=New-Object FactorGolfRangeNative+RECT;if([FactorGolfRangeNative]::GetWindowRect($proc.MainWindowHandle,[ref]$r)){$w=$r.Right-$r.Left;$h=$r.Bottom-$r.Top;if($w-ge400 -and $h-ge300){return [pscustomobject]@{Left=$r.Left;Top=$r.Top;Right=$r.Right;Bottom=$r.Bottom;Width=$w;Height=$h}}}}catch{};return $null
}
function Click-ScreenPoint([int]$x,[int]$y){
    # FGDIAG-BEGIN
    try{Send-FGNavTrace 'click_requested' @{x=$x;y=$y}}catch{}
    # FGDIAG-END
    try{[FactorGolfRangeNative]::SetCursorPos($x,$y)|Out-Null;Start-Sleep -Milliseconds 110;[FactorGolfRangeNative]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero);Start-Sleep -Milliseconds 55;[FactorGolfRangeNative]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero);
    # FGDIAG-BEGIN
    try{Send-FGNavTrace 'click_released' @{x=$x;y=$y}}catch{}
    # FGDIAG-END
    return $true}catch{return $false}
}
function Click-Relative($proc,[double]$rx,[double]$ry){
    $r=Get-WindowRectObject $proc;if(-not$r){return $false};$x=[int]($r.Left+($r.Width*$rx));$y=[int]($r.Top+($r.Height*$ry));return (Click-ScreenPoint $x $y)
}
function Get-RelativePoint($proc,[double]$rx,[double]$ry){
    $r=Get-WindowRectObject $proc;if(-not$r){return $null};return [pscustomobject]@{X=[int]($r.Left+($r.Width*$rx));Y=[int]($r.Top+($r.Height*$ry));Rect=$r}
}
function Get-PointVisualSample($proc,[double]$rx,[double]$ry){
    $r=Get-WindowRectObject $proc;if(-not$r){return $null}
    try{
        $bmp=New-Object System.Drawing.Bitmap -ArgumentList @($r.Width,$r.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size);$g.Dispose()
        $cx=[int]($r.Width*$rx);$cy=[int]($r.Height*$ry);$vals=New-Object 'System.Collections.Generic.List[int]'
        foreach($oy in @(-54,-27,0,27,54)){foreach($ox in @(-110,-55,0,55,110)){$x=[math]::Max(0,[math]::Min($r.Width-1,$cx+$ox));$y=[math]::Max(0,[math]::Min($r.Height-1,$cy+$oy));$c=$bmp.GetPixel($x,$y);$vals.Add([int]$c.R);$vals.Add([int]$c.G);$vals.Add([int]$c.B)}}
        $bmp.Dispose();return $vals.ToArray()
    }catch{return $null}
}
function Get-VisualDiff($a,$b){
    if(-not$a -or -not$b -or $a.Count-ne$b.Count -or $a.Count-eq0){return -1.0};$sum=0.0;for($i=0;$i-lt$a.Count;$i++){$sum += [math]::Abs([double]$a[$i]-[double]$b[$i])};return ($sum/$a.Count)
}
function Click-RelativeWithVisualAck($proc,[double]$rx,[double]$ry,[int]$timeoutMs=5000){
    $pt=Get-RelativePoint $proc $rx $ry;if(-not$pt){return 'unavailable'}
    try{[FactorGolfRangeNative]::SetCursorPos($pt.X,$pt.Y)|Out-Null;Start-Sleep -Milliseconds 280}catch{}
    $before=Get-PointVisualSample $proc $rx $ry
    if(-not(Click-ScreenPoint $pt.X $pt.Y)){return 'failed'}
    if(-not$before){Start-Sleep -Milliseconds $timeoutMs;return 'unavailable'}
    $deadline=(Get-Date).AddMilliseconds($timeoutMs)
    while((Get-Date)-lt$deadline){Start-Sleep -Milliseconds 320;$after=Get-PointVisualSample $proc $rx $ry;$diff=Get-VisualDiff $before $after;if($diff-ge18.0){return 'changed'}}
    return 'unchanged'
}

function Get-WindowVisualSample($proc){
    $r=Get-WindowRectObject $proc;if(-not$r){return $null}
    try{
        $bmp=New-Object System.Drawing.Bitmap -ArgumentList @($r.Width,$r.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size);$g.Dispose()
        $vals=New-Object 'System.Collections.Generic.List[int]'
        foreach($ry in @(0.16,0.30,0.44,0.58,0.72,0.86)){
            foreach($rx in @(0.10,0.24,0.38,0.52,0.66,0.80,0.92)){
                $x=[math]::Max(0,[math]::Min($r.Width-1,[int]($r.Width*$rx)))
                $y=[math]::Max(0,[math]::Min($r.Height-1,[int]($r.Height*$ry)))
                $c=$bmp.GetPixel($x,$y);$vals.Add([int]$c.R);$vals.Add([int]$c.G);$vals.Add([int]$c.B)
            }
        }
        $bmp.Dispose();return $vals.ToArray()
    }catch{return $null}
}
function Wait-GSProVisualStable($proc,[int]$minimumWaitMs=1300,[int]$stableMs=1200,[int]$timeoutMs=9000){
    # Do not equate the first animation/frame change with a ready submenu.
    # Give GSPro a minimum render window, then require the whole window to remain visually settled.
    Start-Sleep -Milliseconds $minimumWaitMs
    $prev=Get-WindowVisualSample $proc
    if(-not$prev){Start-Sleep -Milliseconds 1200;return $true}
    $deadline=(Get-Date).AddMilliseconds($timeoutMs);$stableSince=Get-Date
    while((Get-Date)-lt$deadline){
        Start-Sleep -Milliseconds 280
        $cur=Get-WindowVisualSample $proc
        if(-not$cur){Start-Sleep -Milliseconds 900;return $true}
        $diff=Get-VisualDiff $prev $cur
        if($diff-ge0 -and $diff-le4.5){
            if(((Get-Date)-$stableSince).TotalMilliseconds-ge$stableMs){return $true}
        }else{
            $stableSince=Get-Date
        }
        $prev=$cur
    }
    return $false
}

function Read-Config {
    if(-not $AppDir){return $null}
    foreach($name in @('config.json','config.default.json')){try{$p=Join-Path $AppDir $name;if(Test-Path $p){return Get-Content $p -Raw|ConvertFrom-Json}}catch{}}
    return $null
}
function Dump-Uia($proc){
    $rows=@();try{$root=[System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle);$els=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition);for($i=0;$i-lt$els.Count;$i++){try{$el=$els.Item($i);$r=$el.Current.BoundingRectangle;$rows += [pscustomobject]@{name=[string]$el.Current.Name;automation_id=[string]$el.Current.AutomationId;control_type=[string]$el.Current.ControlType.ProgrammaticName;left=$r.Left;top=$r.Top;width=$r.Width;height=$r.Height}}catch{}}}catch{};return $rows
}
function Invoke-MatchingControl($root,[string[]]$patterns){
    try{$els=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition);foreach($pat in $patterns){for($i=0;$i-lt$els.Count;$i++){try{$el=$els.Item($i);$n=[string]$el.Current.Name;if($n -and $n -match $pat){$p=$null;if($el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern,[ref]$p)){
    # FGDIAG-BEGIN
    try{Send-FGNavTrace 'uia_action' @{name=$n;action='Invoke'}}catch{}
    # FGDIAG-END
    $p.Invoke();return $n};if($el.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern,[ref]$p)){
    # FGDIAG-BEGIN
    try{Send-FGNavTrace 'uia_action' @{name=$n;action='Select'}}catch{}
    # FGDIAG-END
    $p.Select();return $n}}}catch{}}}}catch{};return $null
}
function Test-RangeEvidenceUia($proc){
    try{$root=[System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle);$els=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition);for($i=0;$i-lt$els.Count;$i++){try{$n=[string]$els.Item($i).Current.Name;if($n -match '(?i)Driving Range Distance|Quick CTP|Range Width|Green Width'){return $true}}catch{}}}catch{};return $false
}
function Try-UiaNavigation($p){
    try{
        if(Test-RangeEvidenceUia $p){Save 'success' 'GSPro is already on the Practice Range.' 'UI Automation';return $true}
        $root=[System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
        $first=Invoke-MatchingControl $root @('(?i)^Practice$','(?i)^Practice Mode$','(?i)Practice')
        if($first){Save 'navigating' ("Opened $first with Windows UI Automation.") 'UI Automation';Start-Sleep -Seconds 2}
        $deadline=(Get-Date).AddSeconds(8)
        while((Get-Date)-lt$deadline){
            $root=[System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
            $second=Invoke-MatchingControl $root @('(?i)^GS Pro Practice Range$','(?i)^GSPro Practice Range$','(?i)^Practice Range$','(?i)^Driving Range$','(?i)GS Pro Practice Range','(?i)Practice Range','(?i)Driving Range')
            if($second){Save 'navigating' ("Opened $second with Windows UI Automation.") 'UI Automation';Start-Sleep -Seconds 5;if(Test-RangeEvidenceUia $p){Save 'success' 'GSPro Practice Range opened automatically.' 'UI Automation';return $true};Save 'success' 'GSPro Practice Range command was sent with Windows UI Automation.' 'UI Automation';return $true}
            if(Test-RangeEvidenceUia $p){Save 'success' 'GSPro Practice Range opened automatically.' 'UI Automation';return $true}
            Start-Sleep -Milliseconds 650
        }
    }catch{}
    return $false
}

# PowerShell 5.1 can call Windows 10/11 WinRT OCR. If anything about OCR is unavailable,
# this entire path quietly returns $null and the worker falls back to the older methods.
$script:AsTaskGeneric=$null
try{
    $script:AsTaskGeneric=([System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'}|Select-Object -First 1)
}catch{}
function Await-WinRt($op,[Type]$resultType){
    if(-not$script:AsTaskGeneric -or -not$op){return $null}
    try{$m=$script:AsTaskGeneric.MakeGenericMethod($resultType);$task=$m.Invoke($null,@($op));$task.Wait()|Out-Null;return $task.Result}catch{return $null}
}
function Get-OcrLines($proc){
    if(-not$script:AsTaskGeneric){return $null}
    $wr=Get-WindowRectObject $proc;if(-not$wr){return $null}
    $tmp=Join-Path $env:TEMP ("factor_gspro_ocr_"+$PID+'.png')
    try{
        $bmp=New-Object System.Drawing.Bitmap -ArgumentList @($wr.Width,$wr.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($wr.Left,$wr.Top,0,0,$bmp.Size);$g.Dispose()
        $ocrScale=1.0;$maxDim=[math]::Max($wr.Width,$wr.Height)
        if($maxDim -gt 2200){
            $ocrScale=2200.0/$maxDim;$sw=[int]($wr.Width*$ocrScale);$sh=[int]($wr.Height*$ocrScale)
            $small=New-Object System.Drawing.Bitmap -ArgumentList @($sw,$sh,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $sg=[System.Drawing.Graphics]::FromImage($small);$sg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;$sg.DrawImage($bmp,0,0,$sw,$sh);$sg.Dispose();$bmp.Dispose();$bmp=$small
        }
        $ocrW=$bmp.Width;$ocrH=$bmp.Height;$bmp.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png);$bmp.Dispose()
        $file=Await-WinRt ([Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]);if(-not$file){return $null}
        $stream=Await-WinRt ($file.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType,Windows.Storage.Streams,ContentType=WindowsRuntime]);if(-not$stream){return $null}
        $decoder=Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]);if(-not$decoder){return $null}
        $soft=Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]);if(-not$soft){return $null}
        $engine=[Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]::TryCreateFromUserProfileLanguages();if(-not$engine){return $null}
        $result=Await-WinRt ($engine.RecognizeAsync($soft)) ([Windows.Media.Ocr.OcrResult,Windows.Media.Ocr,ContentType=WindowsRuntime]);if(-not$result){return $null}
        $lines=@();foreach($line in $result.Lines){
            $words=@($line.Words);if(-not$words.Count){continue};$left=999999;$top=999999;$right=0;$bottom=0
            foreach($word in $words){$br=$word.BoundingRect;$left=[math]::Min($left,$br.X);$top=[math]::Min($top,$br.Y);$right=[math]::Max($right,$br.X+$br.Width);$bottom=[math]::Max($bottom,$br.Y+$br.Height)}
            $lines += [pscustomobject]@{text=[string]$line.Text;left=[double]$left;top=[double]$top;width=[double]($right-$left);height=[double]($bottom-$top);screen_x=[int]($wr.Left+((($left+$right)/2)/$ocrScale));screen_y=[int]($wr.Top+((($top+$bottom)/2)/$ocrScale));rel_y=[double](($top+$bottom)/2/$ocrH)}
        }
        ($lines|ForEach-Object{"$($_.text) | $([math]::Round($_.left)), $([math]::Round($_.top)), $([math]::Round($_.width))x$([math]::Round($_.height))"}) -join "`r`n" | Set-Content $ocrDumpPath -Encoding UTF8
        return $lines
    }catch{return $null}finally{try{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}catch{}}
}
function Find-OcrLine($lines,[string]$regex,[double]$minRelY=0.0){
    if(-not$lines){return $null};$matches=@($lines|Where-Object{$_.text -match $regex -and $_.rel_y -ge $minRelY});if(-not$matches.Count){return $null};return @($matches|Sort-Object @{Expression={$_.height};Descending=$true}, @{Expression={$_.top};Descending=$true})[0]
}
function Test-OcrRangeLoaded($lines){if(-not$lines){return $false};return [bool]($lines|Where-Object{$_.text -match '(?i)Driving Range Distance|Quick CTP|Driving Range Width|Green Width'}|Select-Object -First 1)}
function Try-OcrNavigation($p){
    try{
        Restore-GSProFocus;Start-Sleep -Milliseconds 350
        $lines=Get-OcrLines $p;if(-not$lines){return $false}
        if(Test-OcrRangeLoaded $lines){Save 'success' 'GSPro is already on the Practice Range.' 'Windows OCR';return $true}
        $range=Find-OcrLine $lines '(?i)^\s*(GS\s*PRO\s+PRACTICE\s+RANGE|GSPRO\s+PRACTICE\s+RANGE|PRACTICE\s+RANGE|DRIVING\s+RANGE)\s*$' .28
        if($range){Save 'navigating' 'Factor Golf read the Practice Range tile directly from the GSPro screen.' 'Windows OCR';Click-ScreenPoint $range.screen_x $range.screen_y|Out-Null;Start-Sleep -Seconds 5;$verify=Get-OcrLines $p;if(Test-OcrRangeLoaded $verify){Save 'success' 'GSPro Practice Range opened automatically.' 'Windows OCR';return $true};Save 'navigating' 'Practice Range click was sent, but Factor Golf could not verify the loaded range yet.' 'Windows OCR';return $false}
        $practice=Find-OcrLine $lines '(?i)^\s*PRACTICE\s*$' .25
        if(-not$practice){return $false}
        Save 'navigating' 'Factor Golf read the PRACTICE tile directly from the GSPro screen.' 'Windows OCR';Click-ScreenPoint $practice.screen_x $practice.screen_y|Out-Null
        $deadline=(Get-Date).AddSeconds(10)
        while((Get-Date)-lt$deadline){Start-Sleep -Milliseconds 750;$lines=Get-OcrLines $p;$range=Find-OcrLine $lines '(?i)^\s*(GS\s*PRO\s+PRACTICE\s+RANGE|GSPRO\s+PRACTICE\s+RANGE|PRACTICE\s+RANGE|DRIVING\s+RANGE)\s*$' .20;if($range){Click-ScreenPoint $range.screen_x $range.screen_y|Out-Null;Save 'navigating' 'Practice Range tile found and selected.' 'Windows OCR';Start-Sleep -Seconds 5;$verify=Get-OcrLines $p;if(Test-OcrRangeLoaded $verify){Save 'success' 'GSPro Practice Range opened automatically.' 'Windows OCR';return $true};Save 'navigating' 'Practice Range click was sent, but Factor Golf could not verify the loaded range yet.' 'Windows OCR';return $false}}
    }catch{}
    return $false
}
function Try-FallbackClicks($p,$cfg){
    $use=$true;try{$use=[bool]$cfg.RangeNavUseFallbackClicks}catch{};if(-not$use){return $false}
    $calibrated=$false;try{$calibrated=[bool]$cfg.RangeNavCalibrated}catch{};if(-not$calibrated){Save 'calibration_needed' 'GSPro does not expose readable controls on this PC. Open Factor Golf Settings > Display & Screen Routing and run CALIBRATE GSPRO RANGE.' 'Calibration';return $false}
    $x1=.43;$y1=.79;$x2=.18;$y2=.40
    try{$x1=[double]$cfg.RangeNavHomePracticeX}catch{};try{$y1=[double]$cfg.RangeNavHomePracticeY}catch{};try{$x2=[double]$cfg.RangeNavPracticeRangeX}catch{};try{$y2=[double]$cfg.RangeNavPracticeRangeY}catch{}
    Restore-GSProFocus;Start-Sleep -Milliseconds 400
    Save 'navigating' 'Using your calibrated GSPro Practice > Practice Range positions and verifying each screen transition.' 'Calibrated positions'

    $first=Click-RelativeWithVisualAck $p $x1 $y1 5000
    if($first-eq'unchanged'){
        Save 'retrying' 'The first Practice click produced no visible GSPro screen change. Refocusing and retrying once.' 'Calibrated positions'
        Restore-GSProFocus;Start-Sleep -Milliseconds 900;$first=Click-RelativeWithVisualAck $p $x1 $y1 5000
    }
    if($first-eq'failed' -or $first-eq'unchanged'){Save 'failed' 'GSPro did not visibly respond to the calibrated Practice click. Factor Golf stopped instead of sending the second click to the wrong screen.' 'Calibrated positions';return $false}
    Save 'settling' 'Practice opened. Waiting for the GSPro Practice menu to finish rendering before selecting the range.' 'Calibrated positions'
    $settled=Wait-GSProVisualStable $p 1400 1300 9000
    if(-not$settled){Save 'settling' 'Practice menu is still changing. Giving GSPro one additional settle window before the range click.' 'Calibrated positions';Start-Sleep -Milliseconds 1600}

    $second='unchanged'
    for($attempt=1;$attempt-le3;$attempt++){
        Restore-GSProFocus;Start-Sleep -Milliseconds 450
        $second=Click-RelativeWithVisualAck $p $x2 $y2 7000
        if($second-eq'changed' -or $second-eq'unavailable'){break}
        if($attempt-lt3){
            Save 'retrying' ("The Practice Range click did not take on attempt $attempt. Waiting for the Practice menu to settle, then retrying.") 'Calibrated positions'
            [void](Wait-GSProVisualStable $p 900 900 5500)
        }
    }
    if($second-eq'failed' -or $second-eq'unchanged'){Save 'failed' 'GSPro stayed on the Practice menu after three calibrated Practice Range click attempts.' 'Calibrated positions';return $false}
    Start-Sleep -Milliseconds 1800
    if(Test-RangeEvidenceUia $p){Save 'success' 'GSPro Practice Range opened automatically.' 'Calibrated positions + UI verification';return $true}
    $ocr=$null;try{$ocr=Get-OcrLines $p}catch{};if($ocr -and (Test-OcrRangeLoaded $ocr)){Save 'success' 'GSPro Practice Range opened automatically.' 'Calibrated positions + OCR verification';return $true}
    Save 'sent_visual_confirmed' 'Factor Golf sent both calibrated clicks and confirmed that GSPro visibly changed screens after each click.' 'Calibrated positions + visual verification'
    return $true
}

function Wait-GSProReadyProcess{
    # A window can be technically responsive while GSPro is still rendering its startup/loading screen.
    # Cold starts therefore require a minimum process age plus a stable, responsive window. Already-running GSPro skips the age gate.
    $deadline=(Get-Date).AddSeconds(90);$stableSince=$null;$lastSig='';$lastPid=0
    while((Get-Date)-lt$deadline){
        $proc=Get-GSProProcess
        if($proc){
            try{
                $proc.Refresh();$r=Get-WindowRectObject $proc;$age=((Get-Date)-$proc.StartTime).TotalSeconds;$minAge=if($age-gt20){0}else{12};$needStableMs=if($age-gt20){1000}else{2500}
                if($proc.Id-ne$lastPid){$stableSince=$null;$lastSig='';$lastPid=$proc.Id}
                if($proc.Responding -and $r -and $age-ge$minAge){
                    $sig=("{0}:{1},{2},{3},{4}" -f $proc.Id,$r.Left,$r.Top,$r.Width,$r.Height)
                    if($sig-eq$lastSig){if(-not$stableSince){$stableSince=Get-Date}}else{$stableSince=$null;$lastSig=$sig}
                    if($stableSince -and ((Get-Date)-$stableSince).TotalMilliseconds-ge$needStableMs){return $proc}
                }
            }catch{}
        }
        Start-Sleep -Milliseconds 350
    }
    return $null
}

$cfg=Read-Config
Save 'worker_started' 'Range worker started. Waiting for the GSPro window.' 'startup'
$deadline=(Get-Date).AddSeconds(90);$p=$null
while((Get-Date)-lt$deadline){$p=Get-GSProProcess;if($p){Restore-GSProFocus;break};Start-Sleep -Seconds 1}
if(-not$p){Save 'failed' 'GSPro never presented a usable window for range navigation.';exit 4}
Save 'waiting_ready' 'GSPro window found. Waiting for the actual main window to finish its cold-start settling period.' 'startup'
$p=Wait-GSProReadyProcess
if(-not$p){Save 'failed' 'GSPro never reached a stable, responsive startup state for range navigation.' 'startup';exit 5}
Save 'ready' 'GSPro is responsive and settled. Factor Golf is starting verified range navigation.' 'startup'
$uiaDump=Dump-Uia $p;$wr=Get-WindowRectObject $p;$screenInfo=$null;try{$sc=[System.Windows.Forms.Screen]::FromHandle($p.MainWindowHandle);$screenInfo=[ordered]@{device=$sc.DeviceName;primary=$sc.Primary;left=$sc.Bounds.Left;top=$sc.Bounds.Top;width=$sc.Bounds.Width;height=$sc.Bounds.Height}}catch{};Save-Debug ([ordered]@{captured=(Get-Date).ToString('o');window_title=$p.MainWindowTitle;window_rect=$wr;screen=$screenInfo;calibrated=$(try{[bool]$cfg.RangeNavCalibrated}catch{$false});practice_x=$(try{[double]$cfg.RangeNavHomePracticeX}catch{$null});practice_y=$(try{[double]$cfg.RangeNavHomePracticeY}catch{$null});range_x=$(try{[double]$cfg.RangeNavPracticeRangeX}catch{$null});range_y=$(try{[double]$cfg.RangeNavPracticeRangeY}catch{$null});uia_elements=$uiaDump})

# v0.8.7: a user-proven calibration is the preferred navigation method, not the last fallback.
$hasCalibration=$false;try{$hasCalibration=[bool]$cfg.RangeNavCalibrated}catch{}
if($hasCalibration){if(Try-FallbackClicks $p $cfg){Restore-GSProFocus;exit 0}}
if(Try-UiaNavigation $p){Restore-GSProFocus;exit 0}
if(Try-OcrNavigation $p){Restore-GSProFocus;exit 0}
if(-not$hasCalibration -and (Try-FallbackClicks $p $cfg)){Restore-GSProFocus;exit 0}
Save 'calibration_needed' 'Automatic GSPro range navigation did not complete. Factor Golf saved UI/OCR diagnostics for the next calibration pass.'
Restore-GSProFocus
exit 3
