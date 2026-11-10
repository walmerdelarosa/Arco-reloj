"""Arco: reloj de progreso siempre visible (Python + Qt Quick).

Uso:
    python arco.py                 # backend gráfico por defecto (D3D11 en Windows, Metal en macOS)
    python arco.py --backend opengl  # si el fondo transparente se ve negro
    python arco.py --selftest        # carga la interfaz, comprueba que no hay errores de QML y sale
"""
__version__ = "1.4.0"

import argparse
import os
import sys
from pathlib import Path

if sys.version_info >= (3, 15) or sys.version_info < (3, 10):
    sys.exit("Arco necesita Python 3.10-3.14 (PySide6 aun no admite %d.%d). Usa iniciar.bat." % sys.version_info[:2])

from PySide6.QtCore import QCoreApplication, QMetaObject, QObject, QPoint, QRect, QSettings, QTimer, QUrl, Slot, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication, QMessageBox

from arco_sync import SyncService
from arco_ui import Tray, UiPrefs, load_icon

BASE = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
QML_DIR = BASE / "qml"
RUN_KEY = r"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
RUN_KEY_ALL = r"HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run"   # instalación «para todos»
APP_ID = "ArcoReloj"
LOG = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "Arco" / "arco.log"
_messages: list[str] = []


def _log_handler(mode, context, message):
    """Guarda avisos y errores de Qt/QML en arco.log (pythonw no tiene consola)."""
    _messages.append(message)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as f:
            f.write(message + "\n")
    except OSError:
        pass
    if sys.stderr:
        print(message, file=sys.stderr)


class Platform(QObject):
    """Funciones del sistema operativo expuestas a QML (pantallas e inicio automático)."""

    @staticmethod
    def _screen_at(x: int, y: int):
        return QGuiApplication.screenAt(QPoint(x, y)) or QGuiApplication.primaryScreen()

    @Slot(int, int, result=QRect)
    def availableGeometry(self, x: int, y: int) -> QRect:
        """Área útil (sin barra de tareas) de la pantalla que contiene el punto (x, y)."""
        return self._screen_at(x, y).availableGeometry()

    @Slot(int, int, result=QRect)
    def nextScreenGeometry(self, x: int, y: int) -> QRect:
        """Área útil de la pantalla siguiente a la que contiene (x, y)."""
        screens = QGuiApplication.screens()
        cur = self._screen_at(x, y)
        i = screens.index(cur) if cur in screens else 0
        return screens[(i + 1) % len(screens)].availableGeometry()

    @Slot(result=int)
    def screenCount(self) -> int:
        return len(QGuiApplication.screens())

    def _command(self) -> str:
        if getattr(sys, "frozen", False):
            return f'"{sys.executable}"'
        pyw = Path(sys.executable).with_name("pythonw.exe")
        exe = pyw if pyw.exists() else Path(sys.executable)
        return f'"{exe}" "{Path(__file__).resolve()}"'

    @Slot(str)
    def removeSettingsGroup(self, group: str) -> None:
        """Borra los ajustes guardados de un reloj eliminado (p. ej. «reloj_3»)."""
        if group.startswith("reloj_"):
            s = QSettings()
            s.remove(group)
            s.sync()

    @Slot(result=bool)
    def autostartSupported(self) -> bool:
        return sys.platform == "win32"

    @Slot(result=bool)
    def autostartForAll(self) -> bool:
        """True si el instalador activó el inicio automático para todos los usuarios (HKLM)."""
        if sys.platform != "win32":
            return False
        return QSettings(RUN_KEY_ALL, QSettings.NativeFormat).contains(APP_ID)

    @Slot(result=bool)
    def autostartEnabled(self) -> bool:
        if sys.platform != "win32":
            return False
        return self.autostartForAll() or QSettings(RUN_KEY, QSettings.NativeFormat).contains(APP_ID)

    @Slot(bool)
    def setAutostart(self, on: bool) -> None:
        if sys.platform != "win32" or self.autostartForAll():
            return                                  # lo controla el instalador (requiere administrador)
        s = QSettings(RUN_KEY, QSettings.NativeFormat)
        if on:
            s.setValue(APP_ID, self._command())
        else:
            s.remove(APP_ID)


def main() -> int:
    ap = argparse.ArgumentParser(description="Arco – reloj de progreso")
    ap.add_argument("--backend", choices=["d3d11", "d3d12", "opengl", "vulkan", "metal", "software"],
                    help="fuerza el backend gráfico de Qt Quick")
    ap.add_argument("--selftest", action="store_true",
                    help="carga la interfaz y sale con código 1 si QML informa errores (para CI)")
    ap.add_argument("--version", action="version", version=f"Arco {__version__}")
    args, qt_args = ap.parse_known_args()
    if args.backend:
        os.environ["QSG_RHI_BACKEND"] = args.backend
        if args.backend == "software":
            os.environ["QT_QUICK_BACKEND"] = "software"

    QCoreApplication.setOrganizationName("Arco")
    QCoreApplication.setApplicationName("Arco Reloj Selftest" if args.selftest else "Arco Reloj")
    QCoreApplication.setApplicationVersion(__version__)
    QQuickStyle.setStyle("Fusion")
    QQuickWindow.setDefaultAlphaBuffer(True)       # ventanas con fondo transparente

    app = QApplication([sys.argv[0], *qt_args])
    app.setQuitOnLastWindowClosed(False)           # cerrar Ajustes no cierra la app
    app.setWindowIcon(QIcon(str(QML_DIR / "icon.svg")))

    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        LOG.write_text("", encoding="utf-8")
    except OSError:
        pass
    qInstallMessageHandler(_log_handler)

    engine = QQmlApplicationEngine()
    plat = Platform()
    engine.rootContext().setContextProperty("plat", plat)
    engine.rootContext().setContextProperty("appVersion", __version__)
    # Credenciales de Google: junto al programa o en %LOCALAPPDATA%\Arco
    ui = UiPrefs()
    engine.rootContext().setContextProperty("ui", ui)
    tray = Tray(load_icon(QML_DIR / "icon.svg", BASE / "icon.ico"), on_error=_messages.append)
    engine.rootContext().setContextProperty("tray", tray)
    sync = SyncService([BASE, Path(sys.argv[0]).resolve().parent, LOG.parent], ui=ui, enabled=not args.selftest)
    engine.rootContext().setContextProperty("sync", sync)
    engine.load(QUrl.fromLocalFile(str(QML_DIR / "main.qml")))
    if not engine.rootObjects():
        detail = "\n".join(_messages[-15:]) or "Sin detalles."
        QMessageBox.critical(None, "Arco",
                             f"Arco no pudo iniciar / Arco could not start.\n\n{detail}\n\n{LOG}")
        return 1
    if args.selftest:
        # Recorre estilos y ajustes, y deja correr la interfaz para que se evalúen enlaces y temporizadores.
        root = engine.rootObjects()[0]
        def run_selftest():
            if not QMetaObject.invokeMethod(root, "selfTest"):
                _messages.append("selftest-error: no se pudo llamar a selfTest()")
        QTimer.singleShot(400, run_selftest)
        QTimer.singleShot(4000, app.quit)
        app.exec()
        qml_errors = [m for m in _messages if ".qml:" in m or "clocklogic.js:" in m or "selftest-error" in m]
        for m in qml_errors:
            print("QML:", m, file=sys.stderr)
        print("selftest:", "FALLO" if qml_errors else "OK", file=sys.stderr)
        return 1 if qml_errors else 0
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
