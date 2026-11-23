# Shared copy/conflict engine for the Windows dotfiles installer.
#
# This is the PowerShell counterpart of scripts/install-lib.sh in dotfiles-wsl:
#
#   Install-Begin -Tool <name> [-Force] [-HomeRoot <path>] [-StateRoot <path>]
#   Install-File <source> <target relative to HOME>
#   Install-Run
#   Test-InstallRun
#
# Files are copied, never hardlinked or symlinked. The last installed copy of
# each file is kept under <state>/<tool>-dotfiles/installed so that local edits
# can be told apart from files managed by this repository. Replaced files are
# backed up under <state>/<tool>-dotfiles-backup/<timestamp>/.
#
# If a destination differs from both the repository and the last installed
# copy, the whole run aborts unless -Force is used.

$script:InstallItems = @()
$script:InstallTool = ''
$script:InstallForce = $false
$script:InstallHome = ''
$script:InstallStateRoot = ''
$script:InstallStateDir = ''
$script:InstallBackupBase = ''
$script:InstallBackupDir = ''
$script:InstallFirstRun = $false

function Install-Begin {
    param(
        [Parameter(Mandatory)][string]$Tool,
        [switch]$Force,
        [string]$HomeRoot = $HOME,
        [string]$StateRoot
    )

    if (-not $HomeRoot) {
        throw 'HomeRoot is empty.'
    }
    if (-not (Test-Path -LiteralPath $HomeRoot)) {
        New-Item -ItemType Directory -Force -Path $HomeRoot | Out-Null
    }
    if (-not (Test-Path -LiteralPath $HomeRoot -PathType Container)) {
        throw "HomeRoot is not a directory: $HomeRoot"
    }
    $HomeRoot = (Resolve-Path -LiteralPath $HomeRoot).Path

    if (-not $StateRoot) {
        if ($env:LOCALAPPDATA) {
            $StateRoot = Join-Path $env:LOCALAPPDATA 'dotfiles\state'
        } else {
            $StateRoot = Join-Path $HomeRoot '.local/state'
        }
    }

    $script:InstallItems = @()
    $script:InstallTool = $Tool
    $script:InstallForce = [bool]$Force
    $script:InstallHome = $HomeRoot
    $script:InstallStateRoot = $StateRoot
    $script:InstallStateDir = Join-Path (Join-Path $StateRoot ("{0}-dotfiles" -f $Tool)) 'installed'
    $script:InstallBackupBase = Join-Path $StateRoot ("{0}-dotfiles-backup" -f $Tool)
    $script:InstallBackupDir = ''
    $script:InstallFirstRun = -not (Test-Path -LiteralPath (Join-Path $script:InstallStateDir '.installed'))
}

