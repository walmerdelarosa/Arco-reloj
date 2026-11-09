import QtQuick
import QtQml.Models
import Qt.labs.platform as Platform
import "clocklogic.js" as Logic

// Menú nativo del clic derecho sobre un reloj.
Platform.Menu {
    id: menu
    property var conf
    property var clock
    property var settingsWindow
    property var app

    function rebind(item, getter) { item.checked = Qt.binding(getter) }

    Platform.MenuItem {
        text: "Ocultar este reloj"
        onTriggered: menu.clock.visible = false
    }
    Platform.MenuItem {
        text: "Ajustes…"
        onTriggered: menu.settingsWindow.openIt()
    }
    Platform.MenuItem {
        text: "Ayuda: ¿qué hace cada opción?"
        onTriggered: menu.settingsWindow.openHelp()
    }
    Platform.MenuSeparator {}
    Platform.MenuItem {
        text: "Nuevo reloj para otro monitor (copia este)"
        onTriggered: menu.app.addClock(menu.clock)
    }
    Platform.MenuItem {
        text: "Cerrar este reloj"
        enabled: menu.app && menu.app.count > 1
        onTriggered: menu.app.removeClock(menu.clock)
    }
    Platform.MenuSeparator {}
    Platform.Menu {
        title: "Posición"
        Platform.MenuItem { text: "Centrar en la pantalla"; onTriggered: menu.clock.centerOnScreen() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Arriba a la izquierda";  onTriggered: menu.clock.place(0, 0) }
        Platform.MenuItem { text: "Arriba al centro";       onTriggered: menu.clock.place(0.5, 0) }
        Platform.MenuItem { text: "Arriba a la derecha";    onTriggered: menu.clock.place(1, 0) }
        Platform.MenuItem { text: "Centro a la izquierda";  onTriggered: menu.clock.place(0, 0.5) }
        Platform.MenuItem { text: "Centro a la derecha";    onTriggered: menu.clock.place(1, 0.5) }
        Platform.MenuItem { text: "Abajo a la izquierda";   onTriggered: menu.clock.place(0, 1) }
        Platform.MenuItem { text: "Abajo al centro";        onTriggered: menu.clock.place(0.5, 1) }
        Platform.MenuItem { text: "Abajo a la derecha";     onTriggered: menu.clock.place(1, 1) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Pasar al siguiente monitor"; onTriggered: menu.clock.moveToNextScreen() }
    }
    Platform.MenuSeparator {}
    Platform.MenuItem {
        id: miTop
        text: "Siempre visible"
        checkable: true
        checked: menu.conf.onTop
        onTriggered: { menu.conf.onTop = checked; menu.rebind(miTop, () => menu.conf.onTop) }
    }
    Platform.MenuItem {
        id: miLock
        text: "Fijar posición"
        checkable: true
        checked: menu.conf.locked
        onTriggered: { menu.conf.locked = checked; menu.rebind(miLock, () => menu.conf.locked) }
    }
    Platform.MenuItem {
        id: miThrough
        text: "Dejar pasar los clics (desactivar desde aquí)"
        checkable: true
        checked: menu.conf.clickThrough
        onTriggered: { menu.conf.clickThrough = checked; menu.rebind(miThrough, () => menu.conf.clickThrough) }
    }
    Platform.MenuItem {
        id: miBurn
        text: "Anti burn-in"
        checkable: true
        checked: menu.conf.antiBurn
        onTriggered: { menu.conf.antiBurn = checked; menu.rebind(miBurn, () => menu.conf.antiBurn) }
    }
    Platform.Menu {
        id: styleMenu
        title: "Estilo"
        Platform.MenuItemGroup { id: styleGroup; exclusive: true }
        Instantiator {
            model: Logic.styles
            delegate: Platform.MenuItem {
                required property int index
                required property string modelData
                text: modelData
                checkable: true
                group: styleGroup
                checked: !!menu.conf && menu.conf.style === index
                onTriggered: if (menu.conf) menu.conf.style = index
            }
            onObjectAdded: (index, object) => styleMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => styleMenu.removeItem(object)
        }
    }
    Platform.MenuSeparator {}
    Platform.MenuItem {
        text: "Salir"
        onTriggered: Qt.quit()
    }
}
