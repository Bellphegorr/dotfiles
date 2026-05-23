# dotfiles

Configuracoes do meu desktop Windows com Komorebi, whkd e YASB.

## Arquivos

- `.config/yasb/config.yaml`
- `.config/yasb/styles.css`
- `.config/whkdrc`
- `applications.json`
- `komorebi.json`
- `komorebi.bar.json`

## Stack

- `Komorebi`: gerenciador de janelas tiling.
- `whkd`: atalhos de teclado para controlar o Komorebi.
- `YASB`: barra superior com widgets e integracao com o Komorebi.

## Instalar

```powershell
winget install --id Git.Git --exact --source winget
winget install --id LGUG2Z.komorebi --exact --source winget
winget install --id LGUG2Z.whkd --exact --source winget
winget install --id AmN.yasb --exact --source winget
winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --source winget
```

Notas:

- `Segoe UI` e `Segoe Fluent Icons` ja vem no Windows.
- `JetBrainsMono Nerd Font` so e util para a barra nativa do Komorebi.

## Usar

Clone o repositorio:

```powershell
git clone <SEU_REPO> "$HOME\dotfiles"
```

Crie os links para os caminhos usados no Windows:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.config\yasb"
New-Item -ItemType HardLink -Path "$HOME\.config\yasb\config.yaml" -Target "$HOME\dotfiles\.config\yasb\config.yaml"
New-Item -ItemType HardLink -Path "$HOME\.config\yasb\styles.css" -Target "$HOME\dotfiles\.config\yasb\styles.css"
New-Item -ItemType HardLink -Path "$HOME\.config\whkdrc" -Target "$HOME\dotfiles\.config\whkdrc"
New-Item -ItemType HardLink -Path "$HOME\applications.json" -Target "$HOME\dotfiles\applications.json"
New-Item -ItemType HardLink -Path "$HOME\komorebi.json" -Target "$HOME\dotfiles\komorebi.json"
New-Item -ItemType HardLink -Path "$HOME\komorebi.bar.json" -Target "$HOME\dotfiles\komorebi.bar.json"
```

Inicie o ambiente:

```powershell
komorebic start --whkd
yasb
```

## Comandos uteis

```powershell
komorebic reload-configuration
taskkill /f /im whkd.exe; Start-Process whkd -WindowStyle hidden
yasb
```

## Notas

- O YASB recarrega `config.yaml` e `styles.css` ao salvar.
- O arquivo `.config/yasb/yasb.log` e gerado em runtime e nao entra no Git.
- O `whkdrc` ja esta sincronizado neste repositorio.
