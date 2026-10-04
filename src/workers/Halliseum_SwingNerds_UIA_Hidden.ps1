
param(
    [string]$OutRoot = "G:\My Drive\Halliseum Coach Bridge\SwingNerds_UIA"
)

$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null
$status = Join-Path $OutRoot "uia_status.json"

function Save-Status($state,$msg) {
    [ordered]@{state=$state; message=$msg; time=(Get-Date).ToString("o"); pid=$PID} |
        ConvertTo-Json -Depth 5 | Set-Content $status -Encoding UTF8
}

function SafeProp($el,[string]$p) {
    try {
        switch ($p) {
            "Name" { return [string]$el.Current.Name }
            "HelpText" { return [string]$el.Current.HelpText }
            "AutomationId" { return [string]$el.Current.AutomationId }
            default { return "" }
        }
    } catch { return "" }
}

function Get-Text($el) {
    $parts = New-Object System.Collections.Generic.List[string]
    $n = SafeProp $el "Name"; if ($n) { $parts.Add($n) }
    $h = SafeProp $el "HelpText"; if ($h) { $parts.Add($h) }
    try {
        $p=$null
        if ($el.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern,[ref]$p)) {
            if ($p.Current.Value) { $parts.Add([string]$p.Current.Value) }
        }
    } catch {}
    try {
        $p=$null
        if ($el.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern,[ref]$p)) {
            $t=$p.DocumentRange.GetText(-1); if ($t) { $parts.Add([string]$t) }
        }
    } catch {}
    return ($parts | Where-Object {$_ -and $_.Trim()} | Select-Object -Unique) -join "`n"
}


function Try-OpenActiveCoachSidebar($wins) {
    try {
        for ($w=0; $w -lt $wins.Count; $w++) {
            $els = $wins.Item($w).FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition)

            # Target ONLY the sidebar Active Coach button by its HelpText.
            # Do not invoke "Show active coaching" and do not SetFocus.
            for ($i=0; $i -lt $els.Count; $i++) {
                $el = $els.Item($i)
                try {
                    $ct = $el.Current.ControlType.ProgrammaticName
                    $help = SafeProp $el "HelpText"
                    if ($ct -eq "ControlType.Button" -and $help -match '(?i)^Active Coach:') {
                        $p=$null
                        if ($el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern,[ref]$p)) {
                            $p.Invoke()
                            Start-Sleep -Milliseconds 900
                            return $true
                        }
                    }
                } catch {}
            }
        }
    } catch {}
    return $false
}

function Restore-GSProFocus {
    # Active Coach only needs to be opened once. After that, give control
    # straight back to GSPro so normal club-up / club-down pedals keep working.
    try {
        $gs = Get-Process -Name "GSPro" -ErrorAction SilentlyContinue | Select-Object -First 1
        if($gs){
            $ws = New-Object -ComObject WScript.Shell
            [void]$ws.AppActivate($gs.Id)
        }
    } catch {}
}


function Test-ActiveCoachPanelVisible($lines) {
    # Do NOT use swing metrics like Head drift/Tempo to determine whether the
    # panel is open. Before the first swing those metrics may not exist yet.
    $hasCoachingHeader = $false
    $hasActiveCoachingControl = $false
    $hasShowActiveCoaching = $false

    foreach($line in $lines){
        $t = $line.Trim()
        if($t -eq "Coaching"){ $hasCoachingHeader = $true }
        if($t -eq "Active coaching"){ $hasActiveCoachingControl = $true }
        if($t -match '(?i)^Show active coaching'){ $hasShowActiveCoaching = $true }
    }

    return ($hasCoachingHeader -and $hasActiveCoachingControl) -or $hasShowActiveCoaching
}

function Extract-After($lines,$label) {
    for ($i=0; $i -lt $lines.Count-1; $i++) {
        if ($lines[$i].Trim() -eq $label) { return $lines[$i+1].Trim() }
    }
    return $null
}

Save-Status "waiting" "Waiting for SwingNerds"
$lastSig = ""
$activeCoachReady = $false
$activeCoachAttempts = 0
$lastActiveCoachAttempt = [datetime]::MinValue


