param()

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Security

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class QuickCoachNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}
"@

$script:AppName = "Factor Golf Quick Coach Beta"
$script:Version = "0.1.5"
$script:InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataDir = Join-Path $env:LOCALAPPDATA "FactorGolfQuickCoach"
$script:AppDir = $script:DataDir
$script:ConfigPath = Join-Path $script:DataDir "config.json"
$script:SecretPath = Join-Path $script:DataDir "openai_key.dpapi"
$script:ScreenshotPath = Join-Path $script:DataDir "last_gspro_capture.png"
$script:LogPath = Join-Path $script:DataDir "quickcoach.log"
$script:LastApiResponsePath = Join-Path $script:DataDir "last_api_response.json"
$script:UpdateManifestUrl = "https://raw.githubusercontent.com/jahall0323/factor-golf-updates/main/quick-coach-beta/latest.json"

New-Item -ItemType Directory -Force -Path $script:DataDir | Out-Null

function Write-Log {
    param([string]$Message)
    try {
        $line = "{0:u} {1}" -f (Get-Date), $Message
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
    } catch {}
}

function Get-DefaultConfig {
    [ordered]@{
        Version = $script:Version
        GolferExperience = "Rookie"
        Persona = "Golf Buddy"
        SpeakFeedback = $true
        ShowPopup = $true
        PopupSeconds = 10
        Voice = ""
        TriggerKey = "F18"
        Model = "gpt-6-luna"
        RealtimeVoiceModel = "gpt-realtime-2.1-mini"
        ResponseWordLimit = 70
        ImageDetail = "high"
        ArmedOnStartup = $true
        WindowLeft = $null
        WindowTop = $null
    }
}

function Load-Config {
    $defaults = Get-DefaultConfig
    if (Test-Path -LiteralPath $script:ConfigPath) {
        try {
            $loaded = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
            foreach ($p in @($defaults.Keys)) {
                if ($null -ne $loaded.PSObject.Properties[$p]) {
                    $defaults[$p] = $loaded.$p
                }
            }
        } catch {
            Write-Log "Config load failed: $($_.Exception.Message)"
        }
    }
    return $defaults
}

function Save-Config {
    param($Config)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
}

function Save-ApiKey {
    param([string]$PlainText)
    $value = [string]$PlainText
    if ([string]::IsNullOrWhiteSpace($value)) { throw "API key box is empty." }
    $value = $value.Trim()

    try {
        $plainBytes = [Text.Encoding]::UTF8.GetBytes($value)
        $protectedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        $encoded = [Convert]::ToBase64String($protectedBytes)
        [IO.File]::WriteAllText($script:SecretPath, $encoded, (New-Object Text.UTF8Encoding($false)))

        $roundTrip = Get-ApiKey -IgnoreEnvironment
        if ([string]::IsNullOrWhiteSpace($roundTrip) -or $roundTrip -ne $value) {
            throw "The saved key could not be read back correctly."
        }

        Write-Log "API key saved and verified with Windows DPAPI (System.Security.Cryptography.ProtectedData)."
        return $true
    } catch {
        Write-Log "API key save failed: $($_.Exception.Message)"
        throw "Could not securely save the API key: $($_.Exception.Message)"
    }
}

function Get-ApiKey {
    param([switch]$IgnoreEnvironment)

    if (-not $IgnoreEnvironment -and $env:OPENAI_API_KEY) {
        return $env:OPENAI_API_KEY.Trim()
    }

    if (-not (Test-Path -LiteralPath $script:SecretPath)) { return $null }

    try {
        $encoded = [IO.File]::ReadAllText($script:SecretPath).Trim()
        if ([string]::IsNullOrWhiteSpace($encoded)) { return $null }

        $protectedBytes = [Convert]::FromBase64String($encoded)
        $plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $protectedBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [Text.Encoding]::UTF8.GetString($plainBytes).Trim()
    } catch {
        Write-Log "API key load failed: $($_.Exception.Message)"
        return $null
    }
}

function Get-VirtualKeyCode {
    param([string]$KeyName)
    if ($KeyName -match '^F(\d+)$') {
        $n = [int]$Matches[1]
        if ($n -ge 1 -and $n -le 24) {
            return 0x70 + ($n - 1)
        }
    }
    throw "Unsupported trigger key: $KeyName"
}

function Find-GSProWindow {
    $candidates = @()
    foreach ($p in [System.Diagnostics.Process]::GetProcesses()) {
        try {
            if ($p.MainWindowHandle -eq [IntPtr]::Zero) { continue }
            $title = [string]$p.MainWindowTitle
            $name = [string]$p.ProcessName

            $score = 0
            if ($name -match '(?i)^GSPro$') { $score += 100 }
            if ($title -match '(?i)\bGS\s*Pro\b|\bGSPro\b') { $score += 60 }
            if ($title -match '(?i)Foresight|Bushnell|Connector|Visual Golf') { $score -= 80 }

            if ($score -gt 0) {
                $candidates += [pscustomobject]@{
                    Process = $p
                    Score = $score
                    Title = $title
                }
            }
        } catch {}
    }

    return $candidates | Sort-Object Score -Descending | Select-Object -First 1
}

