import QtQuick
import QtQml.Models
import Qt.labs.platform as Platform

// Menú del icono de la bandeja: acciones para todos los relojes.
Platform.Menu {
    id: menu
    property var app
    property var clocks          // Instantiator con las ventanas de los relojes

    Platform.MenuItem {
        text: "Mostrar u ocultar relojes"
        onTriggered: menu.app.setAllVisible(!menu.app.anyVisible())
    }
    Platform.MenuItem {
        text: "Añadir reloj para otro monitor"
        onTriggered: menu.app.addClock(menu.app.primary)
    }
    Platform.Menu {
        id: settingsMenu
        title: "Ajustes"
        Instantiator {
            model: menu.app ? menu.app.count : 0
            delegate: Platform.MenuItem {
                required property int index
                text: "Reloj " + (index + 1) + "…"
                onTriggered: {
                    const w = menu.clocks.objectAt(index)
                    if (w) { w.visible = true; w.settingsWindow.openIt() }
                }
            }
            onObjectAdded: (index, object) => settingsMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => settingsMenu.removeItem(object)
        }
    }
    Platform.MenuItem {
        text: "Volver a recibir clics (quitar «dejar pasar los clics»)"
        onTriggered: menu.app.releaseClickThrough()
    }
    Platform.MenuItem {
        text: "Ayuda: ¿qué hace cada opción?"
        onTriggered: if (menu.app.primary) menu.app.primary.settingsWindow.openHelp()
    }
    Platform.MenuSeparator {}
    Platform.MenuItem {
        text: "Salir"
        onTriggered: Qt.quit()
    }
}
