@echo off
REM Kebera - double-click to run a home internet check-up (Windows).
REM Read-only: nothing on your network is changed.
REM KEBERA IS NOT A HACKING TOOL. Use it only on your own connection. See ACCEPTABLE_USE.md.
cd /d "%~dp0"
echo.
echo  Kebera - home internet check-up
echo  -------------------------------
echo  Kebera is NOT a hacking tool. Use it only on your own connection.
echo  1. Standard check (about 5 minutes, uses about 35 MB for the speed test)
echo  2. Quick check (about 2 minutes)
echo  3. Long log (records your connection for 3 hours)
echo.
set /p choice="Choose 1, 2 or 3 and press Enter: "
if "%choice%"=="2" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\kebera.ps1" -Quick
) else if "%choice%"=="3" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\kebera-log.ps1" -Hours 3
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\kebera.ps1"
)
echo.
pause
