#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the tracked configuration files without changing them.

.DESCRIPTION
    Runs on Windows PowerShell 5.1 and PowerShell 7. Checks strict JSON,
    JSONC for Zed, YAML structure, CSS brace balance and the repository layout.
    Exits with code 1 when any check fails.

    Run it before committing; it is the local validation gate.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}

$script:Checks = 0
$script:Failures = 0

function Pass {
    param([string]$Message)
    Write-Host ("OK    {0}" -f $Message) -ForegroundColor Green
    $script:Checks++
}

function Fail {
    param([string]$Message)
    Write-Host ("FAIL  {0}" -f $Message) -ForegroundColor Red
    $script:Failures++
}

function Check-File {
    param([string]$Relative)
    $path = Join-Path $RepoRoot $Relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Pass $Relative
        return $path
    }
    Fail ("{0} (missing)" -f $Relative)
    return $null
}

# Strict JSON: comments and trailing commas are rejected before ConvertFrom-Json
# is asked to parse the content. ConvertFrom-Json alone is too forgiving on some
# PowerShell versions for the komorebi configuration.
function Test-StrictJson {
    param([string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    $line = 1
    $inString = $false
    $escaped = $false
    $errors = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $raw.Length; $i++) {
        $c = $raw[$i]
        if ($c -eq "`n") {
            $line++
            continue
        }

        if ($inString) {
            if ($escaped) {
                $escaped = $false
            } elseif ($c -eq '\') {
                $escaped = $true
            } elseif ($c -eq '"') {
                $inString = $false
            }
            continue
        }

        if ($c -eq '"') {
            $inString = $true
            continue
        }

        if ($c -eq '/' -and $i + 1 -lt $raw.Length -and $raw[$i + 1] -eq '/') {
            $errors.Add("line ${line}: // comments are not valid JSON")
            while ($i -lt $raw.Length -and $raw[$i] -ne "`n") { $i++ }
            if ($i -lt $raw.Length) { $line++ }
            continue
        }

        if ($c -eq '/' -and $i + 1 -lt $raw.Length -and $raw[$i + 1] -eq '*') {
            $errors.Add("line ${line}: /* */ comments are not valid JSON")
            $i += 2
            while ($i + 1 -lt $raw.Length -and -not ($raw[$i] -eq '*' -and $raw[$i + 1] -eq '/')) {
                if ($raw[$i] -eq "`n") { $line++ }
                $i++
            }
            $i++
            continue
        }

        if ($c -eq ',') {
            $j = $i + 1
            while ($j -lt $raw.Length -and [char]::IsWhiteSpace($raw[$j])) { $j++ }
            if ($j -lt $raw.Length -and ($raw[$j] -eq '}' -or $raw[$j] -eq ']')) {
                $errors.Add("line ${line}: trailing commas are not valid JSON")
            }
        }
    }

    if ($errors.Count -gt 0) {
        return @{ Ok = $false; Error = ($errors -join '; ') }
    }

    try {
        $null = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        return @{ Ok = $true; Error = '' }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Remove-JsonComments {
    param([string]$Raw)

    $out = New-Object System.Text.StringBuilder
    $inString = $false
    $escaped = $false

    for ($i = 0; $i -lt $Raw.Length; $i++) {
        $c = $Raw[$i]

        if ($inString) {
            [void]$out.Append($c)
            if ($escaped) {
                $escaped = $false
            } elseif ($c -eq '\') {
                $escaped = $true
            } elseif ($c -eq '"') {
                $inString = $false
            }
            continue
        }

        if ($c -eq '"') {
            $inString = $true
            [void]$out.Append($c)
            continue
        }

        if ($c -eq '/' -and $i + 1 -lt $Raw.Length -and $Raw[$i + 1] -eq '/') {
            while ($i -lt $Raw.Length -and $Raw[$i] -ne "`n") { $i++ }
            if ($i -lt $Raw.Length) { [void]$out.Append("`n") }
            continue
        }

        if ($c -eq '/' -and $i + 1 -lt $Raw.Length -and $Raw[$i + 1] -eq '*') {
            $i += 2
            while ($i + 1 -lt $Raw.Length -and -not ($Raw[$i] -eq '*' -and $Raw[$i + 1] -eq '/')) {
                if ($Raw[$i] -eq "`n") { [void]$out.Append("`n") }
                $i++
            }
            $i++
            continue
        }

        [void]$out.Append($c)
    }

    return $out.ToString()
}

function Test-Jsonc {
    param([string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    $stripped = Remove-JsonComments $raw
    try {
        $null = ConvertFrom-Json -InputObject $stripped -ErrorAction Stop
        return @{ Ok = $true; Error = '' }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Report-Json {
    param(
        [string]$Label,
        [string]$Path,
        [switch]$AllowComments
    )

    if (-not $Path) { return $false }

    if ($AllowComments) {
        $result = Test-Jsonc $Path
    } else {
        $result = Test-StrictJson $Path
    }

    if ($result.Ok) {
        $kind = if ($AllowComments) { 'JSONC' } else { 'JSON' }
        Pass ("{0} (valid {1})" -f $Label, $kind)
        return $true
    }

    Fail ("{0} ({1})" -f $Label, $result.Error)
    return $false
}

$required = @(
    'install.ps1',
    'scripts/install-lib.ps1',
    'scripts/manifest.ps1',
    'scripts/validate.ps1'
)

$paths = @{}
foreach ($relative in $required) {
    $path = Check-File $relative
    if ($path) { $paths[$relative] = $path }
}

$manifest = @()
$manifestPath = $paths['scripts/manifest.ps1']
if ($manifestPath) {
    . $manifestPath
    $manifest = @(Get-DotfilesManifest)
    if ($manifest.Count -eq 0) {
        Fail 'manifest is empty'
    }
    foreach ($entry in $manifest) {
        $sourcePath = Join-Path $RepoRoot $entry.Source
        $targetOk = $entry.Target -and
            -not [System.IO.Path]::IsPathRooted($entry.Target) -and
            $entry.Target -notmatch '(^|[\\/])\.\.([\\/]|$)'
        if ((Test-Path -LiteralPath $sourcePath -PathType Leaf) -and $targetOk) {
            Pass ("manifest: {0} -> {1}" -f $entry.Source, $entry.Target)
            $paths[$entry.Source] = $sourcePath
        } else {
            Fail ("manifest: {0} -> {1}" -f $entry.Source, $entry.Target)
        }
    }
    Pass ("manifest has {0} entries" -f $manifest.Count)
}

Write-Host ''

$komorebiPath = $paths['config/komorebi/komorebi.json']
if (Report-Json 'komorebi.json' $komorebiPath) {
    $komorebi = ConvertFrom-Json ([System.IO.File]::ReadAllText($komorebiPath))

    if ($komorebi.app_specific_configuration_path -eq '$Env:USERPROFILE/applications.json') {
        Pass 'komorebi.json app_specific_configuration_path'
    } else {
        Fail ("komorebi.json app_specific_configuration_path is '{0}'" -f $komorebi.app_specific_configuration_path)
    }

    $preferenceNames = @($komorebi.display_index_preferences.PSObject.Properties.Name)
    $missingPreferences = @(0..5 | Where-Object { $preferenceNames -notcontains [string]$_ })
    if ($missingPreferences.Count -eq 0) {
        Pass 'komorebi.json display_index_preferences (0-5)'
    } else {
        Fail ("komorebi.json display_index_preferences missing: {0}" -f ($missingPreferences -join ', '))
    }

    if (@($komorebi.monitors).Count -eq 6) {
        Pass 'komorebi.json has 6 monitors'
    } else {
        Fail ("komorebi.json has {0} monitors (expected 6)" -f @($komorebi.monitors).Count)
    }

    $workspaceCounts = @($komorebi.monitors | ForEach-Object { @($_.workspaces).Count })
    if (@($workspaceCounts | Where-Object { $_ -ne 8 }).Count -eq 0) {
        Pass 'komorebi.json has 8 workspaces per monitor'
    } else {
        Fail ("komorebi.json workspace counts: {0}" -f ($workspaceCounts -join ', '))
    }
}

$applicationsPath = $paths['config/komorebi/applications.json']
if (Report-Json 'applications.json' $applicationsPath) {
    $applications = ConvertFrom-Json ([System.IO.File]::ReadAllText($applicationsPath))
    $applicationNames = @($applications.PSObject.Properties.Name | Where-Object { $_ -ne '$schema' })
    if ($applicationNames.Count -gt 0) {
        Pass ("applications.json ({0} app entries)" -f $applicationNames.Count)
    } else {
        Fail 'applications.json has no app entries'
    }
    if ($applications.'$schema' -match 'komorebi/v0\.1\.41/schema\.asc\.json$') {
        Pass 'applications.json schema is pinned to v0.1.41'
    } else {
        Fail ("applications.json schema is '{0}'" -f $applications.'$schema')
    }
}

$wtPath = $paths['config/windows-terminal/settings.json']
if (Report-Json 'Windows Terminal settings.json' $wtPath) {
    $wt = ConvertFrom-Json ([System.IO.File]::ReadAllText($wtPath))
    if ($wt.profiles.defaults.font.face -eq 'JetBrainsMono Nerd Font') {
        Pass 'Windows Terminal font face'
    } else {
        Fail ("Windows Terminal font face is '{0}'" -f $wt.profiles.defaults.font.face)
    }
}

$zedPath = $paths['config/zed/settings.json']
if ($zedPath) {
    $zedResult = Test-Jsonc $zedPath
    if ($zedResult.Ok) {
        Pass 'Zed settings.json (valid JSONC)'
        $zed = ConvertFrom-Json (Remove-JsonComments ([System.IO.File]::ReadAllText($zedPath)))
        $zedProjects = @($zed.wsl_connections[0].projects)
        if ($zedProjects.Count -eq 0) {
            Pass 'Zed settings.json has no personal WSL projects'
        } else {
            Fail 'Zed settings.json still lists personal WSL projects'
        }
    } else {
        Fail ("Zed settings.json ({0})" -f $zedResult.Error)
    }
}

Report-Json 'Zed keymap.json' $paths['config/zed/keymap.json'] -AllowComments | Out-Null

$yamlPath = $paths['config/yasb/config.yaml']
if ($yamlPath) {
    $yaml = [System.IO.File]::ReadAllText($yamlPath)
    $yamlChecks = @(
        @{ Name = 'watch_stylesheet: true'; Pattern = '(?m)^watch_stylesheet:\s*true\s*$' },
        @{ Name = 'bars section'; Pattern = '(?m)^bars:\s*$' },
        @{ Name = 'widgets section'; Pattern = '(?m)^widgets:\s*$' },
        @{ Name = 'start_command uses %USERPROFILE%\start-komorebi.cmd'; Pattern = '(?m)^\s*start_command:.*%USERPROFILE%\\start-komorebi\.cmd' }
    )
    foreach ($check in $yamlChecks) {
        if ($yaml -match $check.Pattern) {
            Pass ("YASB {0}" -f $check.Name)
        } else {
            Fail ("YASB {0}" -f $check.Name)
        }
    }
    if ($yaml -match '(?m)^\t') {
        Fail 'YASB config.yaml contains tab indentation'
    } else {
        Pass 'YASB config.yaml has no tab indentation'
    }
    if ($yaml -match '(?m)^  taskbar:\s*$') {
        Fail 'YASB config.yaml still defines the unused taskbar widget'
    } else {
        Pass 'YASB config.yaml has no unused taskbar widget'
    }
    if ($yaml -match '(?m)^\s*start_command:.*dotfiles') {
        Fail 'YASB start_command still references the dotfiles path'
    } else {
        Pass 'YASB start_command is independent of the clone path'
    }
}

$cssPath = $paths['config/yasb/styles.css']
if ($cssPath) {
    $css = [System.IO.File]::ReadAllText($cssPath)
    $open = ([regex]::Matches($css, '\{')).Count
    $close = ([regex]::Matches($css, '\}')).Count
    if ($open -eq $close) {
        Pass ("styles.css braces ({0})" -f $open)
    } else {
        Fail ("styles.css braces: {0} open, {1} close" -f $open, $close)
    }
}

$launcherPath = $paths['config/komorebi/start-komorebi.cmd']
if ($launcherPath) {
    $launcher = [System.IO.File]::ReadAllText($launcherPath)
    if ($launcher -match '%~dp0komorebi\.json') {
        Pass 'start-komorebi.cmd uses %~dp0komorebi.json'
    } else {
        Fail 'start-komorebi.cmd does not use %~dp0komorebi.json'
    }
    if ($launcher -match '--whkd') {
        Pass 'start-komorebi.cmd starts whkd'
    } else {
        Fail 'start-komorebi.cmd does not start whkd'
    }
    if ($launcher -match 'dotfiles') {
        Fail 'start-komorebi.cmd still references dotfiles'
    } else {
        Pass 'start-komorebi.cmd is independent of the clone path'
    }
}

$autostartPath = $paths['config/komorebi/komorebi-autostart.cmd']
if ($autostartPath) {
    $autostart = [System.IO.File]::ReadAllText($autostartPath)
    if ($autostart -match '%USERPROFILE%\\start-komorebi\.cmd') {
        Pass 'komorebi-autostart.cmd calls %USERPROFILE%\start-komorebi.cmd'
    } else {
        Fail 'komorebi-autostart.cmd does not call %USERPROFILE%\start-komorebi.cmd'
    }
    if ($autostart -match 'dotfiles') {
        Fail 'komorebi-autostart.cmd still references dotfiles'
    } else {
        Pass 'komorebi-autostart.cmd is independent of the clone path'
    }
}

Write-Host ''
if ($script:Failures -gt 0) {
    Write-Host ("Validation failed: {0} failure(s), {1} check(s)." -f $script:Failures, $script:Checks) -ForegroundColor Red
    exit 1
}

Write-Host ("Validation passed: {0} check(s)." -f $script:Checks) -ForegroundColor Green
exit 0
