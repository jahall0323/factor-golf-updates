$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$files=@(Get-ChildItem $root -Recurse -Filter *.ps1)
$issues=New-Object System.Collections.Generic.List[string]
foreach($f in $files){
  $t=Get-Content $f.FullName -Raw
  if($t -match 'Foreground="White"[^>]*Background="White"' -or $t -match 'Background="White"[^>]*Foreground="White"'){
    $issues.Add("White-on-white explicit style: $($f.FullName)")
  }
  if($t -match 'Foreground="#FFFFFF"[^>]*Background="#FFFFFF"' -or $t -match 'Background="#FFFFFF"[^>]*Foreground="#FFFFFF"'){
    $issues.Add("White-on-white explicit style: $($f.FullName)")
  }
  if($t -match '<Button' -and $t -notmatch 'IsEnabled" Value="False"|Trigger Property="IsEnabled" Value="False"|IsEnabled="False"'){
    # informational only; not a failure because not every window has disabled buttons
  }
}
if($issues.Count){
  Write-Host "UI visibility audit FAILED" -ForegroundColor Red
  $issues|ForEach-Object{Write-Host $_ -ForegroundColor Red}
  exit 1
}
Write-Host "UI visibility audit passed: no explicit white-on-white text/background combinations found."
