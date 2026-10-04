# Runs unchanged updater code in disposable directories. Never starts the application.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$updater = Join-Path $repo 'src\workers\Halliseum_Self_Update.ps1'
$originalTemp = $env:TEMP
$originalLocal = $env:LOCALAPPDATA
$testRoot = Join-Path $originalTemp ('FactorGolfRegression_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $testRoot | Out-Null
# The failure UI is replaced in this process only; the updater source remains unchanged.
Add-Type -TypeDefinition @'
namespace System.Windows {
 public enum MessageBoxButton { OK }
 public enum MessageBoxImage { Error }
 public static class MessageBox {
  public static int Show(string message, string title, MessageBoxButton b, MessageBoxImage i) { return 0; }
 }
}
'@
function Add-Type { param($AssemblyName) if ($AssemblyName -ne 'PresentationFramework') { throw 'Unexpected assembly request' } }
function Get-CimInstance { param($ClassName) return @() }
function Start-Sleep { param($Seconds, $Milliseconds) }
function Start-Process {
 param($FilePath, $ArgumentList)
 $global:FGLaunches++
 $marker = (Get-Content (Join-Path $global:FGApp 'app_version.txt') -Raw).Trim()
 if ($marker -ne '0.8.14') { throw 'Relaunch before installed version validation' }
}
function Copy-Item {
 [CmdletBinding()]param([string]$LiteralPath, [string]$Destination, [switch]$Recurse, [switch]$Force)
 if ($global:FGInject -and $Destination -eq (Join-Path $global:FGApp 'zz_fail.txt')) {
  $global:FGInject = $false
  throw 'Injected copy failure after earlier files were installed'
 }
 Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
}
function Assert-True($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Text($Path) { (Get-Content -LiteralPath $Path -Raw).Trim() }
$results = @()
$cases = @('fresh','upgrade','nested','bad_hash','missing_hash','wrong_version','missing_main','both_sources','http_source','rollback','installer_copy')
try {
 foreach ($case in $cases) {
  $caseRoot = Join-Path $testRoot $case
  $app = Join-Path $caseRoot 'app'
  $payload = Join-Path $caseRoot 'payload'
  $env:TEMP = Join-Path $caseRoot 'temp'
  $env:LOCALAPPDATA = Join-Path $caseRoot 'local'
  New-Item -ItemType Directory -Path $app,$payload,$env:TEMP,$env:LOCALAPPDATA | Out-Null
  $global:FGApp = $app; $global:FGLaunches = 0; $global:FGInject = ($case -eq 'rollback')
  try {
   if ($case -ne 'fresh') {
    Set-Content (Join-Path $app 'app_version.txt') '0.8.13'
    Set-Content (Join-Path $app 'Halliseum_Control_Center.ps1') '# previous application'
   }
   $settings = '{"RangeNavCalibrated":true,"RangeNavHomePracticeX":0.32,"ClubSelectorX":0.73,"GSProDisplayKey":"AUTO","CoachCardDisplayKey":"projector","UserSentinel":"retain"}'
   Set-Content (Join-Path $app 'config.json') $settings
   New-Item -ItemType Directory (Join-Path $app 'secrets'),(Join-Path $app 'learned') | Out-Null
   [IO.File]::WriteAllBytes((Join-Path $app 'secrets\key.bin'), [byte[]](0,255,42,17))
   Set-Content (Join-Path $app 'learned\bag.json') '{"carry":200}'
   $preserved = @{}
   foreach ($name in @('config.json','secrets\key.bin','learned\bag.json')) { $preserved[$name] = (Get-FileHash (Join-Path $app $name)).Hash }
   if ($case -eq 'installer_copy') {
    # Execute the exact BAT payload-copy command, with isolated SRC/DEST; no shortcuts or launch.
    $bat = Get-Content (Join-Path $repo 'src\INSTALL_Halliseum_Control_Center.bat')
    $line = @($bat | Where-Object { $_ -match '^xcopy ' })
    Assert-True ($line.Count -eq 1) 'Installer payload-copy command changed; review harness'
    $env:SRC = (Join-Path $repo 'src') + '\'; $env:DEST = $app
    & cmd.exe /d /c $line[0]
    Assert-True ($LASTEXITCODE -eq 0) 'Installer xcopy failed'
    Assert-True ((Read-Text (Join-Path $app 'app_version.txt')) -eq '0.8.14') 'Installer version missing'
    foreach ($f in Get-ChildItem (Join-Path $repo 'src') -File -Recurse) {
     $rel = $f.FullName.Substring((Join-Path $repo 'src').Length + 1)
     Assert-True ((Get-FileHash $f.FullName).Hash -eq (Get-FileHash (Join-Path $app $rel)).Hash) ('Installer payload mismatch: ' + $rel)
    }
   } else {
    Set-Content (Join-Path $payload 'app_version.txt') '0.8.14'
    if ($case -ne 'missing_main') { Set-Content (Join-Path $payload 'Halliseum_Control_Center.ps1') '# candidate application' }
    Set-Content (Join-Path $payload 'Halliseum_Control_Center.vbs') "' inert launcher fixture"
    Set-Content (Join-Path $payload 'config.json') '{"UserSentinel":"overwrite attempt"}'
    New-Item -ItemType Directory (Join-Path $payload 'secrets') | Out-Null
    Set-Content (Join-Path $payload 'secrets\key.bin') 'overwrite attempt'
    if ($case -eq 'rollback') {
     New-Item -ItemType Directory (Join-Path $app 'workers'),(Join-Path $payload 'workers'),(Join-Path $payload 'new_directory') | Out-Null
     Set-Content (Join-Path $app 'workers\existing.ps1') '# old nested worker'
     Set-Content (Join-Path $payload 'workers\existing.ps1') '# replacement nested worker'
     Set-Content (Join-Path $payload 'workers\introduced.ps1') '# introduced nested worker'
     Set-Content (Join-Path $payload 'new_directory\introduced.txt') 'new directory content'
     Set-Content (Join-Path $payload 'aa_new_file.txt') 'must disappear on rollback'
     Set-Content (Join-Path $payload 'zz_fail.txt') 'injection target'
    }
    $zip = Join-Path $caseRoot 'candidate.zip'
    $zipSource = if ($case -eq 'nested') { $payload } else { Join-Path $payload '*' }
    Compress-Archive -Path $zipSource -DestinationPath $zip
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
    $argsMap = @{ AppDir=$app; PackagePath=$zip; Version='0.8.14'; ExpectedSha256=$hash }
    if ($case -eq 'bad_hash') { $argsMap.ExpectedSha256 = '0' * 64 }
    if ($case -eq 'missing_hash') { $argsMap.ExpectedSha256 = '' }
    if ($case -eq 'wrong_version') { $argsMap.Version = '0.8.15' }
    if ($case -eq 'both_sources') { $argsMap.PackageUrl = 'https://example.invalid/package.zip' }
    if ($case -eq 'http_source') { $argsMap.PackagePath = ''; $argsMap.PackageUrl = 'http://example.invalid/package.zip' }
    & $updater @argsMap
    $log = Get-Content (Join-Path $app 'update.log') -Raw
    if ($case -in @('fresh','upgrade','nested')) {
     Assert-True ($log -match 'Update files installed successfully') 'Updater did not report successful install'
     Assert-True ((Read-Text (Join-Path $app 'app_version.txt')) -eq '0.8.14') 'Installed version incorrect'
     Assert-True ($global:FGLaunches -eq 1) 'Expected one controlled relaunch'
     $state = Get-Content (Join-Path $app 'last_update.json') -Raw | ConvertFrom-Json
     Assert-True ($state.version -eq '0.8.14' -and $state.source -eq 'local_fallback') 'Installed state metadata incorrect'
    } else {
     Assert-True ($log -match 'UPDATE FAILED') 'Bad update was not rejected'
     Assert-True ($global:FGLaunches -eq 0) 'Rejected update relaunched the application'
     Assert-True ((Read-Text (Join-Path $app 'app_version.txt')) -eq '0.8.13') 'Previous version not preserved/restored'
     Assert-True ((Read-Text (Join-Path $app 'Halliseum_Control_Center.ps1')) -eq '# previous application') 'Previous application not preserved/restored'
     if ($case -eq 'rollback') {
      Assert-True ($log -match 'Injected copy failure' -and $log -match 'Rollback completed') 'Failure injection or rollback did not execute'
      Assert-True (-not (Test-Path (Join-Path $app 'aa_new_file.txt'))) 'ROLLBACK DEFECT: newly introduced file remains after rollback'
      Assert-True ((Read-Text (Join-Path $app 'workers\existing.ps1')) -eq '# old nested worker') 'Nested worker not restored'
      Assert-True (-not (Test-Path (Join-Path $app 'workers\introduced.ps1'))) 'Introduced nested worker remains'
      Assert-True (-not (Test-Path (Join-Path $app 'new_directory'))) 'New directory remains'
      Assert-True (-not (Test-Path (Join-Path $app 'workers\workers'))) 'Rollback nested the workers directory'
     }
    }
    Assert-True (@(Get-ChildItem $env:TEMP -Directory -Filter 'FactorGolfStage_*').Count -eq 0) 'Staging directory leaked'
   }
   foreach ($name in $preserved.Keys) { Assert-True ((Get-FileHash (Join-Path $app $name)).Hash -eq $preserved[$name]) ('User data changed: ' + $name) }
   $results += [pscustomobject]@{name=$case;passed=$true;detail='PASS'}
  } catch { $detail=$_.Exception.Message; if(Test-Path (Join-Path $app 'update.log')){ $detail += "`n" + (Get-Content (Join-Path $app 'update.log') -Raw) }; $results += [pscustomobject]@{name=$case;passed=$false;detail=$detail} }
 }
} finally {
 $env:TEMP=$originalTemp; $env:LOCALAPPDATA=$originalLocal
 Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
$results | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
$results | ConvertTo-Json | Set-Content (Join-Path $repo 'install-update-results.json') -Encoding UTF8
if (@($results | Where-Object {-not $_.passed}).Count) { throw 'Install/update regression contracts failed. See result details.' }
