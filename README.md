# Arco

Reloj de escritorio que muestra cuánto ha pasado del año, el mes, la semana, el día, la hora y el minuto. Queda siempre visible, con fondo transparente, y casi no consume recursos.

![Estilos de Arco](vista_previa_estilos.png)

## Funciones

- Anillos para año, mes, semana, día (o tu jornada laboral), hora y minuto
- 8 estilos: anillos, segmentos, fino, neón, bloque, barras horizontales, barras verticales y analógico
- Un reloj por monitor, cada uno con su configuración
- Hora y fecha con [formato personalizable](docs/formatos.md)
- Color y transparencia por elemento
- Sincronización de la configuración entre equipos con tu cuenta de Google o una carpeta sincronizada
- Protección contra burn-in para pantallas OLED
- Inicio con Windows

## Descarga

Descarga el instalador desde [Releases](../../releases/latest). Funciona en Windows 10 y 11, no necesita Python ni permisos de administrador.

Windows puede mostrar un aviso de SmartScreen porque el instalador no está firmado: **Más información → Ejecutar de todas formas**.

## Uso

| | |
|---|---|
| Mover | Arrastrar |
| Tamaño | Rueda del ratón |
| Opacidad | Mayús + rueda |
| Ajustes | Doble clic |
| Más opciones | Clic derecho |
| Mostrar u ocultar | Clic en el icono de la bandeja |

Para añadir un reloj en otro monitor: clic derecho → **Nuevo reloj para otro monitor**.

## Sincronización

En **Ajustes → Sincronización** elige una de estas opciones:

- **Cuenta de Google**: Arco guarda la configuración en una carpeta oculta de tu Drive y no puede ver tus otros archivos.
- **Carpeta sincronizada**: cualquier carpeta de Google Drive para escritorio, OneDrive o Dropbox.

La posición de los relojes no se sincroniza, porque depende de los monitores de cada equipo.

## Desde el código

Requiere Python 3.10–3.14.

```bash
pip install -r requirements.txt
python arco.py
```

En Windows también puedes usar `iniciar.bat`, que crea el entorno virtual la primera vez. `build_installer.bat` genera el instalador (requiere [Inno Setup 6](https://jrsoftware.org/isinfo.php)).

Pruebas:

```bash
node tests/test_logic.js
python tests/test_sync.py
python arco.py --selftest
```

Para publicar una versión, cambia `__version__` en `arco.py` y sube una etiqueta (`git tag v1.2.0 && git push --tags`). GitHub Actions compila el instalador y lo adjunta al release. Para incluir el inicio de sesión con Google, consulta [docs/google-sync.md](docs/google-sync.md).

## Problemas frecuentes

- **El fondo se ve negro:** inicia con `--backend opengl`.
- **No puedo hacer clic en el reloj:** desactiva «dejar pasar los clics» desde el icono de la bandeja.
- **Errores al iniciar:** revisa `%LOCALAPPDATA%\Arco\arco.log` o usa `depurar.bat`.

## Licencia

MIT
