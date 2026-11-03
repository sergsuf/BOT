@echo off
setlocal

set "SCRIPT=%~dp0Install-3dsMax-2025.ps1"
set "MAXEXE=C:\Program Files\Autodesk\3ds Max 2025\3dsmax.exe"

if exist "%MAXEXE%" (
    echo 3ds Max 2025 is already installed successfully.
    echo Program: "%MAXEXE%"
    pause
    exit /b 0
)

net session >nul 2>&1
if errorlevel 1 (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$process = Start-Process -FilePath '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%SCRIPT%' -Verb RunAs -Wait -PassThru; exit $process.ExitCode"
) else (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)

if errorlevel 1 (
    echo Installation failed. Check C:\Install\3dsMax-2025-install.log
    pause
    exit /b 1
)

echo Installation finished successfully.
pause
