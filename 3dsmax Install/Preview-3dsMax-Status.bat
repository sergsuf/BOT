@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "STATUS_PREPARING=Preparing Autodesk 3ds Max 2025..."
set "STATUS_MOUNTING=Mounting installation media..."
set "STATUS_WAITING=Waiting for Autodesk Setup..."
set "STATUS_VERIFYING=Verifying the installation..."
set "STATUS_COMPLETE=Installation completed successfully."
set "STATUS_FAILED=Installation failed. Check the install log."

set "PERCENT=0"
set "TITLE=Installing Autodesk 3ds Max 2025"
set "FILE_COUNT=0"
set "STATE=INSTALLING"
set "SPINNER_PHASE=1"
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"

:draw_screen
cls
echo.
echo Autodesk 3ds Max 2025 - Status Preview
echo ======================================
echo !TITLE!
echo.
if "!STATE!"=="INSTALLING" (
    call :draw_progress !PERCENT!
    echo.
    echo %ESC%[8;1H%ESC%[2K!SPINNER!
    echo Files: !FILE_COUNT!
) else if "!STATE!"=="PREPARING" (
    call :draw_progress !PERCENT!
    echo Status: !STATUS_PREPARING!
) else if "!STATE!"=="MOUNTING" (
    call :draw_progress !PERCENT!
    echo Status: !STATUS_MOUNTING!
) else if "!STATE!"=="WAITING" (
    call :draw_progress !PERCENT!
    echo Status: !STATUS_WAITING!
) else if "!STATE!"=="VERIFYING" (
    call :draw_progress !PERCENT!
    echo Status: !STATUS_VERIFYING!
) else if "!STATE!"=="COMPLETE" (
    call :draw_progress !PERCENT!
    echo Status: !STATUS_COMPLETE!
) else if "!STATE!"=="FAILED" (
    call :draw_progress !PERCENT!
    echo Status: !STATUS_FAILED!
)
echo.
echo [1] Preparing    [2] Mounting    [3] Waiting    [4] Installing
echo [5] Verifying    [6] Complete    [7] Failed      [R] Random
echo [Q] Quit
echo.
goto animate

:loop
:animate
set /a SPINNER_PHASE=!SPINNER_PHASE! %% 4 + 1
if "!SPINNER_PHASE!"=="1" set "SPINNER=/"
if "!SPINNER_PHASE!"=="2" set "SPINNER=-"
if "!SPINNER_PHASE!"=="3" set "SPINNER=\"
if "!SPINNER_PHASE!"=="4" set "SPINNER=|"
if "!STATE!"=="INSTALLING" (
    <nul set /p "=!ESC![8;1H!ESC![2K!SPINNER!!ESC![14;1H"
)
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "Start-Sleep -Milliseconds 500"
choice /c 1234567RXQ /n /d X /t 0 >nul
set "KEY=!errorlevel!"

rem choice maps digit keys to positions in /C order.
if "!KEY!"=="1" call :set_status PREPARING 0 0
if "!KEY!"=="2" call :set_status MOUNTING 5 0
if "!KEY!"=="3" call :set_status WAITING 10 0
if "!KEY!"=="4" call :set_status INSTALLING 35 2450
if "!KEY!"=="5" call :set_status VERIFYING 96 8042
if "!KEY!"=="6" call :set_status COMPLETE 100 8042
if "!KEY!"=="7" call :set_status FAILED 62 4125
if "!KEY!"=="8" call :set_random_status
if "!KEY!"=="10" goto quit
if not "!KEY!"=="9" goto draw_screen
goto animate

:set_status
set "STATE=%~1"
set "PERCENT=%~2"
set "FILE_COUNT=%~3"
exit /b

:set_random_status
set /a "PERCENT=%RANDOM% %% 96"
set /a "FILE_COUNT=%RANDOM% %% 8000"
set /a "STATE_NUMBER=%RANDOM% %% 7"
if "!STATE_NUMBER!"=="0" set "STATE=PREPARING"
if "!STATE_NUMBER!"=="1" set "STATE=MOUNTING"
if "!STATE_NUMBER!"=="2" set "STATE=WAITING"
if "!STATE_NUMBER!"=="3" set "STATE=INSTALLING"
if "!STATE_NUMBER!"=="4" set "STATE=VERIFYING"
if "!STATE_NUMBER!"=="5" set "STATE=COMPLETE"
if "!STATE_NUMBER!"=="6" set "STATE=FAILED"
if "!STATE!"=="COMPLETE" set "PERCENT=100"
exit /b

:draw_progress
setlocal EnableDelayedExpansion
set /a FILLED=(%~1 * 30) / 100
set "BAR="
for /l %%I in (1,1,%FILLED%) do set "BAR=!BAR!#"
set /a EMPTY=30-FILLED
for /l %%I in (1,1,!EMPTY!) do set "BAR=!BAR!-"
echo [!BAR!] %~1%%%
endlocal
exit /b

:quit
exit /b 0
