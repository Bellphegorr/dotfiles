# dotfiles

Configuracoes do desktop Windows: Komorebi, whkd, YASB, Zed e Windows Terminal.

O lado WSL tem repositorio proprio:
[dotfiles-wsl](https://github.com/Bellphegorr/dotfiles-wsl).

## Instalacao

Pre-requisitos:

```powershell
winget install --id Git.Git --exact --source winget
winget install --id LGUG2Z.komorebi --exact --source winget
winget install --id LGUG2Z.whkd --exact --source winget
winget install --id AmN.yasb --exact --source winget
winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --source winget
winget install --id ZedIndustries.Zed --exact --source winget
```

O Windows Terminal ja vem no Windows 11.

```powershell
git clone https://github.com/Bellphegorr/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

O repositorio pode ficar em qualquer caminho: o instalador copia para
`%USERPROFILE%`.

- `-Verify`: so compara, nao escreve.
- `-Force`: substitui conflitos depois de guardar backup.

## O que o install.ps1 faz

- Copia os arquivos listados em `scripts/manifest.ps1`; nao usa hardlinks nem
  symlinks.
- Mantem o estado em
  `%LOCALAPPDATA%\dotfiles\state\windows-dotfiles\installed` e os backups em
  `%LOCALAPPDATA%\dotfiles\state\windows-dotfiles-backup\<timestamp>`.
- Arquivo igual ao repo: `ok`. Igual a ultima copia: atualiza com backup.
  Diferente dos dois: conflito, aborta sem alterar; use `-Force`.
- Na primeira execucao, arquivos iguais (inclusive hardlinks antigos) viram
  copias independentes.
- Como e copia, o Windows Terminal e o YASB podem reescrever seus arquivos; a
  proxima execucao detecta a diferenca como conflito.

## Atualizar

```powershell
cd "$HOME\dotfiles"
git pull
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## Estrutura

`scripts/manifest.ps1` e a fonte unica de verdade do mapa origem -> destino. A
tabela abaixo e um resumo.

| Origem | Destino |
| --- | --- |
| `config/komorebi/komorebi.json` | `%USERPROFILE%\komorebi.json` |
| `config/komorebi/applications.json` | `%USERPROFILE%\applications.json` |
| `config/komorebi/start-komorebi.cmd` | `%USERPROFILE%\start-komorebi.cmd` |
| `config/whkd/whkdrc` | `%USERPROFILE%\.config\whkdrc` |
| `config/yasb/config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `config/yasb/styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `config/zed/settings.json` | `%APPDATA%\Zed\settings.json` |
| `config/zed/keymap.json` | `%APPDATA%\Zed\keymap.json` |
| `config/windows-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |

O motor e a validacao ficam em `scripts/install-lib.ps1` e
`scripts/validate.ps1`; `install.ps1` e o ponto de entrada.

## Iniciar

```powershell
& "$HOME\start-komorebi.cmd"
yasb
```

Para iniciar no logon, crie
`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\komorebi-autostart.cmd`:

```cmd
@echo off
call "%USERPROFILE%\start-komorebi.cmd"
```

## Validar

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1
komorebic check -k "$HOME\komorebi.json"
komorebic state
Get-Process komorebi, whkd, yasb
```

## Documentacao

| Guia | Conteudo |
| --- | --- |
| [Monitores](docs/monitores.md) | Mapa de `display_index_preferences` |

## Notas

- O YASB recarrega `config.yaml` e `styles.css` ao salvar. Se o `whkdrc` mudar,
  use `Alt+O` ou reinicie o whkd.
- O `komorebi-bar` nao e usado e o `komorebi.bar.json` nao e sincronizado.
- As conexoes WSL do Zed ficam sem projetos pessoais no repo; adicione os seus
  localmente.
- A validacao e local: rode
  `powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1` antes de
  commitar.
