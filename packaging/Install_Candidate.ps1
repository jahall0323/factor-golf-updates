param([string]$AppDir=(Join-Path $env:LOCALAPPDATA 'HalliseumControlCenter'))
$ErrorActionPreference='Stop'
$manifest=Get-Content (Join-Path $PSScriptRoot 'candidate-manifest.json') -Raw|ConvertFrom-Json
if($manifest.channel -ne 'halliseum-candidate'){throw 'This is not a Halliseum candidate package.'}
$payload=Join-Path $PSScriptRoot 'candidate-payload.zip'
$updater=Join-Path $PSScriptRoot 'Bootstrap_Update.ps1'
foreach($pair in @(@($payload,$manifest.payload_sha256),@($updater,$manifest.updater_sha256))){
 if((Get-FileHash -LiteralPath $pair[0] -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pair[1]){throw 'Candidate integrity check failed. Extract the complete download again.'}
}
if(-not(Test-Path (Join-Path $AppDir 'Halliseum_Control_Center.ps1'))){throw 'Existing Factor Golf installation was not found. This candidate upgrades the existing simulator installation.'}
Write-Host ('Installing '+$manifest.candidate_id+' with verified rollback protection...')
$started=Get-Date
& $updater -AppDir $AppDir -PackagePath $payload -Version $manifest.app_version -ExpectedSha256 $manifest.payload_sha256
# The updater catches failures for its UI; independently verify completion here.
$installed=Get-Content (Join-Path $AppDir 'last_update.json') -Raw|ConvertFrom-Json
if([datetime]$installed.installed_at -lt $started -or $installed.version -ne $manifest.app_version){throw 'Candidate install did not finish. See the Factor Golf update.log.'}
foreach($property in $manifest.files.PSObject.Properties){
 $path=Join-Path $AppDir $property.Name
 if($property.Name -eq 'app_version.txt'){
  if((Get-Content $path -Raw).Trim() -ne $manifest.app_version){throw 'Installed version mismatch'}
 }elseif((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $property.Value){throw ('Installed file mismatch: '+$property.Name)}
}
Write-Host ('Installed '+$manifest.candidate_id+'. Factor Golf has reopened. Your settings and API key were preserved.')