function Get-WindowRect {
    param([IntPtr]$Handle)
    $r = New-Object QuickCoachNative+RECT
    if (-not [QuickCoachNative]::GetWindowRect($Handle, [ref]$r)) {
        throw "Windows could not read the GSPro window size."
    }
    return $r
}

function Capture-GSProWindow {
    $candidate = Find-GSProWindow
    if (-not $candidate) {
        throw "I can't find the live GSPro window. Open GSPro first."
    }

    $rect = Get-WindowRect -Handle $candidate.Process.MainWindowHandle
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    if ($width -lt 500 -or $height -lt 300 -or $width -gt 10000 -or $height -gt 10000) {
        throw "GSPro was found, but its window size looks wrong ($width x $height)."
    }

    $bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen(
                $rect.Left,
                $rect.Top,
                0,
                0,
                (New-Object System.Drawing.Size($width, $height)),
                [System.Drawing.CopyPixelOperation]::SourceCopy
            )
        } finally {
            $graphics.Dispose()
        }

        $bitmap.Save($script:ScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }

    Write-Log "Captured GSPro '$($candidate.Title)' at ${width}x${height}; rect=($($rect.Left),$($rect.Top))-($($rect.Right),$($rect.Bottom))."
    return [pscustomobject]@{
        Path = $script:ScreenshotPath
        Rect = $rect
        Title = $candidate.Title
        Width = $width
        Height = $height
    }
}

function Get-PersonaInstruction {
    param([string]$Persona)
    switch ($Persona) {
        "Professional / Clean" {
            return "Use concise, professional golf-coach language. No profanity."
        }
        "Golf Buddy" {
            return "Sound like a relaxed, knowledgeable golf buddy. Conversational, clear, and not overly technical."
        }
        "One of the Boys" {
            return "Sound casual, direct, funny when it fits, and comfortable using mild profanity. Never sacrifice accuracy."
        }
        "Hood Golf" {
            return "Use a direct, casual, slang-friendly golf-buddy voice with natural rhythm. Avoid caricature, stereotypes, racial language, or slurs. Never sacrifice accuracy."
        }
        "Extreme" {
            return "Be very direct, energetic, and blunt. Strong language can fit, but the golf analysis must stay accurate and useful."
        }
        default {
            return "Use concise, conversational golf-coach language."
        }
    }
}

function Get-ExperienceInstruction {
    param([string]$Level)
    switch ($Level) {
        "Rookie" {
            return "Assume the golfer is still learning. Use plain English. Give one main takeaway and one simple feel or next-shot cue."
        }
        "Amateur" {
            return "Assume normal golf fundamentals and common terms are understood. Explain the biggest useful cause/effect without drowning the golfer in mechanics."
        }
        "Pro / Advanced" {
            return "Technical language is okay, but only discuss technical delivery metrics when they are actually visible and readable in the evidence."
        }
        default {
            return "Keep the coaching simple and useful."
        }
    }
}

function Build-CoachPrompt {
    param(
        $Config,
        [string]$OptionalContext
    )

    $persona = Get-PersonaInstruction -Persona ([string]$Config.Persona)
    $level = Get-ExperienceInstruction -Level ([string]$Config.GolferExperience)
    $limit = [int]$Config.ResponseWordLimit

    $contextText = ""
    if (-not [string]::IsNullOrWhiteSpace($OptionalContext)) {
        $contextText = @"

The golfer supplied this context for the shot:
"$OptionalContext"
Use it as context, not as measured launch-monitor data.
"@
    }

    return @"
You are Factor Golf Quick Coach. This is live on-course GSPro play, not a full swing lesson.

Analyze the attached screenshot of the entire GSPro window after the golfer's most recent shot.

Golfer Experience: $($Config.GolferExperience)
Coach Persona: $($Config.Persona)

$level
$persona

DATA HONESTY RULES:
- The golfer uses a Bushnell Launch Pro with a one-dot club marker.
- Only call a number or metric measured/known when it is actually visible and readable in the screenshot.
- Do not invent club path, face angle, angle of attack, strike location, or other delivery metrics if they are not shown.
- Ball flight can show WHAT happened, but it does not always prove WHY it happened.
- If you infer a likely cause, clearly use words such as "likely", "could be", or "suggests".
- If important text is unreadable, say that instead of guessing.
- Separate a poor result from a poor swing. A shot can have a bad outcome without enough evidence to diagnose the swing.

ON-COURSE RESPONSE:
1. Say the most important thing you can confidently tell from the shot.
2. Mention one thing that was good if the evidence supports it.
3. Give one simple next-shot cue or decision.
4. Do not turn this into a long lesson.
5. Stay under about $limit words.
6. Do not use headings or bullet points because the answer will be spoken aloud.
$contextText
"@
}

