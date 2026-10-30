<#
.SYNOPSIS
    aKill 2.1 - Lista y termina procesos de Windows por nombre, patron, antiguedad o consumo.

.DESCRIPTION
    Los filtros son opcionales y se combinan entre si. Sin filtros, lista todo.

.PARAMETER Match
    Subcadena a buscar en la linea de comandos. Admite comodines * y ?.

.PARAMETER Name
    Nombre del ejecutable. La extension .exe es opcional.

.PARAMETER MinAge
    Antiguedad minima en minutos. Solo procesos que lleven al menos ese tiempo vivos.

.PARAMETER ProcId
    Uno o varios PID, separados por coma. Se escribe -PID.

.PARAMETER Top
    Mem o Cpu. Ordena lo encontrado por consumo de memoria o de procesador y se
    queda con los primeros -Count. Cpu mide durante un segundo antes de listar.

.PARAMETER Count
    Cuantos procesos muestra -Top. Por defecto 10.

.PARAMETER Tree
    Incluye todos los descendientes de cada proceso encontrado. Con -Kill, termina
    el arbol completo, los hijos antes que los padres.

.PARAMETER Kill
    Termina los procesos encontrados en lugar de solo listarlos. Pide confirmacion.
    Con -Top, pregunta que PID de la lista terminar.

.PARAMETER Force
    Con -Kill, no pide confirmacion.

.EXAMPLE
    aKill
    Lista todos los procesos.

.EXAMPLE
    aKill -Name chrome
    Lista las instancias de chrome.exe.

.EXAMPLE
    aKill -Match "mi_script" -MinAge 30 -Kill
    Termina los procesos con "mi_script" en su linea de comandos que lleven
    mas de 30 minutos ejecutandose.

.EXAMPLE
    aKill -Top Mem -Kill -Tree
    Muestra los 10 procesos que mas memoria consumen, pregunta cuales terminar
    y los termina junto con todos sus descendientes.

.EXAMPLE
    aKill -PID 1234 -Kill -Tree
    Termina el proceso 1234 y todo su arbol.

.NOTES
    Sin permisos de administrador, Windows oculta la linea de comandos de los
    procesos de otros usuarios. -Match solo puede filtrar los que si la exponen.
#>
[CmdletBinding()]
param(
    [string]   $Match,
    [string]   $Name,
    [int]      $MinAge,
    # Como texto: desde aKill.cmd "1,2" llega como una sola cadena, no como int[].
    # Solo alias: $PID es una variable automatica de solo lectura.
    [Alias('PID')]
    [string[]] $ProcId,
    [ValidateSet('Mem', 'Cpu')]
    [string]   $Top,
    [int]      $Count = 10,
    [switch]   $Tree,
    [switch]   $Kill,
    [switch]   $Force,
    [switch]   $Help
)

if ($Help -or ($PSBoundParameters.Count -eq 0 -and $MyInvocation.Line -match '\s(/\?|-\?)')) {
    @"
aKill 2.1 - lista y termina procesos de Windows.

  aKill [-Name <programa>] [-Match <patron>] [-MinAge <minutos>] [-PID <pid,...>]
        [-Top Mem|Cpu [-Count <n>]] [-Tree] [-Kill] [-Force]

  -Name    nombre del ejecutable; la extension .exe es opcional
  -Match   subcadena de la linea de comandos; admite comodines * y ?
  -MinAge  antiguedad minima en minutos
  -PID     uno o varios PID separados por coma
  -Top     Mem o Cpu: los que mas memoria o procesador consumen
           (Cpu mide durante un segundo antes de listar)
  -Count   cuantos muestra -Top; por defecto 10
  -Tree    incluye los descendientes; con -Kill termina el arbol completo
  -Kill    termina lo encontrado en vez de solo listarlo (pide confirmacion;
           con -Top pregunta que PID de la lista terminar)
  -Force   con -Kill, no pregunta

Los filtros son opcionales y se combinan entre si. Sin filtros, lista todo.

Ejemplos:
  aKill -Top Mem                  los 10 que mas memoria consumen
  aKill -Top Cpu -Count 5         los 5 que mas procesador consumen
  aKill -Top Mem -Kill -Tree      elegir de la lista y terminar en arbol
  aKill -PID 1234 -Kill -Tree     terminar el 1234 y todos sus descendientes

Codigos de salida:  0 correcto   1 sin coincidencias   2 fallo al terminar

Los procesos criticos del sistema y la propia sesion nunca se terminan.
Sin permisos de administrador, Windows oculta la linea de comandos de los
procesos de otros usuarios, y -Match no puede filtrarlos.
"@ | Write-Host
    exit 0
}

# Terminar cualquiera de estos deja el sistema inestable o provoca un pantallazo azul.
$Protegidos = @(
    'System Idle Process', 'System', 'Secure System', 'Registry', 'Memory Compression',
    'smss.exe', 'csrss.exe', 'wininit.exe', 'winlogon.exe',
    'services.exe', 'lsass.exe', 'fontdrvhost.exe'
)

