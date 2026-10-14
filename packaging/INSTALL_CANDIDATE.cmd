@echo off
setlocal
title Factor Golf - Halliseum Candidate
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_Candidate.ps1"
if errorlevel 1 (
 echo.
 echo Candidate installation failed. Keep this window open and report the error above.
 pause
 exit /b 1
)
echo.
echo Ready for the Halliseum test. No stable update feed was changed.
pause