function Extract-ResponseText {
    param($Response)

    if ($null -ne $Response.output_text -and -not [string]::IsNullOrWhiteSpace([string]$Response.output_text)) {
        return [string]$Response.output_text
    }

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Response.output)) {
        foreach ($content in @($item.content)) {
            if ($content.type -eq "output_text" -and $content.text) {
                $parts.Add([string]$content.text)
            }
        }
    }

    return ($parts -join "`n").Trim()
}

function Get-WebErrorDetail {
    param($ErrorRecord)

    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -ne $response) {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object IO.StreamReader($stream)
                try {
                    $bodyText = $reader.ReadToEnd()
                    if (-not [string]::IsNullOrWhiteSpace($bodyText)) {
                        try {
                            $obj = $bodyText | ConvertFrom-Json
                            if ($obj.error.message) { return [string]$obj.error.message }
                        } catch {}
                        return $bodyText
                    }
                } finally {
                    $reader.Dispose()
                }
            }
        }
    } catch {}

    if ($ErrorRecord.Exception.Message) { return [string]$ErrorRecord.Exception.Message }
    return "Unknown API error."
}

function Invoke-OpenAICoach {
    param(
        $Config,
        [string]$ImagePath,
        [string]$OptionalContext
    )

    $apiKey = Get-ApiKey
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "No OpenAI API key is available. Click SAVE SETTINGS and confirm the status says API key SAVED + VERIFIED."
    }

    if (-not (Test-Path -LiteralPath $ImagePath)) {
        throw "Screenshot file is missing."
    }

    $bytes = [IO.File]::ReadAllBytes($ImagePath)
    $base64 = [Convert]::ToBase64String($bytes)
    $prompt = Build-CoachPrompt -Config $Config -OptionalContext $OptionalContext

    $body = @{
        model = [string]$Config.Model
        reasoning = @{
            effort = "none"
        }
        max_output_tokens = 220
        input = @(
            @{
                role = "user"
                content = @(
                    @{
                        type = "input_text"
                        text = $prompt
                    },
                    @{
                        type = "input_image"
                        image_url = "data:image/png;base64,$base64"
                        detail = [string]$Config.ImageDetail
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 12 -Compress

    $headers = @{
        Authorization = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }

    Write-Log "Sending screenshot to OpenAI Responses API model '$($Config.Model)'. Realtime voice target is '$($Config.RealtimeVoiceModel)'."
    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.openai.com/v1/responses" `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 60

        try {
            $response | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $script:LastApiResponsePath -Encoding UTF8
        } catch {}
    } catch {
        $detail = Get-WebErrorDetail -ErrorRecord $_
        Write-Log "OpenAI API request failed: $detail"
        throw "OpenAI API error: $detail"
    }

    $text = Extract-ResponseText -Response $response
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "OpenAI returned a response, but Quick Coach could not find any spoken feedback in it."
    }

    Write-Log "Coach response received: $text"
    return $text.Trim()
}

function Show-FeedbackOverlay {
    param(
        [string]$Text,
        $Rect,
        [int]$Seconds
    )

    try {
        $widthAvailable = [Math]::Max(500, ($Rect.Right - $Rect.Left) - 80)
        $overlayWidth = [Math]::Min(1000, $widthAvailable)

        $overlay = New-Object System.Windows.Window
        $overlay.Title = "Quick Coach"
        $overlay.Width = $overlayWidth
        $overlay.Height = 150
        $overlay.WindowStyle = [System.Windows.WindowStyle]::None
        $overlay.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $overlay.Topmost = $true
        $overlay.ShowInTaskbar = $false
        $overlay.AllowsTransparency = $true
        $overlay.Background = [System.Windows.Media.Brushes]::Transparent
        $overlay.Left = $Rect.Left + 40
        $overlay.Top = [Math]::Max($Rect.Top + 30, $Rect.Bottom - 210)

        $border = New-Object System.Windows.Controls.Border
        $border.CornerRadius = New-Object System.Windows.CornerRadius(12)
        $border.BorderThickness = New-Object System.Windows.Thickness(2)
        $border.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(217,184,76))
        $border.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromArgb(235,16,18,20))
        $border.Padding = New-Object System.Windows.Thickness(18)

        $stack = New-Object System.Windows.Controls.StackPanel

        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = "QUICK COACH"
        $title.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(217,184,76))
        $title.FontSize = 16
        $title.FontWeight = [System.Windows.FontWeights]::Bold
        $title.Margin = New-Object System.Windows.Thickness(0,0,0,8)

        $body = New-Object System.Windows.Controls.TextBlock
        $body.Text = $Text
        $body.Foreground = [System.Windows.Media.Brushes]::White
        $body.FontSize = 20
        $body.TextWrapping = [System.Windows.TextWrapping]::Wrap

        [void]$stack.Children.Add($title)
        [void]$stack.Children.Add($body)
        $border.Child = $stack
        $overlay.Content = $border

        $closeTimer = New-Object System.Windows.Threading.DispatcherTimer
        $closeTimer.Interval = [TimeSpan]::FromSeconds([Math]::Max(3, $Seconds))
        $closeTimer.Add_Tick({
            $closeTimer.Stop()
            $overlay.Close()
        })

        $overlay.Add_ContentRendered({ $closeTimer.Start() })
        [void]$overlay.Show()
    } catch {
        Write-Log "Overlay failed: $($_.Exception.Message)"
    }
}



