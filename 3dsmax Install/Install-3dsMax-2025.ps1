#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$IsoPath = 'C:\Install\Autodesk.3ds.Max.2025.3.Multilingual.iso',
    [string]$LogPath = 'C:\Install\3dsMax-2025-install.log',
    [string]$StatusPath = 'C:\Install\3dsMax-2025-status.txt',
    [int]$EstimatedInstalledFiles = 8000,
    [int]$InstallerTimeoutSeconds = 300,
    [int]$StatusRefreshSeconds = 2,
    [switch]$KeepIsoMounted
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$mountedByScript = $false

function Write-Status {
    param(
        [ValidateRange(0, 100)][int]$Percent,
        [string]$Message
    )

    $statusDirectory = Split-Path -Parent $StatusPath
    if ($statusDirectory -and -not (Test-Path -LiteralPath $statusDirectory)) {
        New-Item -ItemType Directory -Path $statusDirectory -Force | Out-Null
    }
    Set-Content -LiteralPath $StatusPath -Value "$Percent%|$Message" -Encoding UTF8
    $width = [Math]::Max(10, [Math]::Min(40, [Console]::WindowWidth - 35))
    $filled = [int][Math]::Floor($width * $Percent / 100)
    $bar = ('#' * $filled) + ('-' * ($width - $filled))
    [Console]::Write(("`r[{0}] {1,3}%  {2}" -f $bar, $Percent, $Message))
}

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

function Get-FolderFileSnapshot {
    param([string[]]$Paths)

    $count = 0
    $bytes = 0L
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            continue
        }

        foreach ($file in Get-ChildItem -LiteralPath $path -File -Recurse -Force -ErrorAction SilentlyContinue) {
            $count++
            $bytes += $file.Length
        }
    }

    return [PSCustomObject]@{ FileCount = $count; Bytes = $bytes }
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

    $maxExecutable = 'C:\Program Files\Autodesk\3ds Max 2025\3dsmax.exe'
    if (Test-Path -LiteralPath $maxExecutable -PathType Leaf) {
        Write-Log 'Autodesk 3ds Max 2025 is already installed successfully.'
        Write-Status 100 'Autodesk 3ds Max 2025 is already installed.'
        exit 0
    }

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
    Write-Log "Launching $setup -q"
    Write-Status 20 'Waiting for Autodesk Setup to start...'

    $maxInstallerLog = Join-Path ([System.IO.Path]::GetTempPath()) '3dsMax_2025_install.log'
    $maxInstallerLogBaseline = if (Test-Path -LiteralPath $maxInstallerLog -PathType Leaf) {
        (Get-Item -LiteralPath $maxInstallerLog).LastWriteTimeUtc
    } else {
        $null
    }

    $setupProcess = Start-Process -FilePath $setup `
        -ArgumentList '-q' `
        -WorkingDirectory ([System.IO.Path]::GetDirectoryName($setup)) `
        -PassThru

    $deadline = (Get-Date).AddSeconds($InstallerTimeoutSeconds)
    $installRoot = Split-Path -Path $maxExecutable -Parent
    $stableExecutableSince = $null
    $monitorRoots = @(
        $installRoot,
        (Join-Path ([System.IO.Path]::GetTempPath()) 'odis_download_dest'),
        'C:\Program Files\Autodesk\AdODIS',
        'C:\Program Files\Common Files\Autodesk Shared',
        'C:\Program Files (x86)\Common Files\Autodesk Shared',
        'C:\ProgramData\Autodesk'
    )
    $snapshot = Get-FolderFileSnapshot -Paths $monitorRoots
    $installedFileCount = $snapshot.FileCount

    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $maxInstallerLog -PathType Leaf) {
            $maxInstallerLastWriteTime = (Get-Item -LiteralPath $maxInstallerLog).LastWriteTimeUtc
            if ($null -eq $maxInstallerLogBaseline -or $maxInstallerLastWriteTime -gt $maxInstallerLogBaseline) {
                $maxInstallerResult = Get-Content -LiteralPath $maxInstallerLog -Tail 500 -ErrorAction SilentlyContinue
                if ($maxInstallerResult -match 'Installation success or error status: 1602') {
                    throw "Autodesk 3ds Max installation was cancelled or rolled back (Windows Installer status 1602). Review $maxInstallerLog."
                }
            }
        }

        if (Test-Path -LiteralPath $maxExecutable -PathType Leaf) {
            if ($null -eq $stableExecutableSince) {
                $stableExecutableSince = Get-Date
            }

            if (((Get-Date) - $stableExecutableSince).TotalSeconds -ge 30) {
                Write-Status 100 'Installation completed successfully.'
                Write-Log 'Installation completed successfully.'
                exit 0
            }

            Write-Status 95 'Verifying the completed installation...'
        } else {
            $stableExecutableSince = $null
        }

        $snapshot = Get-FolderFileSnapshot -Paths $monitorRoots
        $installedFileCount = $snapshot.FileCount
        $sizeMb = [Math]::Round($snapshot.Bytes / 1MB, 0)

        $calculatedPercent = [Math]::Min(95, [Math]::Max(20, 20 + [int](75 * $installedFileCount / $EstimatedInstalledFiles)))
        Write-Status $calculatedPercent "Installing Autodesk 3ds Max 2025... ($installedFileCount files, $sizeMb MB)"

        if ($setupProcess.HasExited) {
            Start-Sleep -Seconds ([Math]::Max(1, $StatusRefreshSeconds))
            if (Test-Path -LiteralPath $maxExecutable -PathType Leaf) {
                $verificationDeadline = (Get-Date).AddSeconds(30)
                while ((Get-Date) -lt $verificationDeadline -and (Test-Path -LiteralPath $maxExecutable -PathType Leaf)) {
                    Start-Sleep -Seconds 5
                }
                if (Test-Path -LiteralPath $maxExecutable -PathType Leaf) {
                    Write-Status 100 'Installation completed successfully.'
                    Write-Log 'Installation completed successfully.'
                    exit 0
                }
            }
        }

        Start-Sleep -Seconds 10
    }

    if (-not (Test-Path -LiteralPath $maxExecutable -PathType Leaf)) {
        throw "Installation timed out after $InstallerTimeoutSeconds seconds. 3dsmax.exe was not found. Review $LogPath."
    }
}
catch {
    Write-Status 0 $_.Exception.Message
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