function Format-Edad {
    param([TimeSpan] $Span)
    if     ($Span.TotalDays    -ge 1) { '{0}d {1}h' -f [int]$Span.TotalDays, $Span.Hours }
    elseif ($Span.TotalHours   -ge 1) { '{0}h {1}m' -f [int]$Span.TotalHours, $Span.Minutes }
    elseif ($Span.TotalMinutes -ge 1) { '{0}m'      -f [int]$Span.TotalMinutes }
    else                              { '{0}s'      -f [int]$Span.TotalSeconds }
}

# Tiempo de procesador acumulado por PID, en ticks de 100 ns. Pedir solo estas
# propiedades evita el coste de resolver CommandLine.
function Get-TiempoCpu {
    $t = @{}
    Get-CimInstance Win32_Process -Property ProcessId, KernelModeTime, UserModeTime | ForEach-Object {
        $t[$_.ProcessId] = [double]$_.KernelModeTime + [double]$_.UserModeTime
    }
    $t
}

$pids = @($ProcId | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
if ($pids -notmatch '^\d+$') {
    Write-Host "-PID solo admite numeros de PID." -ForegroundColor Red
    exit 1
}

# El uso de procesador es una tasa, no un valor: hacen falta dos muestras.
if ($Top -eq 'Cpu') {
    $antes = Get-TiempoCpu
    $reloj = [Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds 1000
    $despues = Get-TiempoCpu
    $ticksTotales = $reloj.Elapsed.Ticks * [Environment]::ProcessorCount
}

$ahora = Get-Date
$todos = @(Get-CimInstance Win32_Process -ErrorAction Stop)

if ($Top -eq 'Cpu') {
    foreach ($p in $todos) {
        $cpu = 0
        if ($antes.ContainsKey($p.ProcessId) -and $despues.ContainsKey($p.ProcessId)) {
            $delta = $despues[$p.ProcessId] - $antes[$p.ProcessId]
            if ($delta -gt 0) { $cpu = [math]::Round(100 * $delta / $ticksTotales, 1) }
        }
        Add-Member -InputObject $p -NotePropertyName Cpu -NotePropertyValue $cpu
    }
}

# Parentesco. Windows reutiliza los PID, asi que un "padre" creado despues que
# su hijo es en realidad otro proceso que heredo el numero.
$porId = @{}; $padreDe = @{}; $hijosDe = @{}
foreach ($p in $todos) { $porId[$p.ProcessId] = $p }
foreach ($p in $todos) {
    $padre = $porId[$p.ParentProcessId]
    if ($padre -and $padre.ProcessId -ne $p.ProcessId -and $p.CreationDate -ge $padre.CreationDate) {
        $padreDe[$p.ProcessId] = $padre.ProcessId
        $hijosDe[$padre.ProcessId] += @($p)
    }
}

function Get-Ancestros {
    param($ProcessId)
    $vistos = @{}
    while ($padreDe.ContainsKey($ProcessId) -and -not $vistos[$ProcessId]) {
        $vistos[$ProcessId] = $true
        $ProcessId = $padreDe[$ProcessId]
        $ProcessId
    }
}

# Devuelve las raices con todos sus descendientes, en preorden y con su Nivel.
# Una raiz que cuelga de otra raiz sale anidada bajo ella, no repetida.
function Get-Arbol {
    param($Raices)
    $idsRaiz = @($Raices | ForEach-Object { $_.ProcessId })
    $pila = New-Object System.Collections.Stack
    $cimas = @($Raices | Where-Object { -not (@(Get-Ancestros $_.ProcessId) | Where-Object { $_ -in $idsRaiz }) })
    [array]::Reverse($cimas)
    foreach ($r in $cimas) { $pila.Push(@($r, 0)) }
    $vistos = @{}
    while ($pila.Count) {
        $p, $nivel = $pila.Pop()
        if ($vistos[$p.ProcessId]) { continue }
        $vistos[$p.ProcessId] = $true
        Add-Member -InputObject $p -NotePropertyName Nivel -NotePropertyValue $nivel -Force
        $p
        $hijos = @($hijosDe[$p.ProcessId] | Where-Object { $_ })
        [array]::Reverse($hijos)
        foreach ($h in $hijos) { $pila.Push(@($h, ($nivel + 1))) }
    }
}

# Cada filtro solo actua si se paso el parametro correspondiente.
$procesos = @($todos | Where-Object {
    ($(if ($Name)   { $_.Name -eq $Name -or $_.Name -eq "$Name.exe" } else { $true })) -and
    ($(if ($Match)  { $_.CommandLine -like "*$Match*" }               else { $true })) -and
    ($(if ($MinAge) { $_.CreationDate -le $ahora.AddMinutes(-$MinAge) } else { $true })) -and
    ($(if ($pids)   { "$($_.ProcessId)" -in $pids }                   else { $true }))
})

if ($Top) {
    # El PID 0 no es un proceso: su "consumo" es el tiempo que el procesador pasa ocioso.
    $metrica  = if ($Top -eq 'Cpu') { 'Cpu' } else { 'WorkingSetSize' }
    $procesos = @($procesos | Where-Object { $_.ProcessId -ne 0 } |
        Sort-Object $metrica -Descending | Select-Object -First $Count)
}
else {
    $procesos = @($procesos | Sort-Object CreationDate)
}

if (-not $procesos) {
    Write-Host "Sin coincidencias." -ForegroundColor DarkGray
    exit 1
}

$mostrados = @(if ($Tree) { Get-Arbol $procesos } else { $procesos })

$columnas = @(
    @{n = 'PID';    e = { $_.ProcessId }},
    @{n = 'PPID';   e = { $_.ParentProcessId }},
    @{n = 'Edad';   e = { Format-Edad ($ahora - $_.CreationDate) }}
)
if ($Top -eq 'Cpu') { $columnas += @{n = 'CPU %'; e = { $_.Cpu }} }
$columnas += @(
    @{n = 'Mem MB'; e = { [int]($_.WorkingSetSize / 1MB) }},
    @{n = 'Nombre'; e = { ('  ' * $_.Nivel) + $_.Name }},
    @{n = 'Comando'; e = {
        if (-not $_.CommandLine) { '<sin acceso>' }
        elseif ($_.CommandLine.Length -gt 70) { $_.CommandLine.Substring(0, 67) + '...' }
        else { $_.CommandLine }
    }}
)

$mostrados | Select-Object $columnas | Format-Table -AutoSize

if (-not $Kill) {
    Write-Host "$($mostrados.Count) proceso(s). Anade -Kill para terminarlos." -ForegroundColor DarkGray
    exit 0
}

# --- A partir de aqui se termina ---

# Un top es para elegir, no para terminar la lista entera: se pregunta cuales.
$elegidos = $procesos
if ($Top -and -not $Force) {
    $r = (Read-Host "PID a terminar, separados por coma (* = todos, Enter = cancelar)").Trim()
    if (-not $r) {
        Write-Host "Cancelado." -ForegroundColor DarkGray
        exit 0
    }
    if ($r -ne '*') {
        $pedidos  = @($r -split '[,\s]+' | Where-Object { $_ })
        $elegidos = @($mostrados | Where-Object { "$($_.ProcessId)" -in $pedidos })
        if (-not $elegidos) {
            Write-Host "Ningun PID de los indicados esta en la lista." -ForegroundColor Yellow
            exit 1
        }
    }
}

$directos   = @($elegidos | ForEach-Object { $_.ProcessId })
$candidatos = if ($Tree) { @(Get-Arbol $elegidos) } else { $elegidos }

$criticos = @($candidatos | Where-Object { $_.Name -in $Protegidos -or $_.ProcessId -le 4 })
if ($criticos) {
    Write-Host "Se excluyen $($criticos.Count) proceso(s) criticos del sistema: $(($criticos.Name | Sort-Object -Unique) -join ', ')" -ForegroundColor Yellow
}

# Nunca terminar la propia sesion ni el proceso que la lanzo. Si ademas se llego
# a la sesion bajando por un arbol, se respeta toda su cadena de ancestros.
$cadena    = @($PID) + @(Get-Ancestros ([uint32]$PID))
$propios   = @($PID, $porId[[uint32]$PID].ParentProcessId)
$objetivos = @($candidatos | Where-Object {
    $_.Name -notin $Protegidos -and $_.ProcessId -gt 4 -and $_.ProcessId -notin $propios -and
    -not ($_.ProcessId -in $cadena -and $_.ProcessId -notin $directos)
})

if (-not $objetivos) {
    Write-Host "No queda nada que terminar tras excluir procesos protegidos." -ForegroundColor Yellow
    exit 1
}

if (-not $Force -and -not $Top) {
    $r = Read-Host "Terminar $($objetivos.Count) proceso(s)? [s/N]"
    if ($r -notmatch '^(s|si|sí|y|yes)$') {
        Write-Host "Cancelado." -ForegroundColor DarkGray
        exit 0
    }
}

# En arbol, los hijos antes que los padres: asi ninguno queda huerfano a medias.
if ($Tree) { [array]::Reverse($objetivos) }

$ok = 0; $fallos = 0
foreach ($p in $objetivos) {
    try {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
        Write-Host ("  terminado  {0,6}  {1}" -f $p.ProcessId, $p.Name) -ForegroundColor Green
        $ok++
    }
    catch {
        # Al caer un hijo, otros procesos del arbol pueden salir por su cuenta.
        if (-not (Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue)) {
            Write-Host ("  ya no esta {0,6}  {1}" -f $p.ProcessId, $p.Name) -ForegroundColor DarkGray
            $ok++
        }
        else {
            Write-Host ("  ERROR      {0,6}  {1} - {2}" -f $p.ProcessId, $p.Name, $_.Exception.Message) -ForegroundColor Red
            $fallos++
        }
    }
}

Write-Host "$ok terminado(s), $fallos con error."
exit $(if ($fallos) { 2 } else { 0 })
