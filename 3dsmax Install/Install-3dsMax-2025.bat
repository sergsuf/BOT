@echo off
setlocal

set "SCRIPT=%~dp0Install-3dsMax-2025.ps1"

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$script='%SCRIPT%'; $identity=[Security.Principal.WindowsIdentity]::GetCurrent(); $principal=[Security.Principal.WindowsPrincipal]::new($identity); if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){ & $script; exit $LASTEXITCODE } else { $process=Start-Process -FilePath '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$script -Verb RunAs -Wait -PassThru; exit $process.ExitCode }"

if errorlevel 1 (
    echo Installation failed. Check C:\Install\3dsMax-2025-install.log
    pause
    exit /b 1
)

echo Installation finished successfully.
pause
