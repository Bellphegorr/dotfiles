# Single source of truth for the repository -> user profile mapping.
#
# Targets are relative to the user's home directory and use forward slashes;
# Install-File normalizes the separator for the current platform. Keep this
# list in sync with the structure documented in README.md.
function Get-DotfilesManifest {
    @(
        [pscustomobject]@{
            Source = 'config/komorebi/komorebi.json'
            Target = 'komorebi.json'
        }
        [pscustomobject]@{
            Source = 'config/komorebi/applications.json'
            Target = 'applications.json'
        }
        [pscustomobject]@{
            Source = 'config/komorebi/start-komorebi.cmd'
            Target = 'start-komorebi.cmd'
        }
        [pscustomobject]@{
            Source = 'config/komorebi/komorebi-autostart.cmd'
            Target = 'AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/komorebi-autostart.cmd'
        }
        [pscustomobject]@{
            Source = 'config/whkd/whkdrc'
            Target = '.config/whkdrc'
        }
        [pscustomobject]@{
            Source = 'config/yasb/config.yaml'
            Target = '.config/yasb/config.yaml'
        }
        [pscustomobject]@{
            Source = 'config/yasb/styles.css'
            Target = '.config/yasb/styles.css'
        }
        [pscustomobject]@{
            Source = 'config/zed/settings.json'
            Target = 'AppData/Roaming/Zed/settings.json'
        }
        [pscustomobject]@{
            Source = 'config/zed/keymap.json'
            Target = 'AppData/Roaming/Zed/keymap.json'
        }
        [pscustomobject]@{
            Source = 'config/windows-terminal/settings.json'
            Target = 'AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'
        }
    )
}
