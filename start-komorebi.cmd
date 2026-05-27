@echo off
set "KOMOREBIC=%ProgramFiles%\komorebi\bin\komorebic.exe"
if exist "%KOMOREBIC%" (
    "%KOMOREBIC%" start --config "%USERPROFILE%\dotfiles\komorebi.json" --whkd
) else (
    komorebic start --config "%USERPROFILE%\dotfiles\komorebi.json" --whkd
)