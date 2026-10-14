$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src/workers/Halliseum_Club_Test_Status.ps1')
function Assert($condition,[string]$message){if(-not$condition){throw $message}}
function Import-Function([string]$path,[string]$name){
 $tokens=$null;$errors=$null
 $ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw 'Source parse failed'}
 $fn=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
 if(-not$fn){throw "Missing function $name"}
 # Return definition to be evaluated in caller scope.
 return $fn.Extent.Text
}
$ok=[pscustomobject]@{request_id='new';state='club_detection_test_success';message='Detected GSPro club: I7'}
Assert ((Get-FGClubTestView 'new' $ok 2 $false).complete) 'Matching result must complete'
Assert (-not(Get-FGClubTestView 'old' $ok 2 $false).complete) 'Unrelated result must be ignored'
Assert ((Get-FGClubTestView 'new' $ok 31 $true).message -eq $ok.message) 'Valid result wins over timeout/process exit'
Assert ((Get-FGClubTestView 'new' $null 30 $false).message -match 'timed out') 'Hung worker needs bounded feedback'
Assert ((Get-FGClubTestView 'new' $null 1 $true).message -match 'without a result') 'Early exit must be visible'
Assert (-not(Get-FGClubTestView 'new' $null 29 $false).complete) 'Active worker must keep waiting'
$bad=[pscustomobject]@{request_id='new';state='started';message='Watcher startup'}
Assert (-not(Get-FGClubTestView 'new' $bad 1 $false).complete) 'Watcher status is not a test result'
$bad.state='club_detection_test_failed';$bad.message='No club verified'
Assert ((Get-FGClubTestView 'new' $bad 1 $false).message -eq 'No club verified') 'Failure must surface'

$temp=Join-Path $env:TEMP ('fg-club-test-'+[guid]::NewGuid().ToString('N'))
New-Item $temp -ItemType Directory|Out-Null
try{
 $clubCalStatusPath=Join-Path $temp 'calibration.json'
 @{message='OLD CALIBRATION'}|ConvertTo-Json|Set-Content $clubCalStatusPath
 $testPath=Join-Path $temp 'test.json';$ok|ConvertTo-Json|Set-Content $testPath
 $ClubSelectorCalibrationStatus=[pscustomobject]@{Text=''}
 $TestClubDetectionButton=[pscustomobject]@{IsEnabled=$false}
 $script:clubTestMessage=''
 $script:clubTestRequest=[pscustomobject]@{id='new';path=$testPath;started=(Get-Date);process=[pscustomobject]@{HasExited=$true}}
 . ([scriptblock]::Create((Import-Function (Join-Path $root 'src/workers/Halliseum_Settings.ps1') 'Update-ClubSelectorCalibrationStatus')))
 Update-ClubSelectorCalibrationStatus
 Assert ($ClubSelectorCalibrationStatus.Text -eq $ok.message) 'Old calibration must not mask new detection'
 Assert ($TestClubDetectionButton.IsEnabled -and $null -eq $script:clubTestRequest) 'Completed request must re-enable test'
 Update-ClubSelectorCalibrationStatus
 Assert ($ClubSelectorCalibrationStatus.Text -eq $ok.message) 'Timer must preserve terminal feedback'
 Assert (-not(Test-Path $testPath)) 'Consumed private result should be cleaned up'
}finally{Remove-Item $temp -Recurse -Force}

. ([scriptblock]::Create((Import-Function (Join-Path $root 'src/workers/Halliseum_Club_Cheat_Watcher.ps1') 'Get-ActualClubNow')))
function Get-ClubFromSelectorCrop{return $null}
function Get-ClubFromGSProUI{return $null}
function Get-ClubFromGSProScreen{throw 'Unrelated screen text must never supply the selected club'}
Assert ($null -eq (Get-ActualClubNow)) 'Unreadable selector must remain unverified'
function Get-ClubFromSelectorCrop{return [pscustomobject]@{club='I7';source='selector'}}
Assert ((Get-ActualClubNow).club -eq 'I7') 'Verified selector result must be retained'
Write-Output 'PASS: club request correlation, stale-calibration visibility, timeout/exit recovery and no whole-screen inference.'
