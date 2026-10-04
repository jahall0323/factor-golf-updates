$ErrorActionPreference="SilentlyContinue"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class HalliseumNative {
    [DllImport("user32.dll", SetLastError=true)] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'workers\FactorGolf_Display_Helper.ps1')
$versionFile=Join-Path $AppDir "app_version.txt"
$AppVersion="0.8.13"
try{
    if(Test-Path $versionFile){
        $vf=(Get-Content -LiteralPath $versionFile -Raw).Trim()
        if($vf -match '^\d+\.\d+\.\d+$'){$AppVersion=$vf}
    }
}catch{}
$ConfigPath=Join-Path $AppDir "config.json";$DefaultConfigPath=Join-Path $AppDir "config.default.json"
$mutex=New-Object System.Threading.Mutex($false,"HalliseumControlCenterSingleton")
if(-not $mutex.WaitOne(0,$false)){exit}
if(-not(Test-Path $ConfigPath)){Copy-Item $DefaultConfigPath $ConfigPath -Force}
$config=Get-Content $ConfigPath -Raw|ConvertFrom-Json
$defaults=Get-Content $DefaultConfigPath -Raw|ConvertFrom-Json
foreach($p in $defaults.PSObject.Properties){if(-not($config.PSObject.Properties.Name -contains $p.Name)){$config|Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value}}
# v0.8.5 display-routing defaults are additive and preserve older installs.
foreach($kv in @(@('ControlCenterScreenIndex',0),@('SettingsScreenIndex',0),@('PerformanceScreenIndex',0),@('GSProScreenIndex',-1),@('ClubCheatSheetScreenIndex',0),@('CoachCardScreenIndex',0),@('ControlCenterDisplayKey',''),@('SettingsDisplayKey',''),@('PerformanceDisplayKey',''),@('GSProDisplayKey','AUTO'),@('ClubCheatSheetDisplayKey',''),@('CoachCardDisplayKey',''),@('RangeNavCalibrated',$false),@('RangeNavCalibrationDate',''))){if(-not($config.PSObject.Properties.Name -contains $kv[0])){$config|Add-Member -NotePropertyName $kv[0] -NotePropertyValue $kv[1]}}
# v0.8.7 removes the old floating Coach Controls feature completely. Strip stale settings preserved by older config.json files.
foreach($obsolete in @('CoachControlsOverlayEnabled','CoachControlsScreenIndex','CoachControlsTopOffset','CoachControlsDisplayKey')){try{if($config.PSObject.Properties.Name -contains $obsolete){$config.PSObject.Properties.Remove($obsolete)}}catch{}}
# v0.8.8 removes the automatic startup Driver Cheat Sheet. Cheat Sheets now appear only after an actual club change.
try{if($config.PSObject.Properties.Name -contains 'ClubCheatSheetInitialDriverPrompt'){$config.PSObject.Properties.Remove('ClubCheatSheetInitialDriverPrompt')}}catch{}
# v0.8.9 direct updater foundation. HTTPS is primary when configured; the synced Drive folder remains a fallback only.
foreach($kv in @(@('UpdateFeedUrl','https://raw.githubusercontent.com/jahall0323/factor-golf-updates/main/latest.json'),@('UpdateChannel','stable'))){if(-not($config.PSObject.Properties.Name -contains $kv[0])){$config|Add-Member -NotePropertyName $kv[0] -NotePropertyValue $kv[1]}}
# v0.8.13 calibrated club-selector OCR. One click locates the real GSPro selector so club cards use GSPro truth instead of pedal-count inference.
foreach($kv in @(@('ClubSelectorCalibrated',$false),@('ClubSelectorX',0.0),@('ClubSelectorY',0.0),@('ClubSelectorCalibrationDate',''),@('ClubSelectorCropWidthRatio',0.28),@('ClubSelectorCropHeightRatio',0.16))){if(-not($config.PSObject.Properties.Name -contains $kv[0])){$config|Add-Member -NotePropertyName $kv[0] -NotePropertyValue $kv[1]}}
# v0.8.2 repair migration: these are core Coach Mode behaviors for the current Factor Golf build.
# Older installs may have preserved false values from earlier experiments, which silently prevented workers from starting.
try{
    $prior=[version]([string]$config.Version)
    if($prior -lt [version]'0.8.2'){
        $config.AutoOpenDrivingRange=$true
        $config.MinimizeForesightConnector=$true
        $config.ClubCheatSheetEnabled=$true
    }
}catch{}
# v0.8.3 connector-path repair: older auto-discovery could save GSProConnectRestoreFiles.exe,
# which is a repair utility, not the live connector. Never launch setup/restore/repair utilities as Coach Mode connectors.
try{
    $savedConnector=Expand-Path([string]$config.ForesightConnector)
}catch{$savedConnector=[string]$config.ForesightConnector}
try{
    if($savedConnector){
        $leaf=[IO.Path]::GetFileName($savedConnector)
        $badConnector=($leaf -match '(?i)(RestoreFiles|Restore|Repair|Setup|Installer|Install|Updater|Update|Uninstall|Patch)')
        if($badConnector){
            try{Get-Process -Name 'GSProConnectRestoreFiles' -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue}catch{}
            $fixed=''
            try{
                $dir=Split-Path -Parent $savedConnector
                $exact=Join-Path $dir 'GSProConnect.exe'
                if(Test-Path $exact){$fixed=$exact}
                if(-not$fixed -and(Test-Path $dir)){
                    $candidate=Get-ChildItem -LiteralPath $dir -Filter '*.exe' -File -ErrorAction SilentlyContinue|Where-Object{
                        $_.Name -match '(?i)(GSPro.*Connect|Visual.*Golf|VGP.*Connect|Foresight.*Connect)' -and
                        $_.Name -notmatch '(?i)(Restore|Repair|Setup|Install|Update|Uninstall|Patch)'
                    }|Sort-Object @{Expression={if($_.Name -ieq 'GSProConnect.exe'){0}elseif($_.Name -match '(?i)^VGP.*Connect'){1}elseif($_.Name -match '(?i)Visual.*Golf'){2}else{3}}},Name|Select-Object -First 1
                    if($candidate){$fixed=$candidate.FullName}
                }
            }catch{}
            $config.ForesightConnector=$fixed
        }
    }
}catch{}
# Migrate app-owned defaults to the current API model pair.
if(([string]$config.CoachModel -in @("gpt-5.6-sol","gpt-6-sol","gpt-6.1-sol")) -or ([string]$config.Version -in @("0.4.0 First Run","0.4.0","0.4.1"))){
    $config.CoachModel="gpt-6.1-sol"
    $config.FollowupModel="gpt-6-luna"
    $config.CoachModelInputPerMillion=2.0
    $config.CoachModelCachedInputPerMillion=0.1
    $config.CoachModelOutputPerMillion=10.0
    $config.FollowupModelInputPerMillion=0.1
    $config.FollowupModelCachedInputPerMillion=0.01
    $config.FollowupModelOutputPerMillion=0.5
}
$config.Version=$AppVersion
function Save-Config{$config|ConvertTo-Json -Depth 8|Set-Content $ConfigPath -Encoding UTF8}
Save-Config
function Sync-FactorGolfShortcutNames{
    try{
        $ws=New-Object -ComObject WScript.Shell
        foreach($folder in @([Environment]::GetFolderPath("Desktop"),[Environment]::GetFolderPath("Startup"))){
            if(-not$folder -or -not(Test-Path $folder)){continue}
            $old=Join-Path $folder "Halliseum Control Center.lnk"
            $new=Join-Path $folder "Factor Golf Sim Control Center.lnk"
            if(Test-Path $old){
                if(-not(Test-Path $new)){
                    $src=$ws.CreateShortcut($old);$dst=$ws.CreateShortcut($new)
                    $dst.TargetPath=$src.TargetPath;$dst.Arguments=$src.Arguments;$dst.WorkingDirectory=$src.WorkingDirectory;$dst.IconLocation=$src.IconLocation;$dst.Description="Factor Golf Sim Control Center";$dst.Save()
                }
                Remove-Item $old -Force -ErrorAction SilentlyContinue
            }
        }
    }catch{}
}
Sync-FactorGolfShortcutNames
function Expand-Path([string]$p){if(-not$p){return ""};[Environment]::ExpandEnvironmentVariables($p)}
function Resolve-ShortcutTarget([string[]]$patterns){
    $roots=@("$env:APPDATA\Microsoft\Windows\Start Menu\Programs","$env:ProgramData\Microsoft\Windows\Start Menu\Programs",[Environment]::GetFolderPath("Desktop"));$ws=New-Object -ComObject WScript.Shell
    foreach($root in $roots){if(Test-Path $root){foreach($pat in $patterns){$lnk=Get-ChildItem $root -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.BaseName -like $pat}|Select-Object -First 1;if($lnk){try{$t=$ws.CreateShortcut($lnk.FullName).TargetPath;if($t -and(Test-Path $t)){return $t}}catch{}}}}};return ""
}
function Pick-Exe([string]$title){$d=New-Object Microsoft.Win32.OpenFileDialog;$d.Title=$title;$d.Filter="Programs (*.exe)|*.exe|All files (*.*)|*.*";if($d.ShowDialog()){return $d.FileName};return ""}
function Get-AppPath([string]$key){
    $p=Expand-Path([string]$config.$key);if($p -and(Test-Path $p)){if($key -eq 'ForesightConnector' -and ([IO.Path]::GetFileName($p) -match '(?i)(Restore|Repair|Setup|Install|Update|Uninstall|Patch)')){$p=''}else{return $p}}
    $patterns=switch($key){"GSPro"{@("*GSPro*")};"SwingNerds"{@("*SwingNerds*")};"ForesightConnector"{@("*Foresight*Connect*","*Bushnell*Connect*","*GSPro*Connect*","*GS Pro*Connect*","*VGP*Connect*","*GameChanger*")};"FSXPlay"{@("*FSX Play*")};"FSXPro"{@("*FSX Pro*")};"FSXPremier"{@("*FSX Premier*","*Foresight*Premier*")};"Fairgrounds"{@("*Fairgrounds*")};"ChatGPT"{@("*ChatGPT*")};default{@("*$key*")}}
    $p=Resolve-ShortcutTarget $patterns;if($p){$config.$key=$p;Save-Config;return $p};return ""
}
function Find-GSProShortcut {
    # Launching the user's real Windows shortcut preserves any launcher arguments/update handoff that a raw EXE launch can bypass.
    $configured='';try{$configured=Expand-Path([string]$config.GSPro)}catch{}
    $roots=@([Environment]::GetFolderPath('Desktop'),"$env:APPDATA\Microsoft\Windows\Start Menu\Programs","$env:ProgramData\Microsoft\Windows\Start Menu\Programs")|Where-Object{$_ -and(Test-Path $_)}
    $ws=New-Object -ComObject WScript.Shell;$fallback=''
    foreach($r in $roots){
        foreach($lnk in @(Get-ChildItem -LiteralPath $r -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.BaseName -match '(?i)GS\s*Pro|GSPro'})){
            try{
                $sc=$ws.CreateShortcut($lnk.FullName);$target=[Environment]::ExpandEnvironmentVariables([string]$sc.TargetPath)
                if(-not$target -or -not(Test-Path $target)){continue}
                if($configured -and [string]::Equals($target,$configured,[StringComparison]::OrdinalIgnoreCase)){return $lnk.FullName}
                if(-not$fallback -and $target -match '(?i)GSPro' -and $target -notmatch '(?i)(Restore|Repair|Setup|Install|Uninstall|Patch)'){$fallback=$lnk.FullName}
            }catch{}
        }
    }
    # Only use an unmatched shortcut when no configured executable exists. This avoids crossing stable/beta installs accidentally.
    if(-not$configured -or -not(Test-Path $configured)){return $fallback}
    return ''
}
function Launch-App([string]$key,[string]$friendly,[bool]$ask=$true){
    if($key -eq 'GSPro'){
        try{$shortcut=Find-GSProShortcut;if($shortcut){Start-Process -FilePath $shortcut|Out-Null;Set-Status 'GSPro launched through its Windows shortcut so its normal update/launcher path is preserved.';return $true}}catch{}
    }
    $p=Get-AppPath $key;if(-not$p -and $ask){$p=Pick-Exe "Find $friendly";if($p){$config.$key=$p;Save-Config}}
    if($p){Start-Process $p|Out-Null;Set-Status "$friendly launched.";return $true};Set-Status "$friendly path is not configured.";return $false
}
function Is-Running([string]$name){[bool](Get-Process -Name $name -ErrorAction SilentlyContinue)}
function Set-Status([string]$text){if($StatusText){$StatusText.Text=$text;$StatusText.ToolTip=$text}}
function Restore-GSProFocus{try{$g=Get-Process -Name "GSPro" -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1;if($g){[HalliseumNative]::ShowWindowAsync($g.MainWindowHandle,9)|Out-Null;Start-Sleep -Milliseconds 80;[HalliseumNative]::SetForegroundWindow($g.MainWindowHandle)|Out-Null;$w=New-Object -ComObject WScript.Shell;[void]$w.AppActivate($g.Id)}}catch{}}
function Test-LocalApiKey{
    $secret=Join-Path $AppDir "secrets\openai_api_key.dpapi"
    if(-not(Test-Path $secret)){return $false}
    try{$enc=(Get-Content $secret -Raw).Trim();$sec=ConvertTo-SecureString $enc;$b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec);try{$k=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b);return ($k -and $k.StartsWith("sk-") -and $k.Length -gt 20)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)}}catch{return $false}
}

