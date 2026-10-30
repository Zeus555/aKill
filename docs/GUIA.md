# Guía de aKill

- [Cómo funciona](#cómo-funciona)
- [Parámetros](#parámetros)
- [Cómo leer la lista](#cómo-leer-la-lista)
- [Cerrar procesos](#cerrar-procesos)
- [Qué procesos están protegidos](#qué-procesos-están-protegidos)
- [Usar aKill en tus scripts](#usar-akill-en-tus-scripts)
- [Problemas frecuentes](#problemas-frecuentes)

## Cómo funciona

1. Sin parámetros, aKill lista todos los procesos.
2. Cada filtro reduce la lista. Si usas varios, el proceso tiene que cumplirlos todos.
3. Con `-Kill`, aKill cierra lo que encontró, después de preguntarte.

Si no estás seguro de qué va a cerrar un comando, ejecútalo primero sin `-Kill` y mira la lista.

## Parámetros

| Parámetro | Para qué sirve | Ejemplo |
|---|---|---|
| `-Name` | Nombre exacto del programa. La extensión `.exe` es opcional y no importan las mayúsculas. | `aKill -Name chrome` |
| `-Match` | Texto que aparece en cualquier parte de la línea de comandos. Admite los comodines `*` y `?`. | `aKill -Match "mi_script"` |
| `-MinAge` | Solo los procesos que llevan al menos esos minutos abiertos. | `aKill -MinAge 30` |
| `-PID` | Uno o varios números de proceso. Si son varios, sepáralos con comas y ponlos entre comillas. | `aKill -PID "1234,5678"` |
| `-Top` | `Mem` o `Cpu`: ordena por consumo de memoria o de procesador y muestra solo los primeros. | `aKill -Top Mem` |
| `-Count` | Cuántos muestra `-Top`. Por defecto, 10. | `aKill -Top Cpu -Count 5` |
| `-Tree` | Incluye todos los procesos hijos de lo encontrado. | `aKill -PID 1234 -Tree` |
| `-Kill` | Cierra lo encontrado en vez de solo mostrarlo. | `aKill -Name chrome -Kill` |
| `-Force` | Con `-Kill`, no pregunta. | `aKill -Name chrome -Kill -Force` |
| `-Help` | Muestra la ayuda. `aKill /?` hace lo mismo. | `aKill -help` |

`-Name` busca el nombre completo: `-Name chrome` encuentra `chrome.exe`, pero no `chromedriver.exe`. Para una búsqueda parcial usa `-Match`, por ejemplo `aKill -Match "chromedriver"`.

## Cómo leer la lista

| Columna | Significado |
|---|---|
| `PID` | Número del proceso. Es el que usas con `-PID`. |
| `PPID` | Número del proceso que lo abrió (su padre). |
| `Edad` | Tiempo que lleva abierto, por ejemplo `3m`, `1h 12m` o `2d 4h`. |
| `CPU %` | Uso del procesador entre todos los núcleos. Solo aparece con `-Top Cpu`. |
| `Mem MB` | Memoria que está usando. |
| `Nombre` | Nombre del programa. Con `-Tree`, los hijos aparecen con sangría debajo de su padre. |
| `Comando` | Línea de comandos con la que se abrió, recortada a 70 caracteres. `<sin acceso>` significa que Windows no permite verla ([más abajo](#en-comando-aparece-sin-acceso-o--match-no-encuentra-un-proceso)). |

La lista va del proceso más antiguo al más reciente. Con `-Top`, va del que más consume al que menos.

## Cerrar procesos

### Con filtros

aKill muestra la lista y pregunta. Responde `s` para cerrar, o pulsa Enter para cancelar.

```text
D:\>aKill -Name notepad -Kill

 PID  PPID Edad Mem MB Nombre      Comando
 ---  ---- ---- ------ ------      -------
9036  5120 3m       19 notepad.exe "C:\Windows\system32\notepad.exe" notas.txt

Terminar 1 proceso(s)? [s/N]: s
  terminado    9036  notepad.exe
1 terminado(s), 0 con error.
```

### Eligiendo de una lista

Con `-Top`, aKill te deja elegir qué cerrar. Escribe uno o varios PID separados por comas, `*` para cerrar todos los de la lista, o pulsa Enter para cancelar.

```text
D:\>aKill -Top Mem -Kill
...
PID a terminar, separados por coma (* = todos, Enter = cancelar): 1234,5678
```

### Con todos sus hijos

Algunos programas abren muchos procesos. Con `-Tree` se cierran todos, primero los hijos y después el padre.

```bat
aKill -PID 1234 -Kill -Tree
```

### Sin preguntar

`-Force` cierra sin confirmación. Úsalo con cuidado, sobre todo con `-Top`: `aKill -Top Mem -Kill -Force` cierra **todos** los procesos de la lista, sin dejarte elegir.

## Qué procesos están protegidos

Cerrar estos procesos dejaría Windows inestable, así que aKill los excluye aunque coincidan con tu búsqueda y aunque uses `-Force`:

`System Idle Process`, `System`, `Secure System`, `Registry`, `Memory Compression`, `smss.exe`, `csrss.exe`, `wininit.exe`, `winlogon.exe`, `services.exe`, `lsass.exe` y `fontdrvhost.exe`.

aKill tampoco se cierra a sí mismo. La terminal desde la que lo ejecutas sí puede cerrarse si tu búsqueda la incluye: por ejemplo, `aKill -Name cmd -Kill` también afecta a la ventana de `cmd` que estás usando.

## Usar aKill en tus scripts

Usa `-Force` para que no se detenga a preguntar, y revisa el código de salida:

| Código | Significado |
|---|---|
| `0` | Todo correcto. También si cancelaste en la pregunta. |
| `1` | No se encontró nada que listar o cerrar, o el valor de `-PID` no es válido. |
| `2` | Algún proceso no se pudo cerrar. |

Dentro de un archivo `.bat` o `.cmd`, escribe `call aKill ...`. Sin `call`, tu script termina cuando acaba aKill y no ejecuta las líneas siguientes:

```bat
@echo off
call aKill -Name miapp -MinAge 60 -Kill -Force
if %ERRORLEVEL%==2 echo No se pudieron cerrar todos los procesos.
```

## Problemas frecuentes

### "aKill no se reconoce como un comando"

Las terminales que ya estaban abiertas no ven el cambio: abre una nueva. Si sigue igual, ejecuta `instalar.cmd` otra vez desde la carpeta donde se va a quedar aKill.

### "La ejecución de scripts está deshabilitada"

Es la configuración que PowerShell trae por defecto. Tienes dos opciones:

- Escribir `aKill.cmd` en lugar de `aKill`. No cambia nada en tu equipo. Para pasarle varios PID, ponlos entre comillas: `aKill.cmd -PID "1234,5678"`.
- Permitir scripts locales para tu usuario. Solo hay que hacerlo una vez:

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

### En `Comando` aparece `<sin acceso>`, o `-Match` no encuentra un proceso

Sin permisos de administrador, Windows oculta la línea de comandos de los procesos de otros usuarios, y `-Match` no puede buscar en ella. Abre la terminal como administrador y repite el comando.

### Aparece `ERROR` al cerrar un proceso

Normalmente es falta de permisos, por ejemplo con servicios o programas de otro usuario. Abre la terminal como administrador. En este caso aKill termina con el código de salida `2`.

### Dice "Sin coincidencias" y el programa está abierto

`-Name` necesita el nombre exacto del ejecutable, que no siempre coincide con el de la aplicación. Busca el nombre real con `aKill -Match "parte_del_nombre"`.

### `-Top Cpu` tarda un poco

Es normal. Mide el uso del procesador durante un segundo antes de mostrar la lista.
