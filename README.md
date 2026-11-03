# Arco · reloj de progreso siempre visible

Arco es un reloj de escritorio con anillos concéntricos que muestra cuánto ha pasado y cuánto queda del **año, mes, semana, día, hora y minuto**. Sirve para tener siempre a la vista el tiempo que te queda del día o de tu jornada.

![Los cinco estilos de Arco: Anillos, Segmentos, Fino, Neón y Bloque](vista_previa_estilos.png)

*Los cinco estilos de dial. Imagen de referencia; la app real se ve igual con tus colores y ajustes.*

> **Estado:** en pruebas. La versión de Windows se prueba antes de cada entrega.

## Características

- **Anillos independientes:** activa o desactiva Año, Mes, Semana, Día, Hora y Minuto. Cada uno tiene su color.
- **Modo jornada:** el anillo «Día» puede medir solo tu horario de trabajo, por ejemplo de 08:00 a 18:00.
- **Cinco estilos:** Anillos, Segmentos, Fino, Neón y Bloque.
- **Seis paletas** de colores, incluida una pensada para pantallas OLED.
- **Siempre visible, fijar posición y dejar pasar los clics** (con opción para desactivarlo desde la bandeja).
- **Colocación rápida:** centro de la pantalla, esquinas, bordes, paso a otro monitor o coordenadas exactas.
- **Protección contra burn-in:** desplaza el reloj unos píxeles de forma periódica y suave, y puede atenuar las pistas fijas.
- **Ayuda integrada:** cada opción de los ajustes tiene un botón «?», y hay una guía rápida.
- **Bajo consumo:** el dibujo lo hace la GPU y la app no tiene animación continua.

## Instalación en Windows

Necesitas Python 3.10 a 3.14. PySide6, la librería gráfica que usa Arco, todavía no es compatible con Python 3.15.

1. Descarga o clona este repositorio y descomprímelo en una carpeta.
2. Haz doble clic en **`iniciar.bat`**. La primera vez crea un entorno en `.venv` e instala lo necesario; tarda unos minutos.
3. Arco aparece en tu escritorio, en la esquina superior derecha.

Scripts incluidos:

| Archivo | Para qué sirve |
|---|---|
| `iniciar.bat` | Abre Arco sin consola. Úsalo a diario. |
| `depurar.bat` | Abre Arco con consola para ver los errores. |
| `build_windows.bat` | Crea `dist\ArcoReloj\ArcoReloj.exe` para usarlo sin Python. |
| `_preparar.bat` | Prepara el entorno; lo llaman los otros scripts. No hace falta ejecutarlo. |

Si quieres el ejecutable, ejecuta `build_windows.bat`. Para moverlo a otro sitio, copia la carpeta `dist\ArcoReloj` completa, no solo el `.exe`.

### macOS y Linux

```bash
python3.13 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python arco.py
```

## Uso

| Acción | Cómo |
|---|---|
| Mover | Arrastrar el reloj |
| Cambiar tamaño | Rueda del ratón sobre el reloj (90–1800 px) |
| Cambiar opacidad | Mayús + rueda del ratón |
| Abrir ajustes | Doble clic sobre el reloj, o clic derecho → Ajustes… |
| Ver un anillo | Pasa el ratón por encima: el centro muestra su nombre, su porcentaje y el tiempo que queda |
| Ocultar o mostrar | Clic en el icono de la bandeja (junto al reloj de Windows) |
| Colocar el reloj | Clic derecho → Posición, o Ajustes → Posición |
| Ver la ayuda | Botones «?» en Ajustes, «Guía rápida», o clic derecho → Ayuda |

## Ajustes

- **Anillos:** qué unidades mostrar, su color y la paleta general.
- **Estilo y tamaño:** estilo visual, tamaño, opacidad, grosor, intensidad de las pistas y disco de fondo.
- **Posición:** cuadrícula 3×3, centrar, pasar de monitor, mover paso a paso y coordenadas X e Y.
- **Texto central:** hora, segundos, formato de 12 h y movimiento suave del segundero.
- **Día o jornada:** horario de inicio y fin para el anillo «Día».
- **Ventana:** siempre visible, fijar posición y tamaño, dejar pasar los clics e iniciar con Windows.
- **Protección contra burn-in:** radio y frecuencia del desplazamiento.

Los ajustes y la posición se guardan automáticamente.

## Consumo de recursos

- La GPU dibuja los arcos mediante Qt Quick (Direct3D 11 en Windows, Metal en macOS, OpenGL o Vulkan).
- No hay bucle de animación. La app se actualiza una vez por segundo, o una vez por minuto si apagas el anillo «Minuto» y los segundos.
- Oculta, no hace ningún trabajo.
- El «movimiento suave» es opcional: redibuja unas 30 veces por segundo y usa algo más de GPU.
- La memoria depende de Qt. Es del orden de 60 a 120 MB, y el uso de CPU en reposo es muy bajo.

## Solución de problemas

- **El fondo se ve negro en vez de transparente:** inicia con `python arco.py --backend opengl`. También puedes probar `--backend d3d12`.
- **Activaste «dejar pasar los clics» y no puedes tocar el reloj:** desactívalo desde el icono de la bandeja.
- **No aparece sobre juegos a pantalla completa exclusiva:** es una limitación del sistema operativo. En modo ventana sin bordes sí funciona.
- **Errores al iniciar:** ejecuta `depurar.bat`. El registro completo queda en `%LOCALAPPDATA%\Arco\arco.log`.

## Estructura del proyecto

```
arco.py                 lanzador (Python/PySide6), inicio automático y funciones del sistema
qml/main.qml            ventana, actualización, anti burn-in e interacción
qml/Ring.qml            un anillo, con sus cinco estilos
qml/SettingsWindow.qml  ventana de ajustes y guía rápida
qml/AppMenu.qml         menú de la bandeja y del clic derecho
qml/clocklogic.js       cálculos de tiempo y paletas
tests/test_logic.js     pruebas de los cálculos de tiempo (Node.js)
requirements.txt        dependencias (PySide6)
```

Para ejecutar las pruebas de la lógica de tiempo:

```bash
node tests/test_logic.js
```

## Licencia

MIT
