param()

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

try {
    $sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $root = Join-Path $env:LOCALAPPDATA "FactorGolfQuickCoach"
    $installDir = Join-Path $root "App"
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null

    foreach ($name in @("QuickCoach.ps1","Launch_Quick_Coach.vbs","config.default.json","README.txt")) {
        $source = Join-Path $sourceDir $name
        if (-not (Test-Path -LiteralPath $source)) { throw "Installer package is missing $name." }
        Copy-Item -LiteralPath $source -Destination (Join-Path $installDir $name) -Force
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Factor Golf Quick Coach Beta.lnk"
    $launcher = Join-Path $installDir "Launch_Quick_Coach.vbs"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $shortcut.Arguments = '"' + $launcher + '"'
    $shortcut.WorkingDirectory = $installDir
    $shortcut.Description = "Factor Golf Quick Coach Beta"
    $shortcut.Save()

    Start-Process -FilePath "wscript.exe" -ArgumentList ('"' + $launcher + '"')

    [System.Windows.Forms.MessageBox]::Show(
        "Factor Golf Quick Coach Beta v0.1.5 is installed.`n`nDesktop shortcut created.`n`nExisting Quick Coach settings/API key were preserved.",
        "Factor Golf Quick Coach Beta"
    ) | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Install failed: " + $_.Exception.Message,
        "Factor Golf Quick Coach Beta"
    ) | Out-Null
    exit 1
}