@echo off
echo Starting MetaBundle Setup Wizard...
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
echo Setup completed. Press any key to exit...
pause
