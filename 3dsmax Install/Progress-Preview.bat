@echo off
setlocal
title Installation Progress - Visual Test
set "PROGRESS_PREVIEW_FILE=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$source = [IO.File]::ReadAllText($env:PROGRESS_PREVIEW_FILE); $script = ($source -split '(?m)^# POWERSHELL_START\r?$', 2)[1]; & ([scriptblock]::Create($script))"
exit /b %errorlevel%
# POWERSHELL_START
$ErrorActionPreference = 'Stop'
$oldCursorVisible = [Console]::CursorVisible
try {
    [Console]::CursorVisible = $false
    [Console]::WriteLine('INSTALLATION PROGRESS - VISUAL TEST')
    [Console]::WriteLine('Press any key: +1% | Esc: exit')
    [Console]::WriteLine('')
    $width = [Math]::Max(10, [Math]::Min(40, [Console]::WindowWidth - 35))
    for ($percent = 0; $percent -le 100; $percent++) {
        $filled = [int][Math]::Floor($width * $percent / 100)
        $bar = ('#' * $filled) + ('-' * ($width - $filled))
        $status = if ($percent -eq 100) { 'Complete   ' } else { 'Installing...' }
        [Console]::Write(("`r[{0}] {1,3}%  {2}" -f $bar, $percent, $status))
        if ($percent -lt 100) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Escape) { return }
        }
    }
    [Console]::WriteLine('')
    [Console]::WriteLine('Press any key to close.')
    $null = [Console]::ReadKey($true)
} finally {
    [Console]::CursorVisible = $oldCursorVisible
    [Console]::WriteLine('')
}
