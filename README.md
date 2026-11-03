# Arco · reloj de progreso siempre visible

Dial de anillos concéntricos que muestra cuánto ha avanzado (y cuánto queda) del **año, mes, semana, día, hora y minuto**. En el centro aparecen la hora y el tiempo restante del día o de la jornada.

## Ejecutar (Windows)

PySide6 funciona con Python 3.10 a 3.14 (todavía no con 3.15). Los scripts lo resuelven solos: buscan una versión compatible con el lanzador `py` o instalan Python 3.13 junto a la que ya tienes, y crean un entorno aislado en `.venv`.

- **Usar la app:** doble clic en `iniciar.bat`. La primera vez tarda unos minutos.
- **Ver errores:** `depurar.bat` abre la app con consola. Los avisos también quedan en `%LOCALAPPDATA%\Arco\arco.log`.
- **Crear el .exe:** `build_windows.bat`. El ejecutable queda en `dist\ArcoReloj\ArcoReloj.exe` (la carpeta `build\` es temporal y su .exe no funciona). Si lo mueves, copia la carpeta `dist\ArcoReloj` completa.

macOS/Linux: `python3.13 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/python arco.py`

## Uso

| Acción | Cómo |
|---|---|
| Mover | Arrastrar el reloj |
| Cambiar tamaño | Rueda del ratón sobre el reloj (90–1800 px) |
| Cambiar opacidad | Mayús + rueda |
| Ajustes | Doble clic, o clic derecho → Ajustes |
| Ver qué es cada anillo | Pasar el ratón por encima: el centro muestra nombre, % y tiempo restante |
| Ocultar/mostrar | Clic en el icono de la bandeja |
| Colocar | Clic derecho → Posición, o Ajustes → Posición (centro, esquinas, bordes, otro monitor, paso a paso, coordenadas) |
| Ayuda | Botones «?» en Ajustes, «Guía rápida», o clic derecho → Ayuda |

## Ajustes disponibles

- **Anillos:** activar o desactivar cada uno (Año, Mes, Semana, Día, Hora, Minuto) y elegir su color. Hay 6 paletas predefinidas.
- **Estilos:** Anillos, Segmentos (un bloque por día, hora o segundo), Fino, Neón y Bloque.
- **Tamaño, opacidad, grosor, intensidad de las pistas y disco de fondo.**
- **Texto central:** hora, segundos, formato 12 h y movimiento suave del segundero.
- **Modo jornada:** el anillo «Día» mide solo tu horario de trabajo (p. ej., 08:00–18:00).
- **Ventana:** siempre visible, fijar posición, dejar pasar los clics e iniciar con Windows.
- **Anti burn-in:** desplazamiento periódico de unos píxeles (pixel shift), con radio e intervalo configurables. Además permite atenuar las pistas fijas.

Los ajustes y la posición se guardan solos.

## Consumo de recursos

- El dibujo lo hace la GPU (Qt Quick con Direct3D 11, Metal, Vulkan u OpenGL). Los arcos se rasterizan con *shaders* (CurveRenderer).
- No hay bucle de animación. La app despierta una vez por segundo, alineada al cambio de segundo, y solo recalcula unos pocos arcos.
- Si apagas el anillo «Minuto» y los segundos, despierta **una vez por minuto**.
- Oculta, no hace ningún trabajo.
- El «movimiento suave» es opcional y es lo único que pide ~30 fps.
- Memoria aproximada: 60–120 MB (el peso del entorno Qt). El uso de CPU en reposo es prácticamente 0 %.

## Solución de problemas

- **El fondo se ve negro en lugar de transparente:** inicia con `python arco.py --backend opengl`. También puedes probar `--backend d3d12`.
- **Activé «dejar pasar los clics» y ya no puedo tocar el reloj:** desactívalo desde el icono de la bandeja.
- **No queda encima de juegos o vídeos en pantalla completa exclusiva:** es una limitación del sistema operativo; en ventana sin bordes sí funciona.
- **macOS:** la app aparece en el Dock; no se superpone a las apps que están en pantalla completa nativa.

## Estructura

```
arco.py            lanzador (Python/PySide6) e inicio automático
qml/main.qml       ventana, lógica de refresco, anti burn-in, interacción
qml/Ring.qml       un anillo (los 5 estilos)
qml/SettingsWindow.qml  ventana de ajustes
qml/AppMenu.qml    menú de bandeja y de clic derecho
qml/clocklogic.js  cálculos de tiempo (probado con Node)
```
