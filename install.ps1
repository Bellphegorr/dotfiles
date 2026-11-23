#Requires -Version 5.1
<#
.SYNOPSIS
    Copies the files listed in scripts/manifest.ps1 into the current user's
    profile.

.DESCRIPTION
    This mirrors the install model used by dotfiles-wsl: files are copied, not
    hardlinked or symlinked. The last installed copy is tracked under
    %LOCALAPPDATA%\dotfiles\state so local edits can be detected, and replaced
    files are backed up before being overwritten.

    Safe to rerun after a git pull. If a destination differs from both the
    repository and the last installed copy, the run aborts and lists the file.
    Review the difference, then use -Force to replace it (a backup is made).

.PARAMETER Force
    Replace files that differ from both the repository and the last installed
    copy. The current file is backed up first.

.PARAMETER Verify
    Only report the sync state; do not write anything. Exit code 1 means at
    least one file is missing, outdated or different.

.PARAMETER HomeRoot
    Destination home directory. Defaults to $HOME. Intended for tests.

.PARAMETER StateRoot
    Directory for state copies and backups. Defaults to
    %LOCALAPPDATA%\dotfiles\state on Windows.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    .\install.ps1 -Verify
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Verify,
    [string]$HomeRoot = $HOME,
    [string]$StateRoot
)

$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'scripts/manifest.ps1'
$library = Join-Path $repoRoot 'scripts/install-lib.ps1'

Write-Host ''
Write-Host 'Windows dotfiles sync'
Write-Host ("Repository: {0}" -f $repoRoot)
Write-Host ("Home:       {0}" -f $HomeRoot)
Write-Host ''

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "The manifest was not found at $manifestPath"
}
if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
    throw "The install library was not found at $library"
}

. $library

try {
    Install-Begin -Tool 'windows' -Force:$Force -HomeRoot $HomeRoot -StateRoot $StateRoot

    . $manifestPath
    $manifest = @(Get-DotfilesManifest)
    if ($manifest.Count -eq 0) {
        throw 'The manifest is empty.'
    }

    foreach ($entry in $manifest) {
        $source = Join-Path $repoRoot $entry.Source
        Install-File -Source $source -Target $entry.Target
    }

    Write-Host ("Files:      {0}" -f $manifest.Count)
    Write-Host ''

    if ($Verify) {
        if (Test-InstallRun) {
            exit 0
        }
        exit 1
    }

    Install-Run
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host 'Next steps:'
Write-Host '  - Restart YASB (or save config.yaml/styles.css to reload them).'
Write-Host '  - Restart Zed and Windows Terminal if they were open.'
Write-Host '  - If komorebi is already running: komorebic reload-configuration'
