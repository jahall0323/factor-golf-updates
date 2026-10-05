param(
    [Parameter(Mandatory=$true)][string]$AppDir,
    [string]$PackagePath = "",
    [string]$PackageUrl = "",
    [Parameter(Mandatory=$true)][string]$Version,
    [string]$ExpectedSha256 = ""
)

$ErrorActionPreference = "Stop"
$log = Join-Path $AppDir "update.log"
function Log([string]$msg) {
    try { Add-Content -LiteralPath $log -Value ("{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding UTF8 } catch {}
}
function Download-UpdatePackage([string]$Url,[string]$Destination){
    $u=[uri]$Url
    if($u.Scheme -ne 'https'){throw 'Update package URL must use HTTPS.'}
    try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{}
    $last=$null
    for($attempt=1;$attempt -le 3;$attempt++){
        try{
            Log "Downloading update package (attempt $attempt): $Url"
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 120 -Headers @{'Cache-Control'='no-cache';'User-Agent'="FactorGolfUpdater/$Version"}
            if((Test-Path -LiteralPath $Destination) -and (Get-Item -LiteralPath $Destination).Length -gt 0){return}
            throw 'Downloaded package was empty.'
        }catch{$last=$_;Start-Sleep -Seconds ([Math]::Min(2*$attempt,6))}
    }
    throw "Direct update download failed after 3 attempts: $($last.Exception.Message)"
}

$downloaded=$false
$tempPackage=''
$stage=''
$backup=''
$snapshotReady=$false
$journal=New-Object 'System.Collections.Generic.List[object]'
function Record-UpdatePath([string]$relative,[bool]$directory=$false){
    $target=Join-Path $AppDir $relative
    if(-not($journal | Where-Object {$_.relative -eq $relative})){
        $journal.Add([pscustomobject]@{relative=$relative;existed=(Test-Path -LiteralPath $target);directory=$directory})
    }
}
try {
    if(-not$PackagePath -and -not$PackageUrl){throw 'No update package path or URL was supplied.'}
    if($PackagePath -and $PackageUrl){throw 'Updater received both PackagePath and PackageUrl. Only one source is allowed.'}
    Log "Starting update to v$Version"
    Start-Sleep -Seconds 2

    if($PackageUrl){
        $tempRoot=Join-Path $env:TEMP 'FactorGolfUpdates';New-Item -ItemType Directory -Path $tempRoot -Force|Out-Null
        $tempPackage=Join-Path $tempRoot ("FactorGolf_"+$Version+'_'+[guid]::NewGuid().ToString('N')+'.zip')
        Download-UpdatePackage $PackageUrl $tempPackage
        $PackagePath=$tempPackage;$downloaded=$true
    }
    if (-not (Test-Path -LiteralPath $PackagePath)) { throw "Update package not found: $PackagePath" }

    if ($ExpectedSha256) {
        $actual = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $ExpectedSha256.ToLowerInvariant()) { throw "Update package hash did not match the manifest." }
        Log "SHA256 verified."
    }else{throw 'Update manifest did not provide a SHA256 hash.'}

    $escaped = [regex]::Escape($AppDir)
    $me = $PID
    $procs = Get-CimInstance Win32_Process | Where-Object {
        $_.ProcessId -ne $me -and
        $_.Name -eq 'powershell.exe' -and
        $_.CommandLine -match $escaped -and
        $_.CommandLine -match 'Halliseum_(Control_Center|Direct_Bridge_Hidden|SwingNerds_UIA_Hidden|Coach_Set_API|Coach_Card|Range_Nav|Range_Calibration|Focus_GSPro|Minimize_Connectors|Club_Cheat_Watcher|Club_Cheat_Sheet|Coach_Controls|Performance|Archive_Set|Voice_Test|Settings|Self_Update)\.ps1'
    }
    foreach ($p in $procs) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
    Start-Sleep -Milliseconds 700

    $stage = Join-Path $env:TEMP ("FactorGolfStage_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $stage -Force

    $payload = $stage
    if (-not (Test-Path (Join-Path $payload "Halliseum_Control_Center.ps1"))) {
        $dirs = @(Get-ChildItem -LiteralPath $stage -Directory)
        if ($dirs.Count -eq 1 -and (Test-Path (Join-Path $dirs[0].FullName "Halliseum_Control_Center.ps1"))) { $payload = $dirs[0].FullName }
    }
    if (-not (Test-Path (Join-Path $payload "Halliseum_Control_Center.ps1"))) { throw "Update package is not a valid Factor Golf package." }
    $packageVersionFile=Join-Path $payload 'app_version.txt'
    if(-not(Test-Path -LiteralPath $packageVersionFile)){throw 'Update package is missing app_version.txt.'}
    $packageVersion=(Get-Content -LiteralPath $packageVersionFile -Raw).Trim()
    if($packageVersion -ne $Version){throw "Package version mismatch. Manifest says $Version but package says $packageVersion."}

    # Make one local rollback snapshot of app-owned files before changing anything.
    $backupRoot=Join-Path $env:LOCALAPPDATA 'FactorGolfUpdater\Backups';New-Item -ItemType Directory -Path $backupRoot -Force|Out-Null
    $currentVersion='unknown';try{$currentVersion=(Get-Content -LiteralPath (Join-Path $AppDir 'app_version.txt') -Raw).Trim()}catch{}
    $backup=Join-Path $backupRoot ("v"+$currentVersion+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup -Force|Out-Null
    foreach($item in Get-ChildItem -LiteralPath $AppDir -Force){
        if($item.Name -in @('config.json','secrets','update.log')){continue}
        Copy-Item -LiteralPath $item.FullName -Destination $backup -Recurse -Force
    }
    Get-ChildItem -LiteralPath $backupRoot -Directory|Sort-Object LastWriteTime -Descending|Select-Object -Skip 2|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $snapshotReady=$true
    Log "Rollback snapshot created: $backup"

    $preserve = @('config.json','secrets','update.log')
    # Normalize short (8.3) and expanded paths before computing relative names.
    $payload=(Get-Item -LiteralPath $payload).FullName
    # Journal only package-owned paths before each mutation. Preserve unrelated user data.
    foreach ($item in Get-ChildItem -LiteralPath $payload -Force -Recurse | Sort-Object FullName) {
        $relative=$item.FullName.Substring($payload.Length).TrimStart('\')
        $top=($relative -split '[\\/]')[0]
        if ($preserve -contains $top) { continue }
        $dest=Join-Path $AppDir $relative
        Record-UpdatePath $relative $item.PSIsContainer
        if($item.PSIsContainer){New-Item -ItemType Directory -Path $dest -Force|Out-Null}
        else{Copy-Item -LiteralPath $item.FullName -Destination $dest -Force}
    }
    Record-UpdatePath 'app_version.txt'
    Record-UpdatePath 'last_update.json'
    Set-Content -LiteralPath (Join-Path $AppDir 'app_version.txt') -Value $Version -Encoding ASCII
    [ordered]@{
        version = $Version
        installed_at = (Get-Date).ToString('o')
        package = (Split-Path -Leaf $PackagePath)
        source = $(if($PackageUrl){'https'}else{'local_fallback'})
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $AppDir 'last_update.json') -Encoding UTF8

    $installedVersion=(Get-Content -LiteralPath (Join-Path $AppDir 'app_version.txt') -Raw).Trim()
    if($installedVersion -ne $Version){throw "Installed version marker validation failed. Expected $Version but found $installedVersion."}
    if(-not(Test-Path -LiteralPath (Join-Path $AppDir 'Halliseum_Control_Center.ps1'))){throw 'Installed main application script is missing.'}
    Log "Installed version marker verified as v$installedVersion."
    Log "Update files installed successfully."

    try { if($stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue} } catch {}
    try { if($downloaded -and $tempPackage){Remove-Item -LiteralPath $tempPackage -Force -ErrorAction SilentlyContinue} } catch {}

    $vbs = Join-Path $AppDir "Halliseum_Control_Center.vbs"
    if (Test-Path $vbs) {
        Start-Process -FilePath (Join-Path $env:WINDIR "System32\wscript.exe") -ArgumentList ('"' + $vbs + '"') | Out-Null
        Log "Factor Golf relaunched."
    }
} catch {
    Log ("UPDATE FAILED: " + $_.Exception.Message)
    # Roll back if an install failure happened after the snapshot was created.
    if($snapshotReady -and $backup -and (Test-Path -LiteralPath $backup)){
        try{
            Log "Attempting rollback from $backup"
            # Deepest paths first. Restore exact file paths, never nest backup directories.
            foreach($entry in @($journal | Sort-Object @{Expression={$_.relative.Length};Descending=$true})){
                $dest=Join-Path $AppDir $entry.relative
                if($entry.directory){
                    if(-not$entry.existed -and (Test-Path -LiteralPath $dest) -and @(Get-ChildItem -LiteralPath $dest -Force).Count -eq 0){
                        Remove-Item -LiteralPath $dest -Force
                    }
                }elseif($entry.existed){
                    Copy-Item -LiteralPath (Join-Path $backup $entry.relative) -Destination $dest -Force
                }elseif(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Force}
            }
            Log 'Rollback completed.'
        }catch{Log ("ROLLBACK FAILED: "+$_.Exception.Message)}
    }
    try { if($stage -and(Test-Path $stage)){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue} } catch {}
    try { if($downloaded -and $tempPackage -and(Test-Path $tempPackage)){Remove-Item -LiteralPath $tempPackage -Force -ErrorAction SilentlyContinue} } catch {}
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Factor Golf update failed.`n`n$($_.Exception.Message)`n`nThe updater attempted to restore the previous version. See update.log for details.",
            "Factor Golf Update",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch {}
}
