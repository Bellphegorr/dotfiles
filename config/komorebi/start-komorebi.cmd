@echo off
setlocal

set "KOMOREBIC=%ProgramFiles%\komorebi\bin\komorebic.exe"
set "CONFIG=%~dp0komorebi.json"

if not exist "%CONFIG%" (
    echo Config not found: %CONFIG%
    exit /b 1
)

if exist "%KOMOREBIC%" (
    "%KOMOREBIC%" start --config "%CONFIG%" --whkd
) else (
    komorebic start --config "%CONFIG%" --whkd
)