function Export-QuickCoachDiagnostics {
    try {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $desktop = [Environment]::GetFolderPath("Desktop")
        $zipPath = Join-Path $desktop ("FactorGolfQuickCoach_Diagnostics_" + $stamp + ".zip")
        $tempDir = Join-Path $env:TEMP ("FactorGolfQuickCoachDiag_" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

        $diagText = @"
Factor Golf Quick Coach Beta diagnostics
Version: $script:Version
Created: $(Get-Date -Format o)
InstallDir: $script:InstallDir
DataDir: $script:DataDir
Model: $($script:Config.Model)
RealtimeVoiceModel: $($script:Config.RealtimeVoiceModel)
TriggerKey: $($script:Config.TriggerKey)
Armed: $script:Armed
QuickCoachWindow: Left=$($window.Left) Top=$($window.Top) Width=$($window.ActualWidth) Height=$($window.ActualHeight) State=$($window.WindowState)

IMPORTANT:
openai_key.dpapi is intentionally NOT included.
"@
        [IO.File]::WriteAllText(
            (Join-Path $tempDir "diagnostics.txt"),
            $diagText,
            (New-Object Text.UTF8Encoding($false))
        )

        foreach ($name in @("quickcoach.log","config.json","last_api_response.json","last_gspro_capture.png")) {
            $source = Join-Path $script:DataDir $name
            if (Test-Path -LiteralPath $source) {
                Copy-Item -LiteralPath $source -Destination (Join-Path $tempDir $name) -Force
            }
        }

        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }

        Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zipPath -Force
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue

        Write-Log "Diagnostics exported to $zipPath"
        return $zipPath
    } catch {
        Write-Log "Diagnostics export failed: $($_.Exception.Message)"
        throw
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-QuickCoachUpdate {
    try {
        Set-Status "Checking for Quick Coach Beta updates..."
        $manifest = Invoke-RestMethod -Uri $script:UpdateManifestUrl -Method Get -TimeoutSec 15

        if (-not $manifest.version -or -not $manifest.files) {
            throw "Update manifest is missing version/files."
        }

        $releaseStatus = "candidate"
        if ($manifest.release_status) {
            $releaseStatus = ([string]$manifest.release_status).ToLowerInvariant()
        } elseif ($manifest.status) {
            $releaseStatus = ([string]$manifest.status).ToLowerInvariant()
        }

        if ($releaseStatus -eq "rejected") {
            Set-Status "The published Quick Coach build is rejected and will not be installed."
            return
        }

        if (@("dev","candidate","accepted") -notcontains $releaseStatus) {
            throw "Unknown Quick Coach release status: $releaseStatus"
        }

        $current = [Version]$script:Version
        $available = [Version][string]$manifest.version
        if ($available -le $current) {
            Set-Status "You're current. Factor Golf Quick Coach Beta v$script:Version."
            return
        }

        $answer = [System.Windows.MessageBox]::Show(
            "Factor Golf Quick Coach Beta v$($manifest.version) [$releaseStatus] is available.`n`nInstall it now?`n`nYour settings and protected API key stay in place.",
            "Quick Coach Update",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
            Set-Status "Update canceled."
            return
        }

        $updateRoot = Join-Path $env:TEMP ("FactorGolfQuickCoachUpdate_" + [Guid]::NewGuid().ToString("N"))
        $stage = Join-Path $updateRoot "stage"
        New-Item -ItemType Directory -Force -Path $stage | Out-Null

        Set-Status "Downloading and verifying v$($manifest.version)..."
        foreach ($file in @($manifest.files)) {
            $name = [IO.Path]::GetFileName([string]$file.path)
            if ([string]::IsNullOrWhiteSpace($name)) { throw "Manifest contains an invalid file path." }

            $dest = Join-Path $stage $name
            Invoke-WebRequest -Uri ([string]$file.url) -OutFile $dest -UseBasicParsing -TimeoutSec 60

            $actual = Get-Sha256 -Path $dest
            $expected = ([string]$file.sha256).ToLowerInvariant()
            if ($actual -ne $expected) {
                throw "SHA-256 verification failed for $name."
            }
        }

        $updaterPath = Join-Path $updateRoot "Apply_QuickCoach_Update.ps1"
        $launcherPath = Join-Path $script:InstallDir "Launch_Quick_Coach.vbs"
        $updater = @"
param(
    [int]`$WaitPid,
    [string]`$StageDir,
    [string]`$InstallDir,
    [string]`$LauncherPath
)
`$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
try {
    try { Wait-Process -Id `$WaitPid -Timeout 20 -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Milliseconds 700

    Get-ChildItem -LiteralPath `$StageDir -File -Force | ForEach-Object {
        Copy-Item -LiteralPath `$_.FullName -Destination (Join-Path `$InstallDir `$_.Name) -Force
    }

    Start-Sleep -Milliseconds 500
    if (Test-Path -LiteralPath `$LauncherPath) {
        Start-Process -FilePath "wscript.exe" -ArgumentList ('"' + `$LauncherPath + '"')
    }
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Quick Coach update failed: " + `$_.Exception.Message,
        "Factor Golf Quick Coach Beta"
    ) | Out-Null
}
"@
        [IO.File]::WriteAllText($updaterPath, $updater, (New-Object Text.UTF8Encoding($false)))

        Set-Status "Update verified. Installing and restarting..."
        $args = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$updaterPath`"",
            "-WaitPid", $PID,
            "-StageDir", "`"$stage`"",
            "-InstallDir", "`"$script:InstallDir`"",
            "-LauncherPath", "`"$launcherPath`""
        )
        Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden
        $window.Close()
    } catch {
        Write-Log "Update failed: $($_.Exception.Message)"
        Set-Status "UPDATE ERROR: $($_.Exception.Message)"
    }
}

