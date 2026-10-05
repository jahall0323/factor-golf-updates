$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failures = @()
$files = @(foreach($folder in @('src','tests','packaging')){Get-ChildItem (Join-Path $root $folder) -Filter '*.ps1' -Recurse})
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($error in $parseErrors) { $failures += "$($file.Name):$($error.Extent.StartLineNumber): $($error.Message)" }
}
if ($failures.Count) { $failures | Write-Output; throw 'PowerShell syntax validation failed.' }
Write-Output "PASS: parsed $($files.Count) PowerShell files. Runtime behavior is not tested."
