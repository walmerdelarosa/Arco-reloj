"""Preferencias de interfaz (idioma y tema) y menús nativos de Windows.

Los menús se construyen con QMenu (Qt Widgets) a partir de una lista que envía QML:

    [{"id": "settings", "text": "Ajustes…"},
     {"separator": True},
     {"text": "Estilo", "items": [{"id": "style:0", "text": "Anillos", "checked": True}, …]}]

Así el menú del icono de la bandeja y el del clic derecho funcionan igual desde el código
y desde el ejecutable empaquetado (no dependen del módulo Qt.labs.platform).
"""
from __future__ import annotations

from PySide6.QtCore import Property, QLocale, QObject, QSettings, Qt, Signal, Slot
from PySide6.QtGui import QAction, QColor, QCursor, QGuiApplication, QIcon, QPainter, QPen, QPixmap
from PySide6.QtWidgets import QMenu, QSystemTrayIcon


class UiPrefs(QObject):
    """Idioma ("es" / "en") y tema ("system" / "light" / "dark"), comunes a todos los relojes."""

    changed = Signal()

    def __init__(self):
        super().__init__()
        s = QSettings()
        default_lang = "es" if QLocale.system().name().lower().startswith("es") else "en"
        self._lang = str(s.value("ui/lang", default_lang))
        if self._lang not in ("es", "en"):
            self._lang = default_lang
        self._theme = str(s.value("ui/theme", "system"))
        hints = QGuiApplication.styleHints()
        if hasattr(hints, "colorSchemeChanged"):
            hints.colorSchemeChanged.connect(lambda *_: self.changed.emit())

    def _system_dark(self) -> bool:
        hints = QGuiApplication.styleHints()
        try:
            return hints.colorScheme() == Qt.ColorScheme.Dark
        except AttributeError:
            return True

    def _g_lang(self): return self._lang
    def _g_theme(self): return self._theme
    def _g_dark(self): return self._theme == "dark" or (self._theme == "system" and self._system_dark())

    lang = Property(str, _g_lang, notify=changed)
    theme = Property(str, _g_theme, notify=changed)
    dark = Property(bool, _g_dark, notify=changed)

    def tr(self, es: str, en: str) -> str:
        return en if self._lang == "en" else es

    @Slot(str)
    def setLang(self, lang: str) -> None:
        if lang in ("es", "en") and lang != self._lang:
            self._lang = lang
            QSettings().setValue("ui/lang", lang)
            self.changed.emit()

    @Slot(str)
    def setTheme(self, theme: str) -> None:
        if theme in ("system", "light", "dark") and theme != self._theme:
            self._theme = theme
            QSettings().setValue("ui/theme", theme)
            self.changed.emit()


def _fill(menu: QMenu, items) -> None:
    for it in items or []:
        if not isinstance(it, dict):
            continue
        if it.get("separator"):
            menu.addSeparator()
            continue
        if "items" in it:
            sub = menu.addMenu(str(it.get("text", "")))
            sub.setEnabled(bool(it.get("enabled", True)))
            _fill(sub, it["items"])
            continue
        act: QAction = menu.addAction(str(it.get("text", "")))
        act.setData(str(it.get("id", "")))
        if "checked" in it:
            act.setCheckable(True)
            act.setChecked(bool(it["checked"]))
        act.setEnabled(bool(it.get("enabled", True)))


def _painted_icon() -> QIcon:
    """Icono de respaldo dibujado (tres arcos), por si no se puede cargar el archivo."""
    pm = QPixmap(64, 64)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    for i, (col, span) in enumerate([("#8B5CF6", 300), ("#10B981", 220), ("#EF4444", 130)]):
        pen = QPen(QColor(col), 7, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap)
        p.setPen(pen)
        r = 28 - i * 9
        p.drawArc(32 - r, 32 - r, 2 * r, 2 * r, 90 * 16, -span * 16)
    p.end()
    return QIcon(pm)


def load_icon(*paths) -> QIcon:
    for path in paths:
        icon = QIcon(str(path))
        if not icon.isNull() and icon.availableSizes():
            return icon
        if not icon.isNull() and not icon.pixmap(32, 32).isNull():
            return icon
    return _painted_icon()


class Tray(QObject):
    """Icono de la bandeja con menú nativo, y menús emergentes para los relojes."""

    clicked = Signal()                                    # clic izquierdo en el icono
    menuRequested = Signal()                              # QML responde llamando a setItems()
    triggered = Signal(str, arguments=["id"])             # opción elegida en el menú de la bandeja

    def __init__(self, icon: QIcon, on_error=None):
        super().__init__()
        self._items: list = []
        self._on_error = on_error
        self._menu = QMenu()
        self._menu.aboutToShow.connect(self._rebuild)
        self._menu.triggered.connect(lambda a: self.triggered.emit(str(a.data() or "")))
        self._icon = QSystemTrayIcon(icon)
        self._icon.setContextMenu(self._menu)
        self._icon.activated.connect(self._activated)
        self._icon.setToolTip("Arco")
        self._icon.show()

    def _activated(self, reason) -> None:
        if reason in (QSystemTrayIcon.ActivationReason.Trigger, QSystemTrayIcon.ActivationReason.DoubleClick):
            self.clicked.emit()

    def _rebuild(self) -> None:
        self.menuRequested.emit()
        self._menu.clear()
        _fill(self._menu, self._items)

    @Slot("QVariantList")
    def setItems(self, items) -> None:
        self._items = list(items or [])

    @Slot(str)
    def setToolTip(self, text: str) -> None:
        self._icon.setToolTip(text)

    @Slot("QVariantList", result=str)
    def popup(self, items) -> str:
        """Muestra un menú en la posición del ratón y devuelve el id elegido ("" si se cierra)."""
        menu = QMenu()
        _fill(menu, items)
        act = menu.exec(QCursor.pos())
        return str(act.data() or "") if act else ""

    @Slot("QVariantList", result=int)
    def check(self, items) -> int:
        """Construye el menú sin mostrarlo (para --selftest). Devuelve el número de opciones."""
        try:
            menu = QMenu()
            _fill(menu, items)
            return len(menu.actions())
        except Exception as e:  # noqa: BLE001
            if self._on_error:
                self._on_error(f"selftest-error: menú: {e}")
            return -1