function Speak-Feedback {
    param(
        [string]$Text,
        [string]$Voice
    )

    try {
        if ($Voice -and $Voice -ne "(Windows default)") {
            $script:Synth.SelectVoice($Voice)
        }

        if ($script:Synth.State -eq [System.Speech.Synthesis.SynthesizerState]::Speaking) {
            Write-Log "TTS: canceling previous speech before new response."
            [void]$script:Synth.SpeakAsyncCancelAll()
            Start-Sleep -Milliseconds 80
        }

        Write-Log "TTS started. Characters=$($Text.Length). Voice='$Voice'."
        [void]$script:Synth.SpeakAsync($Text)
    } catch {
        Write-Log "TTS failed: $($_.Exception.Message)"
    }
}

$script:Config = Load-Config
if ([string]::IsNullOrWhiteSpace([string]$script:Config.Model) -or [string]$script:Config.Model -ne "gpt-6-luna") {
    $script:Config.Model = "gpt-6-luna"
}
if ([string]::IsNullOrWhiteSpace([string]$script:Config.RealtimeVoiceModel)) {
    $script:Config.RealtimeVoiceModel = "gpt-realtime-2.1-mini"
}
$script:Config.Version = $script:Version
$script:Synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$script:Synth.add_SpeakCompleted({
    param($sender, $e)
    if ($e.Cancelled) {
        Write-Log "TTS completed event: CANCELLED."
    } elseif ($null -ne $e.Error) {
        Write-Log "TTS completed event: ERROR $($e.Error.Message)"
    } else {
        Write-Log "TTS completed event: SUCCESS."
    }
})
$script:Busy = $false
$script:Armed = [bool]$script:Config.ArmedOnStartup
$script:WasTriggerDown = $false
$script:LastCapture = $null

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Factor Golf Quick Coach Beta"
        Width="720"
        Height="760"
        MinWidth="680"
        MinHeight="700"
        WindowStartupLocation="CenterScreen"
        Background="#101214"
        Foreground="White">
    <Grid Margin="22">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0">
            <TextBlock Text="FACTOR GOLF" Foreground="#D9B84C" FontSize="16" FontWeight="Bold"/>
            <TextBlock Text="QUICK COACH BETA" FontSize="30" FontWeight="Bold" Margin="0,2,0,2"/>
            <TextBlock Text="One pedal. One screenshot. One useful answer." Foreground="#AEB4BC" FontSize="14"/>
        </StackPanel>

        <Border Grid.Row="1" Background="#181B1F" BorderBrush="#2B3036" BorderThickness="1" CornerRadius="12" Margin="0,18,0,0" Padding="16">
            <StackPanel>
                <TextBlock Text="COACH SETTINGS" Foreground="#D9B84C" FontWeight="Bold" FontSize="13"/>
                <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="18"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock Text="Golfer Experience" Margin="0,0,0,5"/>
                        <ComboBox x:Name="SkillCombo" Height="34"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2">
                        <TextBlock Text="Coach Persona" Margin="0,0,0,5"/>
                        <ComboBox x:Name="PersonaCombo" Height="34"/>
                    </StackPanel>
                </Grid>

                <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="18"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock Text="Trigger Key" Margin="0,0,0,5"/>
                        <ComboBox x:Name="TriggerCombo" Height="34"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2">
                        <TextBlock Text="Voice (temporary Windows TTS)" Margin="0,0,0,5"/>
                        <ComboBox x:Name="VoiceCombo" Height="34"/>
                    </StackPanel>
                </Grid>

                <TextBlock Text="Shot note for Coach (optional)" Margin="0,12,0,5"/>
                <TextBox x:Name="ContextBox" Height="34" Padding="8,5" Background="#0D0F11" Foreground="White"
                         BorderBrush="#3A4048" ToolTip="Example: 9-iron, tried to hit a draw. Used once, then cleared."/>

                <TextBlock Text="OpenAI API Key" Margin="0,12,0,5"/>
                <PasswordBox x:Name="ApiKeyBox" Height="34" Padding="8,5" Background="#0D0F11" Foreground="White" BorderBrush="#3A4048"/>
                <TextBlock x:Name="KeyStatusText" Foreground="#AEB4BC" FontSize="12" Margin="0,5,0,0"/>

                <WrapPanel Margin="0,12,0,0">
                    <CheckBox x:Name="SpeakCheck" Content="Speak feedback aloud" IsChecked="True" Margin="0,0,22,0" Foreground="White"/>
                    <CheckBox x:Name="PopupCheck" Content="Show temporary GSPro popup" IsChecked="True" Foreground="White"/>
                </WrapPanel>
            </StackPanel>
        </Border>

        <Grid Grid.Row="2" Margin="0,16,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button x:Name="ArmButton" Grid.Column="0" Height="54" FontSize="17" FontWeight="Bold"
                    Background="#D9B84C" Foreground="#101214" BorderThickness="0"/>
            <Button x:Name="TestButton" Grid.Column="2" Height="54" FontSize="15" FontWeight="Bold"
                    Content="TEST SCREENSHOT + COACH" Background="#262B31" Foreground="White" BorderBrush="#3A4048"/>
        </Grid>

        <Border Grid.Row="3" Background="#181B1F" BorderBrush="#2B3036" BorderThickness="1" CornerRadius="10" Margin="0,16,0,0" Padding="14">
            <StackPanel>
                <TextBlock Text="STATUS" Foreground="#D9B84C" FontWeight="Bold" FontSize="12"/>
                <TextBlock x:Name="StatusText" TextWrapping="Wrap" Margin="0,6,0,0" FontSize="14"/>
            </StackPanel>
        </Border>

        <Border Grid.Row="4" Background="#0D0F11" BorderBrush="#2B3036" BorderThickness="1" CornerRadius="10" Margin="0,16,0,0" Padding="14">
            <StackPanel>
                <TextBlock Text="LAST COACH FEEDBACK" Foreground="#D9B84C" FontWeight="Bold" FontSize="12"/>
                <TextBox x:Name="FeedbackBox" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True"
                         VerticalScrollBarVisibility="Auto" Margin="0,8,0,0" Background="#0D0F11"
                         Foreground="White" BorderThickness="0" FontSize="16"/>
            </StackPanel>
        </Border>

        <DockPanel Grid.Row="5" Margin="0,16,0,0" LastChildFill="True">
            <TextBlock DockPanel.Dock="Right" Text="v0.1.5" Foreground="#6F7780"
                       VerticalAlignment="Center" Margin="12,0,0,0"/>
            <WrapPanel>
                <Button x:Name="SaveButton" Content="SAVE SETTINGS" Padding="14,9" Margin="0,0,10,0"
                        Background="#262B31" Foreground="White" BorderBrush="#3A4048"/>
                <Button x:Name="OpenCaptureButton" Content="LAST SCREENSHOT" Padding="14,9" Margin="0,0,10,0"
                        Background="#262B31" Foreground="White" BorderBrush="#3A4048"/>
                <Button x:Name="DiagnosticsButton" Content="EXPORT DIAGNOSTICS" Padding="14,9" Margin="0,0,10,0"
                        Background="#262B31" Foreground="White" BorderBrush="#3A4048"/>
                <Button x:Name="UpdateButton" Content="CHECK UPDATE" Padding="14,9"
                        Background="#262B31" Foreground="White" BorderBrush="#D9B84C"/>
            </WrapPanel>
        </DockPanel>
    </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$SkillCombo = $window.FindName("SkillCombo")
