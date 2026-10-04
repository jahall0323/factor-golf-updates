@echo off
setlocal
title Install Factor Golf Sim Control Center v0.8.2
set "SRC=%~dp0"
set "DEST=%LOCALAPPDATA%\HalliseumControlCenter"

echo.
echo ============================================================
echo   FACTOR GOLF - SIM CONTROL CENTER v0.8.2
echo ============================================================
echo.
echo Installing / repairing to:
echo   %DEST%
echo.

if not exist "%DEST%" mkdir "%DEST%"

rem Stop only Halliseum Control Center / worker PowerShell processes so the update actually loads.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$dest=[regex]::Escape($env:LOCALAPPDATA+'\HalliseumControlCenter');" ^
 "$ps=Get-CimInstance Win32_Process ^| Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -match $dest -and $_.CommandLine -match 'Halliseum_(Control_Center|Direct_Bridge_Hidden|SwingNerds_UIA_Hidden|Coach_Set_API|Coach_Card|Range_Nav|Minimize_Connectors|Self_Update|Club_Cheat_Watcher|Club_Cheat_Sheet|Coach_Controls|Performance|Archive_Set|Voice_Test)\.ps1' };" ^
 "foreach($p in $ps){ try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }" >nul 2>nul
timeout /t 1 /nobreak >nul

xcopy "%SRC%*" "%DEST%\" /E /I /Y >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ws=New-Object -ComObject WScript.Shell;" ^
 "$desktop=[Environment]::GetFolderPath('Desktop');" ^
 "$startup=[Environment]::GetFolderPath('Startup');" ^
 "$target=$env:WINDIR+'\System32\wscript.exe';" ^
 "$vbs=$env:LOCALAPPDATA+'\HalliseumControlCenter\Halliseum_Control_Center.vbs';" ^
 "$icon=$env:LOCALAPPDATA+'\HalliseumControlCenter\assets\Halliseum.ico';$s=$ws.CreateShortcut((Join-Path $desktop 'Factor Golf Sim Control Center.lnk'));$s.TargetPath=$target;$s.Arguments='\"'+$vbs+'\"';$s.WorkingDirectory=$env:LOCALAPPDATA+'\HalliseumControlCenter';if(Test-Path $icon){$s.IconLocation=$icon};$s.Save();" ^
 "$s2=$ws.CreateShortcut((Join-Path $startup 'Factor Golf Sim Control Center.lnk'));$s2.TargetPath=$target;$s2.Arguments='\"'+$vbs+'\"';$s2.WorkingDirectory=$env:LOCALAPPDATA+'\HalliseumControlCenter';if(Test-Path $icon){$s2.IconLocation=$icon};$s2.Save();"

if exist "G:\My Drive\Halliseum Coach Bridge" if not exist "G:\My Drive\Halliseum Coach Bridge\Updates" mkdir "G:\My Drive\Halliseum Coach Bridge\Updates" >nul 2>nul

echo Installed.
echo.
echo Existing config.json and encrypted API key are preserved if already present.
echo A desktop shortcut was created and Startup remains enabled.
echo.
echo This build focuses on the complete Factor Golf flow: touch carousel, Coach controls, club changes, Performance/My Bag, voice settings, Fairgrounds and FSX mode routing.
echo Future updates can be installed from inside Factor Golf Sim Control Center.
echo.
start "" "%WINDIR%\System32\wscript.exe" "%DEST%\Halliseum_Control_Center.vbs"
timeout /t 2 >nul
exit /b 0