while ($true) {
    $proc = Get-Process -Name "SwingNerdsClip" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) {
        Save-Status "waiting" "SwingNerds is not running"
        Start-Sleep -Seconds 2
        continue
    }

    try {
        $cond = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ProcessIdProperty,$proc.Id)
        $wins = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
            [System.Windows.Automation.TreeScope]::Children,$cond)

        $allText = New-Object System.Collections.Generic.List[string]
        for ($w=0; $w -lt $wins.Count; $w++) {
            $els = $wins.Item($w).FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition)
            for ($i=0; $i -lt $els.Count; $i++) {
                $t = Get-Text $els.Item($i)
                if ($t) {
                    foreach ($line in ($t -split "`r?`n")) {
                        if ($line.Trim()) { $allText.Add($line.Trim()) }
                    }
                }
            }
        }

        $lines = @($allText | Select-Object -Unique)
        $joined = $lines -join "`n"

        # Open the Active Coach sidebar during startup only.
        # Key fix: detect the PANEL itself, not swing metrics. Before the first
        # shot there may be no Head drift/Tempo yet even when Active Coach is open.
        if (-not $activeCoachReady) {
            $panelVisible = Test-ActiveCoachPanelVisible $lines

            if ($panelVisible) {
                $activeCoachReady = $true
                Save-Status "running" "Active Coach panel ready; GSPro focus restored"
                Restore-GSProFocus
            }
            elseif ($activeCoachAttempts -lt 12 -and ((Get-Date) - $lastActiveCoachAttempt).TotalSeconds -ge 1.5) {
                $lastActiveCoachAttempt = Get-Date
                $activeCoachAttempts++
                $opened = Try-OpenActiveCoachSidebar $wins

                if ($opened) {
                    Save-Status "running" "Opening Active Coach panel; attempt $activeCoachAttempts"
                    Restore-GSProFocus
                    Start-Sleep -Milliseconds 900
                    continue
                }
            }
            elseif ($activeCoachAttempts -ge 12) {
                Save-Status "running" "Active Coach did not auto-open; manual click may be needed"
            }
        }

        if ($joined -notmatch "(?i)Head drift" -or $joined -notmatch "(?i)Tempo") {
            if($activeCoachReady){
                Save-Status "running" "Active Coach ready; waiting for first swing metrics"
            } else {
                Save-Status "running" "SwingNerds found; waiting for Active Coach panel"
            }
            Start-Sleep -Seconds 2
            continue
        }

        $head = Extract-After $lines "Head drift"
        $lead = Extract-After $lines "Lead arm @ impact"
        $tempo = Extract-After $lines "Tempo"
        $lean = Extract-After $lines "Upper-body lean @ top"

        $hipSway = $null
        foreach ($line in $lines) {
            if ($line -match "(?i)hip sway now\s+([+\-]?[0-9.]+% of height)") {
                $hipSway = $matches[1]; break
            }
        }

        $carry=$null; $ball=$null; $club=$null; $smash=$null; $spin=$null; $path=$null; $aoa=$null
        foreach ($line in $lines) {
            if ($line -match "OverlayStatItem \{ Label = CARRY, Value = ([^,]+)") { $carry=$matches[1].Trim() }
            elseif ($line -match "OverlayStatItem \{ Label = BALL, Value = ([^,]+)") { $ball=$matches[1].Trim() }
            elseif ($line -match "OverlayStatItem \{ Label = CLUB, Value = ([^,]+)") { $club=$matches[1].Trim() }
            elseif ($line -match "OverlayStatItem \{ Label = SMASH, Value = ([^,]+)") { $smash=$matches[1].Trim() }
            elseif ($line -match "OverlayStatItem \{ Label = BACK SPIN, Value = ([^,]+)") { $spin=$matches[1].Trim() }
            elseif ($line -match "OverlayStatItem \{ Label = PATH, Value = ([^,]+)") { $path=$matches[1].Trim() }
            elseif ($line -match "OverlayStatItem \{ Label = AOA, Value = ([^,]+)") { $aoa=$matches[1].Trim() }
        }

        $tip = $null
        foreach ($line in $lines) {
            if ($line -match "(?i)(Quick transition|Nothing flagged|Solid strike|Sway|head movement|backswing|downswing)") {
                if ($line.Length -gt 20) { $tip = $line }
            }
        }

        $sig = "$head|$lead|$tempo|$lean|$carry|$ball|$smash|$tip"
        if ($sig -and $sig -ne $lastSig -and $head -and $head -ne "--") {
            $lastSig = $sig
            $obj = [ordered]@{
                captured_at=(Get-Date).ToString("o")
                head_drift=$head
                lead_arm_impact=$lead
                tempo=$tempo
                upper_body_lean_top=$lean
                hip_sway=$hipSway
                carry=$carry
                ball_speed=$ball
                club_speed=$club
                smash=$smash
                back_spin=$spin
                path=$path
                aoa=$aoa
                coaching_text=$tip
            }
            $json = $obj | ConvertTo-Json -Depth 6
            $json | Set-Content (Join-Path $OutRoot "latest_swingnerds.json") -Encoding UTF8
            Add-Content (Join-Path $OutRoot "swingnerds_history.jsonl") $json.Replace("`r","").Replace("`n"," ") -Encoding UTF8
            Save-Status "running" "Captured a new SwingNerds coaching result"
        } else {
            Save-Status "running" "SwingNerds coaching watcher active"
        }
    } catch {
        Save-Status "error" $_.Exception.Message
    }

    Start-Sleep -Seconds 2
}
