@echo off
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0SETUP_OPENAI_API_KEY.ps1"
exit /b 0
