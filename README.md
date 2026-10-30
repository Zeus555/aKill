# aKill

Busca y cierra procesos de Windows desde la terminal. Puedes encontrarlos por nombre, por texto en su línea de comandos, por el tiempo que llevan abiertos o por lo que consumen.

```text
D:\>aKill -Name notepad

 PID  PPID Edad   Mem MB Nombre      Comando
 ---  ---- ----   ------ ------      -------
8412  5120 1h 12m     24 notepad.exe "C:\Windows\system32\notepad.exe"
9036  5120 3m         19 notepad.exe "C:\Windows\system32\notepad.exe" notas.txt

2 proceso(s). Anade -Kill para terminarlos.
```

Mientras no escribas `-Kill`, aKill solo muestra información: no cierra nada.

## Instalación

Necesitas Windows 10 u 11 (probado en Windows 11). No hay que instalar nada más.

1. Descarga [aKill en ZIP](https://github.com/Zeus555/aKill/archive/refs/heads/main.zip).
2. Descomprímelo en la carpeta donde se vaya a quedar, por ejemplo `C:\Herramientas\aKill`.
3. Haz doble clic en `instalar.cmd`. Si Windows avisa de que el archivo viene de Internet, confirma que quieres ejecutarlo.
4. Abre una terminal **nueva** y comprueba que responde:

   ```bat
   aKill -help
   ```

El instalador solo agrega la carpeta `Script` al PATH de tu usuario, sin pedir permisos de administrador. No copia archivos a otro sitio, así que la carpeta no se debe mover ni borrar después.

> **¿Usas PowerShell?** Si ves un error que dice que la ejecución de scripts está deshabilitada, escribe `aKill.cmd` en lugar de `aKill`. Funciona igual. En la terminal clásica `cmd` no hace falta.

¿Prefieres Git?

```bat
git clone https://github.com/Zeus555/aKill.git
aKill\instalar.cmd
```

## Uso

| Quiero... | Escribo |
|---|---|
| Ver todos los procesos | `aKill` |
| Buscar un programa | `aKill -Name chrome` |
| Buscar un texto en la línea de comandos | `aKill -Match "mi_script"` |
| Ver los que llevan 30 minutos o más abiertos | `aKill -MinAge 30` |
| Ver los 10 que más memoria consumen | `aKill -Top Mem` |
| Ver los 5 que más procesador consumen | `aKill -Top Cpu -Count 5` |
| Ver un proceso concreto | `aKill -PID 1234` |
| Cerrar un programa | `aKill -Name chrome -Kill` |
| Cerrar un proceso y todos sus hijos | `aKill -PID 1234 -Kill -Tree` |
| Elegir de una lista cuál cerrar | `aKill -Top Mem -Kill` |

Los filtros se pueden combinar. Este comando cierra las copias de `python` que llevan más de una hora abiertas y tienen `mi_script` en su línea de comandos:

```bat
aKill -Name python -Match "mi_script" -MinAge 60 -Kill
```

Para ver la ayuda en cualquier momento, escribe `aKill -help`.

## ¿Es seguro?

- Sin `-Kill` no se cierra nada.
- Con `-Kill`, aKill enseña lo que encontró y pregunta antes de cerrar. Solo `-Force` se salta la pregunta.
- Los procesos críticos de Windows, como `lsass.exe` o `csrss.exe`, nunca se cierran.

## Actualizar y desinstalar

**Actualizar:** descarga el ZIP de nuevo y sustituye los archivos en la misma carpeta. Si lo instalaste con Git, usa `git pull`.

**Desinstalar:** haz doble clic en `desinstalar.cmd` y después borra la carpeta.

## Más información

La [guía completa](docs/GUIA.md) explica cada parámetro, cómo cerrar procesos paso a paso, cómo usar aKill en tus scripts y qué hacer si algo falla.
