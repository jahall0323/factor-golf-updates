$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failures = @()
$files = @(Get-ChildItem (Join-Path $root 'src') -Filter '*.ps1' -Recurse)
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($error in $parseErrors) { $failures += "$($file.Name):$($error.Extent.StartLineNumber): $($error.Message)" }
}
if ($failures.Count) { $failures | Write-Output; throw 'PowerShell syntax validation failed.' }
Write-Output "PASS: parsed $($files.Count) PowerShell files. Runtime behavior is not tested."