$PersonaCombo = $window.FindName("PersonaCombo")
$TriggerCombo = $window.FindName("TriggerCombo")
$VoiceCombo = $window.FindName("VoiceCombo")
$ContextBox = $window.FindName("ContextBox")
$ApiKeyBox = $window.FindName("ApiKeyBox")
$KeyStatusText = $window.FindName("KeyStatusText")
$SpeakCheck = $window.FindName("SpeakCheck")
$PopupCheck = $window.FindName("PopupCheck")
$ArmButton = $window.FindName("ArmButton")
$TestButton = $window.FindName("TestButton")
$StatusText = $window.FindName("StatusText")
$FeedbackBox = $window.FindName("FeedbackBox")
$SaveButton = $window.FindName("SaveButton")
$OpenCaptureButton = $window.FindName("OpenCaptureButton")
$DiagnosticsButton = $window.FindName("DiagnosticsButton")
$UpdateButton = $window.FindName("UpdateButton")


if ($null -ne $script:Config.WindowLeft -and $null -ne $script:Config.WindowTop) {
    try {
        $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
        $window.Left = [double]$script:Config.WindowLeft
        $window.Top = [double]$script:Config.WindowTop
        Write-Log "Restored Quick Coach window position Left=$($window.Left) Top=$($window.Top)."
    } catch {
        Write-Log "Window-position restore failed: $($_.Exception.Message)"
    }
}

