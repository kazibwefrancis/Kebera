@echo off
REM Kebera - double-click to run a home internet check-up (Windows).
REM Read-only: nothing on your network is changed.
REM KEBERA IS NOT A HACKING TOOL. Use it only on your own connection. See ACCEPTABLE_USE.md.
cd /d "%~dp0"
title Kebera - home internet check-up

if not exist "%~dp0scripts\windows\kebera.ps1" goto missing

echo.
echo  Kebera - home internet check-up
echo  -------------------------------
echo  Kebera is NOT a hacking tool. Use it only on your own connection.
echo.
echo  1. Standard check - about 5 minutes, uses about 35 MB for the speed test
echo  2. Quick check    - about 2 minutes, uses about 12 MB
echo  3. Long log       - records your connection for 3 hours
echo.
echo  Not sure? Choose 1. On limited mobile data, choose 2.
echo.
set "choice="
set /p choice="Type 1, 2 or 3 and press Enter: "
echo.
if "%choice%"=="2" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\kebera.ps1" -Quick
) else if "%choice%"=="3" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\kebera-log.ps1" -Hours 3
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\kebera.ps1"
)
echo.
echo  -------------------------------
echo  Finished. Your reports are saved in this folder:
echo    %~dp0reports
echo  Each check-up has its own folder named with the date and time.
echo.
echo  Press any key to close this window.
pause >nul
exit /b 0

:missing
echo.
echo  Kebera can't find its files.
echo.
echo  This usually means kebera.bat was opened from inside the ZIP file.
echo  Kebera only works after the ZIP is extracted:
echo.
echo    1. Close this window.
echo    2. In your Downloads folder, right-click Kebera-main.zip
echo       and choose "Extract All...", then "Extract".
echo    3. Open the new Kebera-main folder, then the Kebera-main folder inside it.
echo    4. Double-click kebera.bat there.
echo.
echo  Full steps: https://kebera-production.up.railway.app/#windows
echo.
echo  Press any key to close this window.
pause >nul
exit /b 1