function Send-Mulligan{try{Restore-GSProFocus;Start-Sleep -Milliseconds 80;[System.Windows.Forms.SendKeys]::SendWait("^m");Set-Status "Mulligan sent to GSPro (Ctrl+M)."}catch{}}
function Minimize-ConnectorWindows{
    try{
        $procs=Get-Process|Where-Object{
            $_.MainWindowHandle -ne 0 -and (
                $_.MainWindowTitle -match '(?i)(Foresight|Bushnell|GSPro|GS Pro).*(Connect|Connector|Launch)' -or
                $_.MainWindowTitle -match '(?i)^(Foresight Connect|GSPro Connect|GS Pro Connect)$' -or
                $_.ProcessName -match '(?i)(Foresight|Bushnell|GSPro|VGP).*Connect'
            )
        }
        foreach($p in $procs){[HalliseumNative]::ShowWindowAsync($p.MainWindowHandle,6)|Out-Null}
    }catch{}
}
function Find-RunningConnectorPath{
    try{
        $p=Get-Process|Where-Object{
            ($_.Path -and (Test-Path $_.Path)) -and (
                $_.MainWindowTitle -match '(?i)(Foresight|Bushnell|GSPro|GS Pro).*(Connect|Connector)' -or
                $_.ProcessName -match '(?i)(Foresight|Bushnell|GSPro|VGP).*Connect'
            )
        }|Select-Object -First 1
        if($p -and ([IO.Path]::GetFileName([string]$p.Path) -notmatch '(?i)(Restore|Repair|Setup|Install|Update|Uninstall|Patch)')){return [string]$p.Path}
    }catch{}
    return ''
}
function Resolve-ForesightConnector{
    $p=Get-AppPath 'ForesightConnector';if($p){return $p}
    $p=Find-RunningConnectorPath;if($p){$config.ForesightConnector=$p;Save-Config;return $p}
    $roots=@($env:LOCALAPPDATA,$env:ProgramFiles,${env:ProgramFiles(x86)},'C:\GSProV1')|Where-Object{$_ -and (Test-Path $_)}
    foreach($r in $roots){
        try{
            $hit=Get-ChildItem -LiteralPath $r -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue|Where-Object{($_.Name -match '(?i)(Foresight|Bushnell|GSPro|VGP).*Connect|GameChanger') -and ($_.Name -notmatch '(?i)(Restore|Repair|Setup|Install|Update|Uninstall|Patch)')}|Select-Object -First 1
            if($hit){$config.ForesightConnector=$hit.FullName;Save-Config;return $hit.FullName}
        }catch{}
    }
    return ''
}
function Stop-StaleHalliseumWorkers{try{$ps=Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object{$_.CommandLine -match 'Halliseum_Direct_Bridge_Hidden\.ps1|Halliseum_SwingNerds_UIA_Hidden\.ps1|Halliseum_Coach_Set_API\.ps1|Halliseum_Coach_Card\.ps1|Halliseum_Range_Nav\.ps1|Halliseum_Minimize_Connectors\.ps1|Halliseum_Club_Cheat_Watcher\.ps1|Halliseum_Club_Cheat_Sheet\.ps1|Halliseum_Coach_Controls\.ps1|Halliseum_Voice_Test\.ps1|Halliseum_Focus_GSPro\.ps1|Halliseum_Range_Calibration\.ps1'};foreach($p in $ps){try{Stop-Process -Id $p.ProcessId -Force}catch{}};Start-Sleep -Milliseconds 300}catch{}}
function Start-HiddenWorker([string]$script,[string]$workerArgs=""){
    $full=Join-Path $AppDir "workers\$script"
    if(-not(Test-Path $full)){return $null}
    $commandLine="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$full`" $workerArgs"
    try{
        $p=Start-Process powershell.exe -ArgumentList $commandLine -WindowStyle Hidden -PassThru
        try{
            $log=Join-Path $coachRoot 'worker_launch_status.log'
            Add-Content -LiteralPath $log -Value ("[{0}] START {1} pid={2} workerArgs={3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$script,$p.Id,$workerArgs) -Encoding UTF8
        }catch{}
        return $p
    }catch{
        try{Add-Content -LiteralPath (Join-Path $coachRoot 'worker_launch_status.log') -Value ("[{0}] FAILED {1}: {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$script,$_.Exception.Message) -Encoding UTF8}catch{}
        return $null
    }
}

$stateRoot=Expand-Path([string]$config.GoogleDriveRoot);if(-not$stateRoot){$stateRoot="G:\My Drive\Halliseum Coach Bridge"}
$coachRoot=Join-Path $stateRoot "UltimateCoach";New-Item -ItemType Directory -Path $coachRoot -Force|Out-Null
$stateFile=Join-Path $coachRoot "session_state.json";$runtimeFile=Join-Path $coachRoot "coach_runtime.json";$budgetFile=Join-Path $coachRoot "budget.json";$actionRequestFile=Join-Path $coachRoot "coach_action_request.json"
$script:BridgeProc=$null;$script:UIAProc=$null;$script:CheatWatcherProc=$null;$script:UltimateActive=$false
function Write-SessionState([datetime]$start,[string]$club=''){
    if(-not$club -and(Test-Path $stateFile)){try{$old=Get-Content $stateFile -Raw|ConvertFrom-Json;$club=[string]$old.current_club}catch{}}
    [ordered]@{ultimate_active=$script:UltimateActive;set_started_at=$start.ToString("o");current_club=$club;updated=(Get-Date).ToString("o");bridge_pid=$(if($script:BridgeProc){$script:BridgeProc.Id}else{$null});uia_pid=$(if($script:UIAProc){$script:UIAProc.Id}else{$null})}|ConvertTo-Json -Depth 5|Set-Content $stateFile -Encoding UTF8
}
function Read-SetStart{if(Test-Path $stateFile){try{$s=Get-Content $stateFile -Raw|ConvertFrom-Json;return [datetime]::Parse([string]$s.set_started_at)}catch{}};Get-Date}
function Get-CoachBusy{if(Test-Path $runtimeFile){try{$r=Get-Content $runtimeFile -Raw|ConvertFrom-Json;return ([string]$r.state -in @("collecting","thinking","retrying","card","listening","thinking_followup","speaking_followup"))}catch{}};return $false}

function Wait-GSProReady([int]$seconds=25){
    $deadline=(Get-Date).AddSeconds($seconds)
    while((Get-Date) -lt $deadline){
        try{$g=Get-Process -Name 'GSPro' -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle -ne 0}|Select-Object -First 1;if($g){return $true}}catch{}
        Start-Sleep -Milliseconds 500
    }
    return $false
}
function Start-UltimateCoach{
    if($script:UltimateActive){Set-Status "Coach Mode is already armed.";Restore-GSProFocus;return}
    $script:UltimateActive=$true
    if($StartCoachButton){$StartCoachButton.IsEnabled=$false};if($StopCoachButton){$StopCoachButton.IsEnabled=$true}
    Set-Status "Starting Coach Mode...";Stop-StaleHalliseumWorkers
    Remove-Item $actionRequestFile -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $coachRoot 'worker_launch_status.log') -Force -ErrorAction SilentlyContinue
    [ordered]@{request_id="startup";state="starting";message="Starting a fresh Coach Mode session.";dismiss=$false;updated=(Get-Date).ToString("o")}|ConvertTo-Json|Set-Content $runtimeFile -Encoding UTF8
    $rangePath=Join-Path $coachRoot "range_nav_status.json"
    [ordered]@{state="waiting";message="Coach Mode requested Practice > GS Pro Practice Range.";updated=(Get-Date).ToString("o")}|ConvertTo-Json|Set-Content $rangePath -Encoding UTF8

    # Start GSPro first, then immediately start independent workers. Do not make one feature wait on another.
    if(-not(Is-Running 'GSPro')){Launch-App 'GSPro' 'GSPro' $false|Out-Null}
    # AUTO leaves GSPro wherever its live window actually opens. A specific monitor is an explicit override.
    try{if([string]$config.GSProDisplayKey -and [string]$config.GSProDisplayKey -ne 'AUTO'){if(Wait-GSProReady 8){Move-FGProcessToConfiguredScreen -ProcessName 'GSPro' -Config $config -KeyProperty 'GSProDisplayKey' -IndexProperty 'GSProScreenIndex'|Out-Null}}}catch{}
    if([bool]$config.AutoOpenDrivingRange){Start-HiddenWorker 'Halliseum_Range_Nav.ps1' "-Root `"$stateRoot`" -AppDir `"$AppDir`""|Out-Null}
    if([bool]$config.ClubCheatSheetEnabled){$script:CheatWatcherProc=Start-HiddenWorker 'Halliseum_Club_Cheat_Watcher.ps1' "-Root `"$stateRoot`" -AppDir `"$AppDir`""}
    if([bool]$config.MinimizeForesightConnector){Start-HiddenWorker 'Halliseum_Minimize_Connectors.ps1' "-Root `"$stateRoot`""|Out-Null}

    # Give GSPro a short chance to create its main window, but never block the other workers behind this wait.
    $gsReady=Wait-GSProReady 8
    if(-not$gsReady){Set-Status 'Coach Mode is armed. Factor Golf is still waiting for the GSPro window in the background.'}

    # Only launch a connector executable when the user already has a valid explicit path saved.
    # Modern GSPro/Foresight setups can spawn their own connector, which the minimizer above watches for.
    $connector='';try{$candidate=Expand-Path([string]$config.ForesightConnector);if($candidate -and(Test-Path $candidate) -and ([IO.Path]::GetFileName($candidate) -notmatch '(?i)(Restore|Repair|Setup|Install|Update|Uninstall|Patch)')){$connector=$candidate}}catch{}
    $connectorPid=0
    if($connector){
        $running=Get-Process|Where-Object{try{$_.Path -and ([string]::Equals($_.Path,$connector,[StringComparison]::OrdinalIgnoreCase))}catch{$false}}|Select-Object -First 1
        if(-not$running){try{$running=Start-Process $connector -PassThru;Start-Sleep -Milliseconds 500}catch{}}
        if($running){try{$connectorPid=[int]$running.Id}catch{}}
        if([bool]$config.MinimizeForesightConnector){Start-HiddenWorker 'Halliseum_Minimize_Connectors.ps1' "-Root `"$stateRoot`" -PreferredPid $connectorPid -ConnectorPath `"$connector`""|Out-Null}
    }

    if(-not(Is-Running 'SwingNerdsClip')){Launch-App 'SwingNerds' 'SwingNerds' $false|Out-Null;Start-Sleep -Milliseconds 500}
    $bridgeDest=Join-Path $stateRoot 'Direct';$uiaDest=Join-Path $stateRoot 'SwingNerds_UIA';New-Item -ItemType Directory -Path $bridgeDest,$uiaDest -Force|Out-Null
    $script:BridgeProc=Start-HiddenWorker 'Halliseum_Direct_Bridge_Hidden.ps1' "-Destination `"$bridgeDest`""
    $script:UIAProc=Start-HiddenWorker 'Halliseum_SwingNerds_UIA_Hidden.ps1' "-OutRoot `"$uiaDest`""
    # Preserve the last known GSPro club instead of forcing Driver. The watcher silently reconciles to GSPro before the first club-change card.
    Write-SessionState (Get-Date)
    Hide-ControlCenterForMode 'Coach Mode' @('GSPro')
    Restore-GSProFocus;Start-HiddenWorker 'Halliseum_Focus_GSPro.ps1' ''|Out-Null
    Set-Status 'Coach Mode armed. Factor Golf is opening Practice > GS Pro Practice Range first, then it will show club/coaching overlays.'
}
function Stop-UltimateCoach{
    $script:UltimateActive=$false
    if($StartCoachButton){$StartCoachButton.IsEnabled=$true}
    if($StopCoachButton){$StopCoachButton.IsEnabled=$false}
    if($ModeBadge){$ModeBadge.Text="MULLIGAN MODE";$ModeBadge.Foreground="#80C89F"}
    try{if($script:BridgeProc -and -not$script:BridgeProc.HasExited){Stop-Process -Id $script:BridgeProc.Id -Force}}catch{}
    try{if($script:UIAProc -and -not$script:UIAProc.HasExited){Stop-Process -Id $script:UIAProc.Id -Force}}catch{}
    try{if($script:CheatWatcherProc -and -not$script:CheatWatcherProc.HasExited){Stop-Process -Id $script:CheatWatcherProc.Id -Force}}catch{}
    $script:BridgeProc=$null;$script:UIAProc=$null;$script:CheatWatcherProc=$null
    Stop-StaleHalliseumWorkers;Write-SessionState(Get-Date);Set-Status "Coach Mode stopped. The coach pedal is back to Mulligan mode.";Restore-ControlCenterHome
}
function Enter-GSProOnly{
    if($script:UltimateActive){Stop-UltimateCoach}
    $rangePath=Join-Path $coachRoot "range_nav_status.json"
    [ordered]@{state="disabled";message="GSPro Only mode: Driving Range automation is OFF.";updated=(Get-Date).ToString("o")}|ConvertTo-Json|Set-Content $rangePath -Encoding UTF8
    if(-not(Is-Running "GSPro")){Launch-App "GSPro" "GSPro"|Out-Null}else{Set-Status "GSPro Only mode. Driving Range automation is off."}
    try{if([string]$config.GSProDisplayKey -and [string]$config.GSProDisplayKey -ne 'AUTO'){if(Wait-GSProReady 8){Move-FGProcessToConfiguredScreen -ProcessName 'GSPro' -Config $config -KeyProperty 'GSProDisplayKey' -IndexProperty 'GSProScreenIndex'|Out-Null}}}catch{}
    Hide-ControlCenterForMode 'GSPro Only' @('GSPro')
    Start-Sleep -Milliseconds 250
    Restore-GSProFocus
}
function Invoke-CoachSet{
    if(-not$script:UltimateActive){Send-Mulligan;return}
    if(Get-CoachBusy){Set-Status "Coach is already talking/listening. Pedal press ignored so the set cycle cannot get lost.";return}
    $start=Read-SetStart;$now=Get-Date;Write-SessionState $now
    [ordered]@{request_id="pending";state="collecting";message="Set closed. New set started now.";dismiss=$false;updated=(Get-Date).ToString("o")}|ConvertTo-Json|Set-Content $runtimeFile -Encoding UTF8
    Set-Status "Set closed. New set started immediately. Building local summary and coaching response..."
    $worker=Join-Path $AppDir "workers\Halliseum_Coach_Set_API.ps1";$args="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$worker`" -SetStartIso `"$($start.ToString('o'))`" -Root `"$stateRoot`" -AppDir `"$AppDir`"";Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden|Out-Null
}
function Show-PreviewCard{if(Get-CoachBusy){Set-Status "Wait until the current coach conversation ends before previewing the card.";return};$script=Join-Path $AppDir "workers\Halliseum_Coach_Card.ps1";Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Root `"$stateRoot`" -AppDir `"$AppDir`" -Preview" -WindowStyle Hidden|Out-Null;Set-Status "Coach Card preview opened in a closable projector overlay."}
function Setup-ApiKey{Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $AppDir 'SETUP_OPENAI_API_KEY.ps1')`"" -WindowStyle Hidden}

$script:UpdateManifest=$null
$script:UpdateSource=''
$script:LastUpdateCheck=[datetime]::MinValue
function Get-UpdateRoot{
    $root=Join-Path $stateRoot "Updates"
    try{New-Item -ItemType Directory -Path $root -Force|Out-Null}catch{}
    return $root
}
function Get-DirectUpdateManifest{
    $feed='';try{$feed=[string]$config.UpdateFeedUrl}catch{}
    if(-not$feed){return $null}
    try{
        $uri=[uri]$feed
        if($uri.Scheme -ne 'https'){throw 'Update feed must use HTTPS.'}
        try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{}
        $sep=if($feed.Contains('?')){'&'}else{'?'}
        $cb=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $m=Invoke-RestMethod -Uri ($feed+$sep+'fgcb='+$cb) -Method Get -TimeoutSec 10 -Headers @{'Cache-Control'='no-cache';'User-Agent'="FactorGolf/$AppVersion"}
        if(-not$m -or -not$m.version -or -not$m.sha256 -or -not$m.package_url){throw 'Direct update manifest is missing required fields.'}
        $pkg=[uri]([string]$m.package_url)
        if($pkg.Scheme -ne 'https'){throw 'Update package URL must use HTTPS.'}
        $m|Add-Member -NotePropertyName '_source' -NotePropertyValue 'https' -Force
        return $m
    }catch{
        try{Add-Content -LiteralPath (Join-Path $AppDir 'update.log') -Value ("{0}  Direct update check failed: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$_.Exception.Message) -Encoding UTF8}catch{}
        return $null
    }
}
function Get-LocalUpdateManifest{
    try{
        $manifestPath=Join-Path (Get-UpdateRoot) 'latest.json'
        if(-not(Test-Path $manifestPath)){return $null}
        $m=Get-Content $manifestPath -Raw|ConvertFrom-Json
        if(-not$m.version -or -not$m.package){return $null}
        $package=Join-Path (Get-UpdateRoot) ([string]$m.package)
        if(-not(Test-Path $package)){return $null}
        $m|Add-Member -NotePropertyName '_source' -NotePropertyValue 'local' -Force
        $m|Add-Member -NotePropertyName '_localPackagePath' -NotePropertyValue $package -Force
        return $m
    }catch{return $null}
}
function Check-HalliseumUpdate([bool]$announce=$false){
    try{
        $script:LastUpdateCheck=Get-Date
        $current=[version]$AppVersion
        $candidates=@()
        $direct=Get-DirectUpdateManifest;if($direct){$candidates+=$direct}
        $local=Get-LocalUpdateManifest;if($local){$candidates+=$local}
        $best=$null
        foreach($m in $candidates){
            try{$v=[version]([string]$m.version)}catch{continue}
            if($v -le $current){continue}
            if(-not$best){$best=$m;continue}
            $bv=[version]([string]$best.version)
            if($v -gt $bv -or ($v -eq $bv -and [string]$m._source -eq 'https')){$best=$m}
        }
        if($best){
            $script:UpdateManifest=$best;$script:UpdateSource=[string]$best._source
            if($UpdateButton){$UpdateButton.Content="INSTALL v$($best.version) UPDATE"}
            if($UpdateStatus){
                $src=if($script:UpdateSource -eq 'https'){'Direct HTTPS update ready.'}else{'Local update fallback ready.'}
                $UpdateStatus.Text=if($best.notes){$src+' '+[string]$best.notes}else{$src};$UpdateStatus.Foreground="#78D6A2"
            }
            if($announce){Set-Status "Factor Golf v$($best.version) is ready. Click INSTALL UPDATE."}
            return $true
        }
        $script:UpdateManifest=$null;$script:UpdateSource=''
        if($UpdateButton){$UpdateButton.Content="CHECK FOR UPDATE"}
        if($UpdateStatus){$UpdateStatus.Text="Factor Golf v$AppVersion is current.";$UpdateStatus.Foreground="#BFD2C7"}
        if($announce){Set-Status "Factor Golf v$AppVersion is current."}
    }catch{
        $script:UpdateManifest=$null;$script:UpdateSource=''
        if($UpdateStatus){$UpdateStatus.Text="Update check failed. Direct feed and local fallback were unavailable.";$UpdateStatus.Foreground="#F0A96A"}
        if($announce){Set-Status "Could not reach the Factor Golf update feed."}
    }
    return $false
}
function Start-HalliseumUpdate{
    if(-not$script:UpdateManifest){[void](Check-HalliseumUpdate $true);return}
    $m=$script:UpdateManifest
    $answer=[System.Windows.MessageBox]::Show("Install Factor Golf Sim Control Center v$($m.version) now?`n`nThe Control Center will close, verify the update, install it, and reopen. Your settings and encrypted API key are preserved.","Factor Golf Update",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
    if($answer -ne [System.Windows.MessageBoxResult]::Yes){return}
    $updater=Join-Path $AppDir "workers\Halliseum_Self_Update.ps1"
    $hash=if($m.sha256){[string]$m.sha256}else{""}
    if($script:UpdateSource -eq 'https'){
        $packageUrl=[string]$m.package_url
        $args="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updater`" -AppDir `"$AppDir`" -PackageUrl `"$packageUrl`" -Version `"$($m.version)`" -ExpectedSha256 `"$hash`""
    }else{
        $package=[string]$m._localPackagePath
        if(-not$package -or -not(Test-Path $package)){Set-Status "Local update fallback is no longer available. Check again.";return}
        $args="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updater`" -AppDir `"$AppDir`" -PackagePath `"$package`" -Version `"$($m.version)`" -ExpectedSha256 `"$hash`""
    }
    Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden|Out-Null
    Set-Status "Installing Factor Golf v$($m.version)..."
    $window.Close()
}
function Open-Config{
    $settings=Join-Path $AppDir "workers\Halliseum_Settings.ps1"
    if(Test-Path $settings){
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$settings`" -AppDir `"$AppDir`"" -WindowStyle Hidden|Out-Null
        Set-Status "Factor Golf Settings opened."
    }else{Start-Process notepad.exe $ConfigPath}
}

function Open-Performance{
    $p=Join-Path $AppDir 'workers\Halliseum_Performance.ps1';if(Test-Path $p){Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$p`" -Root `"$stateRoot`" -AppDir `"$AppDir`"" -WindowStyle Hidden|Out-Null;Set-Status 'Performance opened.'}
}
function Show-FSXMenu{
    [xml]$fx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="FSX" Width="560" Height="420" WindowStartupLocation="CenterOwner" Background="#08110D" Foreground="#FFFFFF" ResizeMode="NoResize">
<Window.Resources>
 <Style TargetType="Button"><Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#173A2A"/><Setter Property="BorderBrush" Value="#58A67B"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="12,8"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#22513B"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Background" Value="#10291E"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Background" Value="#26342D"/><Setter Property="Foreground" Value="#E9F2ED"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
</Window.Resources>
<Grid Margin="24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><StackPanel><TextBlock Text="FSX" FontSize="30" FontWeight="Bold" Foreground="#FFFFFF"/><TextBlock Text="Choose the Foresight experience." Foreground="#D3E6DA" FontSize="14" Margin="0,5,0,16"/></StackPanel><UniformGrid Grid.Row="1" Rows="3"><Button x:Name="Play" Content="FSX PLAY" FontSize="22" FontWeight="Bold" Margin="0,5"/><Button x:Name="Pro" Content="FSX PRO" FontSize="22" FontWeight="Bold" Margin="0,5"/><Button x:Name="Premier" Content="FSX PREMIER" FontSize="22" FontWeight="Bold" Margin="0,5"/></UniformGrid><Button x:Name="Cancel" Grid.Row="2" Content="BACK" Height="42" Margin="0,14,0,0"/></Grid></Window>
'@
    $rr=New-Object System.Xml.XmlNodeReader $fx;$fw=[Windows.Markup.XamlReader]::Load($rr);$fw.Owner=$window;$fw.FindName('Play').Add_Click({Launch-App 'FSXPlay' 'FSX Play'|Out-Null;$fw.Close();Hide-ControlCenterForMode 'FSX Play' @('FSXPlay')});$fw.FindName('Pro').Add_Click({Launch-App 'FSXPro' 'FSX Pro'|Out-Null;$fw.Close();Hide-ControlCenterForMode 'FSX Pro' @('FSXPro')});$fw.FindName('Premier').Add_Click({Launch-App 'FSXPremier' 'FSX Premier'|Out-Null;$fw.Close();Hide-ControlCenterForMode 'FSX Premier' @('FSXPremier')});$fw.FindName('Cancel').Add_Click({$fw.Close()});$fw.ShowDialog()|Out-Null
}
function Launch-CurrentMode([string]$mode){
 switch($mode){
  'Coach Mode'{Start-UltimateCoach}
  'GSPro Only'{Enter-GSProOnly}
  'SwingNerds'{Launch-App 'SwingNerds' 'SwingNerds'|Out-Null;Hide-ControlCenterForMode 'SwingNerds' @('SwingNerdsClip','swingnerds-pose')}
  'FSX'{Show-FSXMenu}
  'Fairgrounds'{Launch-App 'Fairgrounds' 'Fairgrounds'|Out-Null;Hide-ControlCenterForMode 'Fairgrounds' @('Fairgrounds')}
  'Performance'{Open-Performance}
  'Settings'{Open-Config}
 }
}

[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Factor Golf Sim Control Center" Width="1280" Height="820" MinWidth="1050" MinHeight="680" WindowStartupLocation="Manual" WindowState="Normal" Background="#07100C" Foreground="White">
 <Window.Resources>
  <Style x:Key="BaseButton" TargetType="Button">
   <Setter Property="Background" Value="#173A2A"/><Setter Property="Foreground" Value="#FFFFFF"/>
   <Setter Property="BorderBrush" Value="#58A67B"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Padding" Value="16,10"/><Setter Property="FontWeight" Value="Bold"/>
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="Button">
      <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
       <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" Margin="{TemplateBinding Padding}"/>
      </Border>
      <ControlTemplate.Triggers>
       <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#22513B"/></Trigger>
       <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="#10291E"/></Trigger>
       <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Background" Value="#26342D"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#60766A"/><Setter Property="Foreground" Value="#E9F2ED"/><Setter Property="Cursor" Value="Arrow"/></Trigger>
      </ControlTemplate.Triggers>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>
  <Style TargetType="Button" BasedOn="{StaticResource BaseButton}"/>
  <Style x:Key="Ghost" TargetType="Button" BasedOn="{StaticResource BaseButton}"><Setter Property="Background" Value="#102219"/><Setter Property="BorderBrush" Value="#4C6A59"/></Style>
 </Window.Resources>
 <Grid Margin="34"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid MinHeight="92"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel VerticalAlignment="Center"><TextBlock Text="FACTOR GOLF" Foreground="#D9B84C" FontSize="16" FontWeight="Bold"/><TextBlock Text="SIM CONTROL CENTER" FontSize="34" FontWeight="Bold"/><TextBlock Text="Choose a mode." Foreground="#C4D7CC" FontSize="14"/></StackPanel><StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"><Button x:Name="StopCoachButton" Content="STOP COACH" Width="130" Height="42" Margin="0,0,10,0" Style="{StaticResource Ghost}" IsEnabled="False"/><Button x:Name="UpdateButton" Content="CHECK FOR UPDATE" Width="235" Height="42" Style="{StaticResource Ghost}"/></StackPanel></Grid>
  <Grid x:Name="ModeGrid" Grid.Row="1" Margin="0,26,0,22">
   <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="*"/><RowDefinition Height="*"/></Grid.RowDefinitions>
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <Button x:Name="CoachModeButton" Grid.Row="0" Grid.Column="0" Margin="7" Background="#123524" Foreground="White" BorderBrush="#4A946B" BorderThickness="2" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="COACH MODE" FontSize="28" FontWeight="Bold"/><TextBlock Text="BLP + SwingNerds coaching, Club Cheat Sheets, voice follow-up, and one-club set tracking." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Button>
   <Button x:Name="GSProOnlyButton" Grid.Row="0" Grid.Column="1" Margin="7" Background="#0D1D15" Foreground="White" BorderBrush="#294735" BorderThickness="1" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="GSPRO ONLY" FontSize="28" FontWeight="Bold"/><TextBlock Text="Launch or focus GSPro with coaching off and normal Mulligan behavior." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Button>
   <Button x:Name="SwingNerdsButton" Grid.Row="0" Grid.Column="2" Margin="7" Background="#0D1D15" Foreground="White" BorderBrush="#294735" BorderThickness="1" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="SWINGNERDS" FontSize="28" FontWeight="Bold"/><TextBlock Text="Open swing capture and Active Coach analysis tools." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Button>
   <Button x:Name="FSXButton" Grid.Row="1" Grid.Column="0" Margin="7" Background="#0D1D15" Foreground="White" BorderBrush="#294735" BorderThickness="1" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="FSX" FontSize="28" FontWeight="Bold"/><TextBlock Text="Choose FSX Play, FSX Pro, or FSX Premier." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Button>
   <Button x:Name="FairgroundsButton" Grid.Row="1" Grid.Column="1" Margin="7" Background="#0D1D15" Foreground="White" BorderBrush="#294735" BorderThickness="1" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="FAIRGROUNDS" FontSize="28" FontWeight="Bold"/><TextBlock Text="Launch Fairgrounds as its own simulator experience." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Button>
   <Button x:Name="PerformanceButton" Grid.Row="1" Grid.Column="2" Margin="7" Background="#0D1D15" Foreground="White" BorderBrush="#294735" BorderThickness="1" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="PERFORMANCE" FontSize="28" FontWeight="Bold"/><TextBlock Text="Browse sessions by date and view your living My Bag carry map." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Button>
   <Border Grid.Row="2" Grid.Column="0" Margin="7" Background="#0B1711" BorderBrush="#6F6331" BorderThickness="1" CornerRadius="8" Padding="22"><StackPanel VerticalAlignment="Center"><Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Text="AI CADDY" FontSize="26" FontWeight="Bold" Foreground="#E6C65B"/><Border Grid.Column="1" Background="#2B2A1D" BorderBrush="#8D7E3E" BorderThickness="1" CornerRadius="10" Padding="9,4"><TextBlock Text="COMING SOON" Foreground="#E6C65B" FontSize="11" FontWeight="Bold"/></Border></Grid><TextBlock Text="Live club selection, hazard strategy, and shot planning based on your game." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,8,0,0"/></StackPanel></Border>
   <Button x:Name="SettingsButton" Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" Margin="7" Background="#0B1711" Foreground="White" BorderBrush="#294735" BorderThickness="1" Padding="22" HorizontalContentAlignment="Stretch" VerticalContentAlignment="Stretch"><StackPanel VerticalAlignment="Center"><TextBlock Text="SETTINGS" FontSize="26" FontWeight="Bold"/><TextBlock Text="Golfer Experience, display routing, GSPro range calibration, voice, persona, Club Cheat Sheets, startup, paths, and Coach Mode behavior." FontSize="14" Foreground="#D8E6DE" TextWrapping="Wrap" Margin="0,7,0,0"/></StackPanel></Button>
  </Grid>
  <Grid Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition Width="1.2*"/><ColumnDefinition Width="0.8*"/></Grid.ColumnDefinitions><Border Background="#0B1711" BorderBrush="#1B3025" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,8,0"><StackPanel><TextBlock Text="SYSTEM" Foreground="#C8DAD0" FontSize="12" FontWeight="Bold"/><TextBlock x:Name="SystemText" Text="GSPro offline | SwingNerds offline | Coach AI setup" FontSize="15" Margin="0,6,0,0"/><TextBlock x:Name="RangeStatus" Text="Driving Range automation idle" Foreground="#BFD2C7" FontSize="12" Margin="0,5,0,0" TextWrapping="Wrap"/></StackPanel></Border><Border Grid.Column="1" Background="#0B1711" BorderBrush="#1B3025" BorderThickness="1" CornerRadius="12" Padding="16" Margin="8,0,0,0"><StackPanel><TextBlock Text="AI BUDGET" Foreground="#C8DAD0" FontSize="12" FontWeight="Bold"/><TextBlock x:Name="BudgetText" Text="$0.00 / $20.00" FontSize="20" FontWeight="Bold" Margin="0,5,0,0"/><TextBlock x:Name="UpdateStatus" Text="Factor Golf update status" Foreground="#BFD2C7" FontSize="11" TextWrapping="Wrap" Margin="0,4,0,0"/></StackPanel></Border></Grid>
  <Border Grid.Row="3" Background="#09140F" BorderBrush="#1B3025" BorderThickness="1" CornerRadius="12" Padding="14" Margin="0,14,0,0"><Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock x:Name="StatusText" Text="Home ready." FontSize="14"/><TextBlock x:Name="RuntimeText" Text="No active coach conversation." FontSize="12" Foreground="#BFD2C7" Margin="0,3,0,0"/></StackPanel><StackPanel Grid.Column="1" Orientation="Horizontal"><Button x:Name="EndSetButton" Content="END SET &amp; COACH ME" Width="210" Height="44" Margin="0,0,10,0" Background="#2E8057" Foreground="#FFFFFF" BorderBrush="#72D29B" FontWeight="Bold" IsEnabled="False"/><Button x:Name="SettingsQuickButton" Content="SETTINGS" Width="110" Height="44" Style="{StaticResource Ghost}"/></StackPanel></Grid></Border>
 </Grid>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml;$window=[Windows.Markup.XamlReader]::Load($reader)
$window.Title="Factor Golf Sim Control Center v$AppVersion"
$script:ExternalMode=$null;$script:ExternalModeProcesses=@()
try{$iconPath=Join-Path $AppDir 'assets\Halliseum.ico';if(Test-Path $iconPath){$window.Icon=[System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath)}}catch{}
foreach($n in @('StopCoachButton','UpdateButton','CoachModeButton','GSProOnlyButton','SwingNerdsButton','FSXButton','FairgroundsButton','PerformanceButton','SettingsButton','SystemText','RangeStatus','BudgetText','UpdateStatus','StatusText','RuntimeText','EndSetButton','SettingsQuickButton')){Set-Variable -Scope Script -Name $n -Value $window.FindName($n)}
$CoachModeButton.Add_Click({Launch-CurrentMode 'Coach Mode'})
$GSProOnlyButton.Add_Click({Launch-CurrentMode 'GSPro Only'})
$SwingNerdsButton.Add_Click({Launch-CurrentMode 'SwingNerds'})
$FSXButton.Add_Click({Launch-CurrentMode 'FSX'})
$FairgroundsButton.Add_Click({Launch-CurrentMode 'Fairgrounds'})
$PerformanceButton.Add_Click({Launch-CurrentMode 'Performance'})
$SettingsButton.Add_Click({Launch-CurrentMode 'Settings'})
$SettingsQuickButton.Add_Click({Open-Config});$StopCoachButton.Add_Click({Stop-UltimateCoach});$EndSetButton.Add_Click({Invoke-CoachSet});$UpdateButton.Add_Click({Start-HalliseumUpdate})

$script:CoachHotkeyId=9321;$script:HotkeyHwnd=[IntPtr]::Zero;$script:HotkeySource=$null;$script:HotkeyHook=$null
$window.Add_SourceInitialized({try{$interop=New-Object System.Windows.Interop.WindowInteropHelper($window);$script:HotkeyHwnd=$interop.Handle;$script:HotkeySource=[System.Windows.Interop.HwndSource]::FromHwnd($script:HotkeyHwnd);$script:HotkeyHook=[System.Windows.Interop.HwndSourceHook]{param([IntPtr]$hwnd,[int]$msg,[IntPtr]$wParam,[IntPtr]$lParam,[ref]$handled);if($msg -eq 0x0312 -and $wParam.ToInt32() -eq $script:CoachHotkeyId){Invoke-CoachSet;$handled.Value=$true};return [IntPtr]::Zero};$script:HotkeySource.AddHook($script:HotkeyHook);$ok=[HalliseumNative]::RegisterHotKey($script:HotkeyHwnd,$script:CoachHotkeyId,0x0007,0x78);if(-not$ok){Set-Status 'Coach pedal hotkey could not register.'}}catch{Set-Status 'Coach pedal hotkey setup failed.'}})
$script:lastAction=''
$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(650)
$timer.Add_Tick({
 if($script:ExternalMode -and -not $script:UltimateActive){
   $stillRunning=$false
   foreach($pn in @($script:ExternalModeProcesses)){if($pn -and (Is-Running $pn)){$stillRunning=$true;break}}
   if(-not $stillRunning){Restore-ControlCenterHome;Set-Status 'Home ready.'}
 }
 $gs=Is-Running 'GSPro';$sn=Is-Running 'SwingNerdsClip';$ai=Test-LocalApiKey;$SystemText.Text=('GSPro '+$(if($gs){'online'}else{'offline'})+'   |   SwingNerds '+$(if($sn){'online'}else{'offline'})+'   |   Coach AI '+$(if($ai){'ready'}else{'setup'}))
 $StopCoachButton.IsEnabled=$script:UltimateActive;$EndSetButton.IsEnabled=($script:UltimateActive -and -not(Get-CoachBusy))
 $spent=0.0;$limit=[double]$config.MonthlyBudgetUSD;if($limit -le 0){$limit=20};if(Test-Path $budgetFile){try{$b=Get-Content $budgetFile -Raw|ConvertFrom-Json;if([string]$b.month -eq (Get-Date -Format 'yyyy-MM')){$spent=[double]$b.spent_estimate_usd}}catch{}};$BudgetText.Text=('${0:N2} / ${1:N2}' -f $spent,$limit)
 if(Test-Path $runtimeFile){try{$r=Get-Content $runtimeFile -Raw|ConvertFrom-Json;$RuntimeText.Text=[string]$r.message}catch{}}
 $rangePath=Join-Path $coachRoot 'range_nav_status.json';if(Test-Path $rangePath){try{$r=Get-Content $rangePath -Raw|ConvertFrom-Json;$RangeStatus.Text=[string]$r.message}catch{}}
 if(Test-Path $actionRequestFile){try{$a=Get-Content $actionRequestFile -Raw|ConvertFrom-Json;$sig=[string]$a.requested;if($sig -and $sig -ne $script:lastAction){$script:lastAction=$sig;Remove-Item $actionRequestFile -Force -ErrorAction SilentlyContinue;if([string]$a.action -eq 'end_set'){Invoke-CoachSet}elseif([string]$a.action -eq 'club_change' -and $script:UltimateActive){
     $newClub=[string]$a.club;$oldClub='';$oldStart=Read-SetStart;try{$ss=Get-Content $stateFile -Raw|ConvertFrom-Json;$oldClub=[string]$ss.current_club}catch{}
     $detected=Get-Date;try{$detected=[datetime]::Parse([string]$a.detected_at)}catch{}
     if($oldClub -and $newClub -and $oldClub -ne $newClub){$arch=Join-Path $AppDir 'workers\Halliseum_Archive_Set.ps1';if(Test-Path $arch){$aa="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$arch`" -Root `"$stateRoot`" -SetStartIso `"$($oldStart.ToString('o'))`" -SetEndIso `"$($detected.ToString('o'))`" -ExpectedClub `"$oldClub`"";Start-Process powershell.exe -ArgumentList $aa -WindowStyle Hidden|Out-Null}}
     $newStart=if([string]$a.source -eq 'latest GSPro shot'){$detected.AddSeconds(-2)}else{Get-Date};Write-SessionState $newStart $newClub;Set-Status ("Club changed to $newClub. Fresh coaching set started automatically.")
   }}}catch{}}
 if(((Get-Date)-$script:LastUpdateCheck).TotalSeconds -ge 30){[void](Check-HalliseumUpdate $false)}
})
[void](Check-HalliseumUpdate $false);$timer.Start()
$window.Add_Closed({try{$timer.Stop()}catch{};try{if($script:HotkeyHwnd -ne [IntPtr]::Zero){[HalliseumNative]::UnregisterHotKey($script:HotkeyHwnd,$script:CoachHotkeyId)|Out-Null}}catch{};try{if($script:HotkeySource -and $script:HotkeyHook){$script:HotkeySource.RemoveHook($script:HotkeyHook)}}catch{};try{$mutex.ReleaseMutex()}catch{}})
try{
 $screen=Resolve-FGScreen -Config $config -KeyProperty 'ControlCenterDisplayKey' -IndexProperty 'ControlCenterScreenIndex';$b=$screen.WorkingArea
 $window.Left=$b.Left+20;$window.Top=$b.Top+20;$window.Width=[math]::Max(1050,$b.Width-40);$window.Height=[math]::Max(680,$b.Height-40);$window.WindowState='Maximized'
}catch{}
$window.ShowDialog()|Out-Null