$SkillCombo.ItemsSource = @("Rookie", "Amateur", "Pro / Advanced")
$PersonaCombo.ItemsSource = @("Professional / Clean", "Golf Buddy", "One of the Boys", "Hood Golf", "Extreme")
$TriggerCombo.ItemsSource = 13..24 | ForEach-Object { "F$_" }

$voiceNames = @("(Windows default)")
try {
    $voiceNames += $script:Synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name }
} catch {}
$VoiceCombo.ItemsSource = $voiceNames

$SkillCombo.SelectedItem = [string]$script:Config.GolferExperience
$PersonaCombo.SelectedItem = [string]$script:Config.Persona
$TriggerCombo.SelectedItem = [string]$script:Config.TriggerKey
if ($voiceNames -contains [string]$script:Config.Voice -and $script:Config.Voice) {
    $VoiceCombo.SelectedItem = [string]$script:Config.Voice
} else {
    $VoiceCombo.SelectedItem = "(Windows default)"
}
$SpeakCheck.IsChecked = [bool]$script:Config.SpeakFeedback
$PopupCheck.IsChecked = [bool]$script:Config.ShowPopup

if (Get-ApiKey) {
    $KeyStatusText.Text = "A protected API key is already saved for this Windows user."
} else {
    $KeyStatusText.Text = "No key saved yet. Paste your OpenAI API key above."
}

function Update-ArmUI {
    if ($script:Armed) {
        $ArmButton.Content = "ARMED - FAR RIGHT PEDAL READY"
        $ArmButton.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(217,184,76))
        $ArmButton.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(16,18,20))
    } else {
        $ArmButton.Content = "DISARMED - CLICK TO ARM"
        $ArmButton.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(49,55,62))
        $ArmButton.Foreground = [System.Windows.Media.Brushes]::White
    }
}

function Set-Status {
    param([string]$Text)
    $StatusText.Text = $Text
    [void]$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}

function Apply-UiToConfig {
    $script:Config.GolferExperience = [string]$SkillCombo.SelectedItem
    $script:Config.Persona = [string]$PersonaCombo.SelectedItem
    $script:Config.TriggerKey = [string]$TriggerCombo.SelectedItem
    $script:Config.Voice = [string]$VoiceCombo.SelectedItem
    if ($script:Config.Voice -eq "(Windows default)") { $script:Config.Voice = "" }
    $script:Config.SpeakFeedback = [bool]$SpeakCheck.IsChecked
    $script:Config.ShowPopup = [bool]$PopupCheck.IsChecked
    $script:Config.Version = $script:Version
}

