@echo off
:: Doble clic para quitar aKill del PATH del usuario. No borra ningun archivo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1" -Desinstalar
pause
