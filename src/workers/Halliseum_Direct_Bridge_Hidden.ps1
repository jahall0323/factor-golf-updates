
param(
    [string]$Destination = "G:\My Drive\Halliseum Coach Bridge\Direct"
)
$ErrorActionPreference = "SilentlyContinue"

function Safe-Json($o,$p) {
    try { $o | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $p -Encoding UTF8 } catch {}
}

try {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $gsproLog = Join-Path $env:LOCALAPPDATA "SwingNerdsClip\gspro_shots.log"
    $foresightLog = "C:\ProgramData\Foresight\FSS_SDK_MANAGED_LOG.txt"
    $currentRound = Join-Path $env:USERPROFILE "AppData\LocalLow\GSPro\GSPro\currentRound.dat"

    $sources = @{
        "GSProShots" = $gsproLog
        "ForesightSDK" = $foresightLog
        "CurrentRound" = $currentRound
    }

    $state = @{}
    foreach ($name in $sources.Keys) {
        $p = $sources[$name]
        $state[$name] = if (Test-Path -LiteralPath $p) { (Get-Item $p).LastWriteTimeUtc.Ticks } else { 0 }
    }

    Safe-Json ([ordered]@{
        state="running"; started_local=(Get-Date).ToString("o"); pid=$PID;
        destination=$Destination; gspro_log=$gsproLog; foresight_log=$foresightLog; current_round=$currentRound
    }) (Join-Path $Destination "direct_bridge_status.json")

    while ($true) {
        foreach ($name in $sources.Keys) {
            $p = $sources[$name]
            if (Test-Path -LiteralPath $p) {
                $ticks = (Get-Item -LiteralPath $p).LastWriteTimeUtc.Ticks
                if ($ticks -ne $state[$name]) {
                    $state[$name] = $ticks
                    Start-Sleep -Milliseconds 300
                    if ($name -eq "GSProShots") {
                        Get-Content $p -Tail 700 | Set-Content (Join-Path $Destination "gspro_shots_tail.log") -Encoding UTF8
                    } elseif ($name -eq "ForesightSDK") {
                        Get-Content $p -Tail 700 | Set-Content (Join-Path $Destination "foresight_sdk_tail.log") -Encoding UTF8
                    } elseif ($name -eq "CurrentRound") {
                        Copy-Item $p (Join-Path $Destination "currentRound_latest.dat") -Force
                    }
                    Safe-Json ([ordered]@{
                        state="running"; updated_local=(Get-Date).ToString("o"); pid=$PID;
                        changed_source=$name; source_path=$p; destination=$Destination
                    }) (Join-Path $Destination "direct_bridge_status.json")
                }
            }
        }
        Start-Sleep -Milliseconds 450
    }
} catch {
    Safe-Json ([ordered]@{state="error"; time=(Get-Date).ToString("o"); pid=$PID; error=$_.Exception.Message}) (Join-Path $Destination "direct_bridge_status.json")
}
