$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
function Assert($value,$message){if(-not$value){throw $message}}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $repo 'evidence\Factor_Golf_Sim_Control_Center_v0_8_14_ACCEPTED_BASELINE.zip'))
try{$reader=New-Object IO.StreamReader ($zip.GetEntry('workers/Halliseum_Range_Nav.ps1').Open());try{$baseline=$reader.ReadToEnd()}finally{$reader.Dispose()}}finally{$zip.Dispose()}
$candidate=Get-Content (Join-Path $repo 'src\workers\Halliseum_Range_Nav.ps1') -Raw
$stripped=[regex]::Replace($candidate,'(?ms)^[ \t]*# FGDIAG-BEGIN\r?\n.*?^[ \t]*# FGDIAG-END\r?\n','')
function Tokens([string]$text){
 $tokens=$null;$errors=$null
 [void][Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
 Assert (-not$errors.Count) 'Navigation syntax invalid'
 return (@($tokens|Where-Object{$_.Kind -notin @('NewLine','Comment','EndOfInput')}|ForEach-Object{$_.Kind.ToString()+':'+$_.Text}) -join "`n")
}
Assert ((Tokens $baseline) -ceq (Tokens $stripped)) 'Navigation instructions changed beyond the diagnostic hooks'
. (Join-Path $repo 'src\workers\FactorGolf_Nav_Trace.ps1')
$temp=Join-Path $env:TEMP ('fg-nav-'+[guid]::NewGuid().ToString('N'));New-Item $temp -ItemType Directory|Out-Null
try{
 Write-FGNavEvent $temp 'synthetic-run' 1 'click_requested' @{x=-3200;y=700} @{handle=12;title='fixture foreground'} @{reported_bounds=@{Left=-3840};physical_visible_bounds=@{Left=-3840}}
 Write-FGNavEvent $temp 'synthetic-run' 2 'status' @{state='failed';message='fixture'} $null $null
 $events=@(Get-Content (Join-Path $temp 'events.jsonl')|ForEach-Object{$_|ConvertFrom-Json})
 Assert ($events.Count -eq 2 -and $events[0].sequence -eq 1 -and $events[1].sequence -eq 2) 'Event ordering lost'
 Assert ($events[0].data.x -eq -3200 -and $events[0].target.physical_visible_bounds.Left -eq -3840) 'Negative-monitor coordinates lost'
 Assert ($events[0].foreground.title -eq 'fixture foreground' -and $events[1].data.state -eq 'failed') 'Foreground or failure status missing'
 # Native imports must compile and read the real CI desktop without moving anything.
 Initialize-FGNavNative
 $snapshot=Get-FGWindowObservation ([FGNavObservation]::GetForegroundWindow())
 # Broken diagnostic output must not leak an exception or success-stream output.
 $script:FGNavRun=[pscustomobject]@{id='test';directory=(Join-Path $temp 'missing')};$script:FGNavSequence=0
 function Get-GSProProcess{return $null}
 Assert ($null -eq (Send-FGNavTrace 'fixture' @{})) 'Diagnostics must be fail-open and quiet'
 # Compile the recorder capture class, without starting its loop or capturing the CI desktop.
 $tokens=$null;$errors=$null
 $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'src\workers\FactorGolf_Nav_Recorder.ps1'),[ref]$tokens,[ref]$errors)
 Assert (-not$errors.Count) 'Recorder syntax invalid'
 $code=$ast.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'public static class FGNavCapture'},$true)
 Add-Type -AssemblyName System.Drawing
 Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition $code.Value
 $before=[FGNavObservation]::GetThreadDpiAwarenessContext()
 try{[FGNavCapture]::Capture([IntPtr]::Zero,(Join-Path $temp 'invalid.jpg'))|Out-Null}catch{}
 Assert ([FGNavObservation]::GetThreadDpiAwarenessContext() -eq $before) 'Capture did not restore its calling thread DPI context on failure'
}finally{Remove-Item $temp -Recurse -Force}
Write-Output 'PASS: original navigation tokens unchanged; ordered evidence, negative coordinates, native imports, fail-open behavior and recorder DPI restoration.'