function Install-File {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not $script:InstallHome) {
        throw 'Install-Begin must be called before Install-File.'
    }
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Source file not found: $Source"
    }

    $Target = $Target.TrimStart([char[]]@('\', '/'))
    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    $Target = $Target.Replace('/', $separator).Replace('\', $separator)
    if ([System.IO.Path]::IsPathRooted($Target)) {
        throw "Target must be relative to HOME: $Target"
    }
    if ($Target -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Target must not contain '..': $Target"
    }

    $resolvedSource = (Resolve-Path -LiteralPath $Source).Path
    $destination = Join-Path $script:InstallHome $Target
    $sourceFull = [System.IO.Path]::GetFullPath($resolvedSource).TrimEnd([char[]]@('\', '/'))
    $destFull = [System.IO.Path]::GetFullPath($destination).TrimEnd([char[]]@('\', '/'))
    if ($sourceFull -ieq $destFull) {
        throw "Source and destination are the same file: $destination"
    }

    $script:InstallItems += [pscustomobject]@{
        Source = $resolvedSource
        Target = $Target
    }
}

function Get-InstallDestination {
    param([Parameter(Mandatory)][string]$Target)
    Join-Path $script:InstallHome $Target
}

function Get-InstallStatePath {
    param([Parameter(Mandatory)][string]$Target)
    Join-Path $script:InstallStateDir $Target
}

# Hash text with CRLF normalized to LF so line-ending changes made by Windows
# applications do not look like local edits.
function Get-NormalizedContentHash {
    param([Parameter(Mandatory)][string]$Path)

    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text -replace "`r`n", "`n"
    # Ignore trailing whitespace and final newlines, which Windows applications
    # often add or remove when they rewrite a configuration file.
    $text = (($text -split "`n") | ForEach-Object { $_.TrimEnd() }) -join "`n"
    $text = $text.TrimEnd()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Get-InstallStatus {
    param([Parameter(Mandatory)]$Entry)

    $destination = Get-InstallDestination $Entry.Target
    $previous = Get-InstallStatePath $Entry.Target

    if (-not (Test-Path -LiteralPath $destination)) {
        return 'missing'
    }
    if (Test-Path -LiteralPath $destination -PathType Container) {
        return 'conflict-directory'
    }

    $sourceHash = Get-NormalizedContentHash $Entry.Source
    $destinationHash = Get-NormalizedContentHash $destination
    if ($destinationHash -eq $sourceHash) {
        return 'ok'
    }

    if (Test-Path -LiteralPath $previous -PathType Leaf) {
        $previousHash = Get-NormalizedContentHash $previous
        if ($destinationHash -eq $previousHash) {
            return 'outdated'
        }
    }

    return 'differs'
}

function Backup-InstallTarget {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not $script:InstallBackupDir) {
        New-Item -ItemType Directory -Force -Path $script:InstallBackupBase | Out-Null
        $stamp = Get-Date -Format 'yyyyMMddHHmmss'
        $suffix = [guid]::NewGuid().ToString('N').Substring(0, 6)
        $script:InstallBackupDir = Join-Path $script:InstallBackupBase ("{0}-{1}" -f $stamp, $suffix)
    }

    $backup = Join-Path $script:InstallBackupDir $Target
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    Write-Host ("backup    {0}" -f $backup)
}

function Set-InstallStateCopy {
    param([Parameter(Mandatory)]$Entry)

    $previous = Get-InstallStatePath $Entry.Target
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $previous) | Out-Null
    Copy-Item -LiteralPath $Entry.Source -Destination $previous -Force
}

function Install-Run {
    $conflicts = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $script:InstallItems) {
        $destination = Get-InstallDestination $entry.Target
        if (-not (Test-Path -LiteralPath $destination)) {
            continue
        }
        if (Test-Path -LiteralPath $destination -PathType Container) {
            $conflicts.Add("destination is a directory: $destination")
            continue
        }

        $status = Get-InstallStatus $entry
        if ($status -eq 'ok' -or $status -eq 'outdated') {
            continue
        }
        if (-not $script:InstallForce) {
            $conflicts.Add("conflict: $destination differs from the repository or the last installed copy; review it before using -Force")
        }
    }

    if ($conflicts.Count -gt 0) {
        throw ("Install aborted:`n  " + ($conflicts -join "`n  "))
    }

    $copied = 0
    $unchanged = 0
    $backedUp = 0

    foreach ($entry in $script:InstallItems) {
        $destination = Get-InstallDestination $entry.Target
        $status = Get-InstallStatus $entry
        $replaceIdentical = $false

        if ($status -eq 'ok') {
            if ($script:InstallFirstRun) {
                # A legacy hardlink or symlink may still have identical content.
                # Replacing it on the first run turns it into an independent copy.
                $replaceIdentical = $true
            } else {
                Set-InstallStateCopy $entry
                Write-Host ("ok        {0}" -f $destination)
                $unchanged++
                continue
            }
        }

        if (Test-Path -LiteralPath $destination) {
            if ($status -ne 'ok') {
                Backup-InstallTarget -Path $destination -Target $entry.Target
                $backedUp++
            }
            Remove-Item -LiteralPath $destination -Force
        }

        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $destination -Force
        Set-InstallStateCopy $entry

        if ($replaceIdentical) {
            Write-Host ("copied    {0} (first run)" -f $destination)
        } else {
            Write-Host ("copied    {0}" -f $destination)
        }
        $copied++
    }

    New-Item -ItemType Directory -Force -Path $script:InstallStateDir | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $script:InstallStateDir '.installed') | Out-Null

    Write-Host ''
    Write-Host ("Sync finished: {0} copied, {1} unchanged, {2} backed up." -f $copied, $unchanged, $backedUp)
    if ($script:InstallBackupDir) {
        Write-Host ("Backups: {0}" -f $script:InstallBackupDir)
    }
    Write-Host ("State:   {0}" -f $script:InstallStateDir)
}

function Test-InstallRun {
    $ok = 0
    $missing = 0
    $outdated = 0
    $different = 0

    foreach ($entry in $script:InstallItems) {
        $destination = Get-InstallDestination $entry.Target
        $status = Get-InstallStatus $entry
        switch ($status) {
            'ok' {
                Write-Host ("ok        {0}" -f $destination)
                $ok++
            }
            'missing' {
                Write-Host ("missing   {0}" -f $destination) -ForegroundColor Yellow
                $missing++
            }
            'outdated' {
                Write-Host ("outdated  {0}" -f $destination) -ForegroundColor Yellow
                $outdated++
            }
            default {
                Write-Host ("differs   {0} ({1})" -f $destination, $status) -ForegroundColor Yellow
                $different++
            }
        }
    }

    Write-Host ''
    Write-Host ("Verify: {0} ok, {1} missing, {2} outdated, {3} different." -f $ok, $missing, $outdated, $different)
    return (($missing + $outdated + $different) -eq 0)
}