function Run-QuickCoach {
    if ($script:Busy) {
        Write-Log "Quick Coach trigger ignored because a request is already in progress."
        return
    }

    $script:Busy = $true

    try {
        Apply-UiToConfig
        [System.Media.SystemSounds]::Asterisk.Play()
        Set-Status "Capturing the full GSPro window..."

        # Keep the WPF dialog alive. v0.1.3 used Hide(), which could end the
        # modal ShowDialog lifetime and terminate TTS. Instead, briefly make
        # the window transparent during the screen copy, then restore it.
        $priorOpacity = $window.Opacity
        $priorHitTest = $window.IsHitTestVisible

        try {
            $window.Opacity = 0.0
            $window.IsHitTestVisible = $false
            [void]$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
            Start-Sleep -Milliseconds 150

            $capture = Capture-GSProWindow
            $script:LastCapture = $capture
        } finally {
            $window.Opacity = $priorOpacity
            $window.IsHitTestVisible = $priorHitTest
            [void]$window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
        }

        Set-Status "GSPro captured. Analyzing the shot..."
        $feedback = Invoke-OpenAICoach `
            -Config $script:Config `
            -ImagePath $capture.Path `
            -OptionalContext ([string]$ContextBox.Text)

        $FeedbackBox.Text = $feedback
        $ContextBox.Text = ""
        Set-Status "Coach response ready. F18 is armed for the next shot."

        if ([bool]$script:Config.ShowPopup) {
            Show-FeedbackOverlay -Text $feedback -Rect $capture.Rect -Seconds ([int]$script:Config.PopupSeconds)
        }

        if ([bool]$script:Config.SpeakFeedback) {
            Speak-Feedback -Text $feedback -Voice ([string]$script:Config.Voice)
        }

        Write-Log "Quick Coach cycle completed successfully."
    } catch {
        # Always restore UI visibility if anything failed during capture.
        try {
            $window.Opacity = 1.0
            $window.IsHitTestVisible = $true
        } catch {}

        $msg = $_.Exception.Message
        Write-Log "Quick Coach error: $msg"
        $FeedbackBox.Text = ""
        Set-Status "ERROR: $msg"
        try {
            if ([bool]$script:Config.SpeakFeedback) {
                Speak-Feedback -Text $msg -Voice ([string]$script:Config.Voice)
            }
        } catch {}
    } finally {
        $script:Busy = $false
    }
}

$SaveButton.Add_Click({
    try {
        Apply-UiToConfig
        $savedNewKey = $false
        if (-not [string]::IsNullOrWhiteSpace($ApiKeyBox.Password)) {
            [void](Save-ApiKey -PlainText $ApiKeyBox.Password)
            $savedNewKey = $true
            $ApiKeyBox.Clear()
        }
        Save-Config -Config $script:Config
        $verifiedKey = Get-ApiKey
        if ($verifiedKey) {
            $KeyStatusText.Text = "API key saved + decrypted successfully for this Windows user."
            if ($savedNewKey) {
                Set-Status "API key SAVED + VERIFIED. You're ready to test."
            } else {
                Set-Status "Settings saved. API key is present and verified."
            }
        } else {
            $KeyStatusText.Text = "No usable API key is saved."
            Set-Status "Settings saved, but the API key is still missing."
        }
    } catch {
        Set-Status "ERROR saving settings: $($_.Exception.Message)"
    }
})

$ArmButton.Add_Click({
    $script:Armed = -not $script:Armed
    Update-ArmUI
    if ($script:Armed) {
        Set-Status "Armed. After your shot data appears in GSPro, tap the far-right pedal."
    } else {
        Set-Status "Disarmed. Pedal presses are ignored."
    }
})

$TestButton.Add_Click({
    Run-QuickCoach
})

$DiagnosticsButton.Add_Click({
    try {
        $zip = Export-QuickCoachDiagnostics
        Set-Status "Diagnostics exported to Desktop: $([IO.Path]::GetFileName($zip))"
        [System.Windows.MessageBox]::Show(
            "Diagnostics ZIP created on your Desktop:`n`n$zip`n`nIt does NOT contain your API key.",
            "Quick Coach Diagnostics"
        ) | Out-Null
    } catch {
        Set-Status "ERROR exporting diagnostics: $($_.Exception.Message)"
    }
})

$UpdateButton.Add_Click({
    Invoke-QuickCoachUpdate
})

$OpenCaptureButton.Add_Click({
    if (Test-Path -LiteralPath $script:ScreenshotPath) {
        Start-Process -FilePath $script:ScreenshotPath
    } else {
        Set-Status "No screenshot has been captured yet."
    }
})

$pollTimer = New-Object System.Windows.Threading.DispatcherTimer
$pollTimer.Interval = [TimeSpan]::FromMilliseconds(60)
$pollTimer.Add_Tick({
    try {
        if (-not $script:Armed -or $script:Busy) {
            $script:WasTriggerDown = $false
            return
        }

        Apply-UiToConfig
        $vk = Get-VirtualKeyCode -KeyName ([string]$script:Config.TriggerKey)
        $down = (([QuickCoachNative]::GetAsyncKeyState($vk) -band 0x8000) -ne 0)

        if ($down -and -not $script:WasTriggerDown) {
            Run-QuickCoach
        }

        $script:WasTriggerDown = $down
    } catch {
        Write-Log "Hotkey polling error: $($_.Exception.Message)"
    }
})

$window.Add_ContentRendered({
    Update-ArmUI
    if ($script:Armed) {
        Set-Status "Armed. Map the far-right pedal to $($script:Config.TriggerKey), then tap it after a shot."
    } else {
        Set-Status "Disarmed."
    }
    Write-Log "Quick Coach UI ready. Left=$($window.Left) Top=$($window.Top) Width=$($window.ActualWidth) Height=$($window.ActualHeight)."
    $pollTimer.Start()
})

$window.Add_Closing({
    try {
        Apply-UiToConfig
        $script:Config.ArmedOnStartup = $script:Armed
        if ($window.WindowState -eq [System.Windows.WindowState]::Normal) {
            $script:Config.WindowLeft = [double]$window.Left
            $script:Config.WindowTop = [double]$window.Top
        }
        Write-Log "Main window closing normally."
        Save-Config -Config $script:Config
    } catch {}
    try { $pollTimer.Stop() } catch {}
    try { $script:Synth.Dispose() } catch {}
})

try { Save-Config -Config $script:Config } catch {}
Write-Log "Quick Coach Beta v$script:Version started. Channel=beta InstallDir=$script:InstallDir DataDir=$script:DataDir Model=$($script:Config.Model)"
[void]$window.ShowDialog()