$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$temp=Join-Path $env:TEMP ('Factor Golf Candidate '+[guid]::NewGuid().ToString('N'))
$oldLocal=$env:LOCALAPPDATA
New-Item $temp -ItemType Directory|Out-Null
$env:LOCALAPPDATA=Join-Path $temp 'local';New-Item $env:LOCALAPPDATA -ItemType Directory|Out-Null
function Get-CimInstance{param($ClassName) return @()}
function Start-Sleep{param($Seconds,$Milliseconds)}
function Start-Process{param($FilePath,$ArgumentList) $global:FGCandidateLaunches++}
function Assert($condition,$message){if(-not$condition){throw $message}}
try{
 $bundle=Join-Path $temp 'extracted';Expand-Archive (Join-Path $repo 'dist\Factor_Golf_Halliseum_Candidate_1.zip') $bundle
 $app=Join-Path $env:LOCALAPPDATA 'HalliseumControlCenter'
 Expand-Archive (Join-Path $repo 'evidence\Factor_Golf_Sim_Control_Center_v0_8_14_ACCEPTED_BASELINE.zip') $app
 Set-Content (Join-Path $app 'config.json') '{"RangeNavCalibrated":true,"ClubSelectorX":0.32,"GSProDisplayKey":"AUTO","UserSentinel":"keep"}'
 New-Item (Join-Path $app 'secrets'),(Join-Path $app 'learned') -ItemType Directory|Out-Null
 [IO.File]::WriteAllBytes((Join-Path $app 'secrets\fixture.dpapi'),[byte[]](1,2,255,0))
 Set-Content (Join-Path $app 'learned\bag.json') '{"carry":200}'
 $preserved=@{};foreach($name in @('config.json','secrets\fixture.dpapi','learned\bag.json')){$preserved[$name]=(Get-FileHash (Join-Path $app $name)).Hash}
 foreach($from in @('0.8.14','0.8.15','0.8.14')){
  Set-Content (Join-Path $app 'app_version.txt') $from
  $global:FGCandidateLaunches=0
  & (Join-Path $bundle 'Install_Candidate.ps1') -AppDir $app
  Assert ($global:FGCandidateLaunches -eq 1) 'Expected one intercepted relaunch'
  foreach($name in $preserved.Keys){Assert ((Get-FileHash (Join-Path $app $name)).Hash -eq $preserved[$name]) "User data changed: $name"}
  $build=Get-Content (Join-Path $app 'candidate_build.json') -Raw|ConvertFrom-Json
  Assert ($build.candidate_id -eq '0.8.14-halliseum-candidate.1') 'Installed candidate identity missing'
 }
 # Both bootstrap and package tampering must fail before changing the app.
 $installedHash=(Get-FileHash (Join-Path $app 'workers\Halliseum_Range_Nav.ps1')).Hash
 foreach($file in @('candidate-payload.zip','Bootstrap_Update.ps1')){
  $path=Join-Path $bundle $file;$bytes=[IO.File]::ReadAllBytes($path)
  try{
   [IO.File]::AppendAllText($path,'tamper');$rejected=$false;$global:FGCandidateLaunches=0
   try{& (Join-Path $bundle 'Install_Candidate.ps1') -AppDir $app}catch{$rejected=$_.Exception.Message -match 'integrity check failed'}
   Assert $rejected 'Tampered candidate was not rejected'
   Assert ($global:FGCandidateLaunches -eq 0) 'Tampered candidate launched app'
   Assert ((Get-FileHash (Join-Path $app 'workers\Halliseum_Range_Nav.ps1')).Hash -eq $installedHash) 'Rejected candidate changed app'
  }finally{[IO.File]::WriteAllBytes($path,$bytes)}
 }
}finally{$env:LOCALAPPDATA=$oldLocal;Remove-Item $temp -Recurse -Force}
Write-Output 'PASS: real candidate install from accepted/rejected versions, reinstall, private-state preservation, package and bootstrap tamper rejection.'
