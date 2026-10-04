@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$startup=[Environment]::GetFolderPath('Startup'); foreach($name in @('Halliseum Control Center.lnk','Factor Golf Sim Control Center.lnk')){$p=Join-Path $startup $name; if(Test-Path $p){Remove-Item $p -Force}}; Write-Host 'Factor Golf startup shortcut removed.'"
pause
