@echo off
set "OUT=C:\Install\3dsMax-task-output.log"
set "ERR=C:\Install\3dsMax-task-error.log"
if not exist C:\Install mkdir C:\Install

"%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-3dsMax-2025.ps1" 1>"%OUT%" 2>"%ERR%"
exit /b %errorlevel%
