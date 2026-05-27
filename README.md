# dotfiles

Configuracoes do meu desktop Windows com Komorebi, whkd e YASB.

## Arquivos

- `.config/yasb/config.yaml`
- `.config/yasb/styles.css`
- `.config/whkdrc`
- `AppData/Roaming/Zed/settings.json`
- `AppData/Roaming/Zed/keymap.json`
- `applications.json`
- `komorebi.json`
- `komorebi.bar.json`

## Stack

- `Komorebi`: gerenciador de janelas tiling.
- `whkd`: atalhos de teclado para controlar o Komorebi.
- `YASB`: barra superior com widgets e integracao com o Komorebi.
- `Zed`: editor de texto com foco em performance e colaboracao.

## Instalar

```powershell
winget install --id Git.Git --exact --source winget
winget install --id LGUG2Z.komorebi --exact --source winget
winget install --id LGUG2Z.whkd --exact --source winget
winget install --id AmN.yasb --exact --source winget
winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --source winget
```

Abra um novo terminal depois do `winget` e confirme que os binarios ficaram no `PATH`:

```powershell
Get-Command komorebic, whkd, yasb
```

Se `komorebic` ou `whkd` nao forem encontrados, adicione os bins ao `PATH` do usuario:

```powershell
$required = @("C:\Program Files\komorebi\bin", "C:\Program Files\whkd\bin")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$segments = $userPath -split ';' | Where-Object { $_ }
foreach ($dir in $required) {
	if ($segments -notcontains $dir) {
		$segments += $dir
	}
}
[Environment]::SetEnvironmentVariable("Path", ($segments | Select-Object -Unique) -join ';', "User")
```

Notas:

- `Segoe UI` e `Segoe Fluent Icons` ja vem no Windows.
- `JetBrainsMono Nerd Font` so e util para a barra nativa do Komorebi.

## Usar

Clone o repositorio:

```powershell
git clone <SEU_REPO> "$HOME\dotfiles"
```

Se ja houver configuracoes nesses caminhos, faca backup ou mova os arquivos antes de criar os links. O `New-Item` falha se o destino ja existir.

Exemplo de backup rapido:

```powershell
$backupRoot = Join-Path $HOME ("dotfiles-backup\komorebi-yasb-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$paths = @(
	"$HOME\.config\yasb\config.yaml",
	"$HOME\.config\yasb\styles.css",
	"$HOME\.config\whkdrc",
	"$HOME\AppData\Roaming\Zed\settings.json",
	"$HOME\AppData\Roaming\Zed\keymap.json",
	"$HOME\applications.json",
	"$HOME\komorebi.json",
	"$HOME\komorebi.bar.json"
)

foreach ($path in $paths) {
	if (Test-Path $path) {
		$backup = Join-Path $backupRoot ($path.Replace("$HOME\", ""))
		New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
		Move-Item -Path $path -Destination $backup -Force
	}
}
```

Crie os links para os caminhos usados no Windows:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.config\yasb"
New-Item -ItemType Directory -Force -Path "$HOME\AppData\Roaming\Zed"
New-Item -ItemType HardLink -Path "$HOME\.config\yasb\config.yaml" -Target "$HOME\dotfiles\.config\yasb\config.yaml"
New-Item -ItemType HardLink -Path "$HOME\.config\yasb\styles.css" -Target "$HOME\dotfiles\.config\yasb\styles.css"
New-Item -ItemType HardLink -Path "$HOME\.config\whkdrc" -Target "$HOME\dotfiles\.config\whkdrc"
New-Item -ItemType HardLink -Path "$HOME\AppData\Roaming\Zed\settings.json" -Target "$HOME\dotfiles\AppData\Roaming\Zed\settings.json"
New-Item -ItemType HardLink -Path "$HOME\AppData\Roaming\Zed\keymap.json" -Target "$HOME\dotfiles\AppData\Roaming\Zed\keymap.json"
New-Item -ItemType HardLink -Path "$HOME\applications.json" -Target "$HOME\dotfiles\applications.json"
New-Item -ItemType HardLink -Path "$HOME\komorebi.json" -Target "$HOME\dotfiles\komorebi.json"
New-Item -ItemType HardLink -Path "$HOME\komorebi.bar.json" -Target "$HOME\dotfiles\komorebi.bar.json"
```

O `komorebi.json` do repositorio referencia diretamente `dotfiles/applications.json`, e os arquivos na raiz ficam apenas como caminhos de compatibilidade no Windows.

Inicie o ambiente:

```powershell
& "$HOME\dotfiles\start-komorebi.cmd"
yasb
```

Para iniciar automaticamente no logon, deixe um launcher em `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\komorebi-autostart.cmd` com este conteudo:

```cmd
@echo off
call "%USERPROFILE%\dotfiles\start-komorebi.cmd"
```

Valide o setup:

```powershell
komorebic check
komorebic state
Get-Process komorebi, whkd, yasb
```

## Notas

- O YASB recarrega `config.yaml` e `styles.css` ao salvar.
- O arquivo `.config/yasb/yasb.log` e gerado em runtime e nao entra no Git.
- O Zed usa `settings.json` e `keymap.json` em `%APPDATA%\Zed`; como os arquivos ficam no mesmo volume, este repositorio usa hardlinks para ambos.
- O `whkdrc` ja esta sincronizado neste repositorio.
- O launcher `start-komorebi.cmd` sempre usa `dotfiles/komorebi.json`, mesmo quando o Komorebi e iniciado pelo YASB ou pelo Startup do Windows.
