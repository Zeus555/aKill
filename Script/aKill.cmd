@echo off
:: Puente para invocar aKill.ps1 desde cmd sin escribir la linea de powershell.
:: Uso:  aKill -Name chrome -MinAge 30 -Kill      (aKill /? para la ayuda)
if "%~1"=="/?" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aKill.ps1" -Help
    exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aKill.ps1" %*
exit /b %ERRORLEVEL%
