<#
.SYNOPSIS
    Agrega aKill al PATH del usuario, o lo quita con -Desinstalar.

.DESCRIPTION
    No copia archivos ni pide permisos de administrador: registra la carpeta Script
    tal como esta, asi que esta carpeta debe quedarse donde se instalo.

.PARAMETER Desinstalar
    Quita aKill del PATH. No borra ningun archivo.
#>
[CmdletBinding()]
param(
    [switch] $Desinstalar
)

$carpeta = Join-Path $PSScriptRoot 'Script'
if (-not (Test-Path (Join-Path $carpeta 'aKill.ps1'))) {
    Write-Host "No se encuentra Script\aKill.ps1. Descomprime el ZIP completo antes de ejecutar esto." -ForegroundColor Red
    exit 1
}

# Se lee y se escribe sin expandir: otras entradas pueden usar %USERPROFILE%, y
# GetEnvironmentVariable las dejaria convertidas en rutas fijas.
$entorno = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$actual  = $entorno.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
$resto   = @($actual -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $carpeta })

if ($Desinstalar) {
    $nuevo   = $resto
    $mensaje = "aKill se quito del PATH. Ya puedes borrar esta carpeta."
}
else {
    $nuevo   = $resto + $carpeta
    $mensaje = "aKill instalado. Abre una terminal NUEVA y escribe: aKill -help"
    # Quita la marca de "descargado de Internet", que bloquearia aKill.ps1 en PowerShell.
    Get-ChildItem $carpeta -File | Unblock-File
}
$entorno.SetValue('Path', ($nuevo -join ';'), 'ExpandString')

# Borrar una variable que no existe no cambia nada, pero avisa a Windows de que el
# entorno cambio: asi las terminales que se abran despues ya ven el PATH nuevo.
[Environment]::SetEnvironmentVariable('aKillInstalador', $null, 'User')

Write-Host $mensaje -ForegroundColor Green
exit 0
