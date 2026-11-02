#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$IsoPath = 'C:\Install\Autodesk.3ds.Max.2025.3.Multilingual.iso',
    [string]$LogPath = 'C:\Install\3dsMax-2025-install.log',
    [switch]$KeepIsoMounted
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$mountedByScript = $false

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')

    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Level, $Message
    Write-Output $line
    $logDirectory = [System.IO.Path]::GetDirectoryName($LogPath)
    if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script from an elevated PowerShell (Run as Administrator).'
    }
}

try {
    Assert-Administrator

    if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
        throw "ISO file was not found: $IsoPath"
    }

    Write-Log "Starting silent installation from $IsoPath"

    $diskImage = Get-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    if ($null -eq $diskImage -or -not $diskImage.Attached) {
        $diskImage = Mount-DiskImage -ImagePath $IsoPath -PassThru
        $mountedByScript = $true
    } else {
        $mountedByScript = $false
    }

    $drive = $null
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline -and -not $drive) {
        Start-Sleep -Milliseconds 250
        $drive = ($diskImage | Get-Volume | Where-Object { $_.DriveLetter } |
            Select-Object -First 1).DriveLetter
    }

    if (-not $drive) {
        throw 'The ISO mounted, but Windows did not expose a drive letter.'
    }

    $mediaRoot = "${drive}:"
    $setup = Join-Path $mediaRoot 'Setup.exe'
    if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) {
        $setup = Get-ChildItem -LiteralPath $mediaRoot -Filter 'Setup.exe' -File -Recurse |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $setup) {
        throw "Setup.exe was not found below $mediaRoot"
    }

    Write-Log "Mounted ISO at $mediaRoot"
    Write-Log "Launching $setup --silent"

    $process = Start-Process -FilePath $setup `
        -ArgumentList '--silent' `
        -WorkingDirectory ([System.IO.Path]::GetDirectoryName($setup)) `
        -PassThru `
        -Wait

    $installDirectory = 'C:\Program Files\Autodesk\3ds Max 2025'
    $maxExecutable = Join-Path $installDirectory '3dsmax.exe'
    if (-not (Test-Path -LiteralPath $maxExecutable -PathType Leaf)) {
        throw "Installer exited with code $($process.ExitCode), and 3dsmax.exe was not found. Review $LogPath."
    }

    Write-Log 'Installation completed successfully.'
}
catch {
    Write-Log $_.Exception.Message 'ERROR'
    if ($_.InvocationInfo -and $_.InvocationInfo.Line) {
        Write-Log "Command: $($_.InvocationInfo.Line.Trim())" 'ERROR'
    }
    exit 1
}
finally {
    if (-not $KeepIsoMounted -and $mountedByScript -and $IsoPath) {
        try {
            Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Unmounted $IsoPath"
        }
        catch {
            Write-Log "Could not unmount the ISO: $($_.Exception.Message)" 'WARNING'
        }
    }
}
