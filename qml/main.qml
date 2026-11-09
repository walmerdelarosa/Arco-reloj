import QtQuick
import QtQml.Models
import QtCore
import Qt.labs.platform as Platform
import "clocklogic.js" as Logic

// Gestor de relojes: crea una ventana ClockWindow por cada reloj guardado
// (por ejemplo, uno por monitor) y mantiene el icono de la bandeja.
Item {
    id: mgr

    Settings {
        id: appCfg
        category: "app"
        property string clockIds: "0"     // identificadores de los relojes abiertos, separados por comas
        property int nextId: 1
    }

    ListModel { id: clockModel }
    readonly property int count: clockModel.count
    property int revision: 0              // cambia cuando se añade o quita un reloj
    property var pendingClone: null

    function saveIds() {
        const ids = []
        for (let i = 0; i < clockModel.count; i++) ids.push(clockModel.get(i).cid)
        appCfg.clockIds = ids.join(",")
        revision++
    }
    function indexOfId(cid) {
        for (let i = 0; i < clockModel.count; i++) if (clockModel.get(i).cid === cid) return i
        return -1
    }
    // Número visible (1, 2, 3…) de un reloj; «rev» solo fuerza a recalcular.
    function numberOf(cid, rev) { return indexOfId(cid) + 1 }
    function clockAt(i) { return clocks.objectAt(i) }

    // El reloj nuevo lee esto al crearse para copiar los ajustes del reloj de origen.
    function takeClone() { const c = pendingClone; pendingClone = null; return c }

    // Añade un reloj con los mismos ajustes que «source» y lo lleva al siguiente monitor.
    function addClock(source, quiet) {
        if (source)
            pendingClone = { values: source.snapshot(), x: source.x, y: source.y }
        const cid = appCfg.nextId
        appCfg.nextId = cid + 1
        clockModel.append({ cid: cid })
        saveIds()
        const w = clockAt(clockModel.count - 1)
        if (w && !quiet) w.settingsWindow.openIt()
        return w
    }

    // Cierra un reloj (nunca el último). Se hace después del clic para no destruir la ventana
    // mientras atiende su propio menú.
    function removeClock(clock) {
        if (clockModel.count <= 1 || !clock) return
        const cid = clock.clockId
        Qt.callLater(function () {
            const i = indexOfId(cid)
            if (i < 0 || clockModel.count <= 1) return
            clockModel.remove(i)
            saveIds()
            if (cid !== 0) { mgr.staleGroups.push("reloj_" + cid); cleanup.restart() }
        })
    }

    // Borra del registro los ajustes de los relojes eliminados, cuando sus ventanas ya no existen.
    property var staleGroups: []
    Timer {
        id: cleanup
        interval: 2000
        onTriggered: {
            mgr.staleGroups.forEach(function (g) { plat.removeSettingsGroup(g) })
            mgr.staleGroups = []
        }
    }

    function anyVisible() {
        for (let i = 0; i < clocks.count; i++) { const w = clocks.objectAt(i); if (w && w.visible) return true }
        return false
    }
    function setAllVisible(v) {
        for (let i = 0; i < clocks.count; i++) { const w = clocks.objectAt(i); if (w) w.visible = v }
        revision++
    }

    function releaseClickThrough() {
        for (let i = 0; i < clocks.count; i++) {
            const w = clocks.objectAt(i)
            if (w) { w.conf.clickThrough = false; w.visible = true }
        }
    }

    // Lo llama «arco.py --selftest»: recorre estilos, páginas de ajustes y la creación de relojes
    // para que cualquier error de QML aparezca en el registro.
    function selfTest() {
        const w = primary
        if (!w) { console.error("selftest-error: sin reloj"); return }
        w.settingsWindow.openIt()
        for (let p = 0; p < w.settingsWindow.pageCount; p++) w.settingsWindow.showPage(p)
        w.conf.showDate = true
        w.conf.showWeek = true
        w.conf.workMode = true
        for (let s = 0; s < Logic.styles.length; s++) {
            w.conf.style = s
            w.updateHover(Qt.point(w.dialW / 2 + 1, w.dialH - w.pad - 2))
            w.updateHover(Qt.point(w.dialW / 2 + w.rOuter * 0.9, w.dialH / 2))
            w.conf.showText = !w.conf.showText
            w.conf.showText = !w.conf.showText
        }
        w.conf.style = 0
        w.hoverIdx = -1
        applyConfig(JSON.parse(JSON.stringify(exportConfig())))
        addClock(w)
        if (clocks.count !== 2) console.error("selftest-error: no se creó el segundo reloj")
        removeClock(clockAt(1))
        console.log("selftest: recorrido completo")
    }

    // ---------- Sincronización entre equipos ----------
    // Ajustes de todos los relojes, sin posiciones (cada equipo tiene sus propios monitores).
    function exportConfig() {
        const list = []
        for (let i = 0; i < clocks.count; i++) { const w = clocks.objectAt(i); if (w) list.push(w.snapshot()) }
        return { clocks: list }
    }
    function reportConfig() { sync.report(JSON.stringify(exportConfig())) }

    // Aplica la configuración que llega de otro equipo.
    function applyConfig(data) {
        const list = (data && data.clocks) || []
        if (list.length === 0) return
        if (sync.syncCount) {
            while (clockModel.count < list.length) addClock(clockAt(0), true)
            while (clockModel.count > list.length) {
                const cid = clockModel.get(clockModel.count - 1).cid
                clockModel.remove(clockModel.count - 1)
                if (cid !== 0) { staleGroups.push("reloj_" + cid); cleanup.restart() }
            }
            saveIds()
        }
        for (let i = 0; i < Math.min(clocks.count, list.length); i++) {
            const w = clocks.objectAt(i)
            if (w) w.applyValues(list[i])
        }
    }

    Connections {
        target: sync
        function onRemoteConfig(json) { mgr.applyConfig(JSON.parse(json)) }
        function onRequestLocal() { mgr.reportConfig() }
    }
    // Detecta cambios locales cada 15 s y los sube unos segundos después.
    Timer {
        interval: 15000
        repeat: true
        running: sync.mode !== "off"
        onTriggered: mgr.reportConfig()
    }

    Component.onCompleted: {
        const seen = {}
        appCfg.clockIds.split(",").forEach(function (s) {
            const v = parseInt(s, 10)
            if (!isNaN(v) && v >= 0 && !seen[v]) { seen[v] = true; clockModel.append({ cid: v }) }
        })
        if (clockModel.count === 0) clockModel.append({ cid: 0 })
        saveIds()
        reportConfig()
        sync.start()
    }

    Instantiator {
        id: clocks
        model: clockModel
        delegate: ClockWindow {
            clockId: model.cid
            app: mgr
        }
    }

    readonly property var primary: clocks.count > 0 ? clocks.objectAt(0) : null

    Platform.SystemTrayIcon {
        visible: true
        icon.source: Qt.resolvedUrl("icon.svg")
        tooltip: mgr.primary ? "Arco · " + Logic.daySubtitle(mgr.primary.t.day, false) : "Arco"
        menu: TrayMenu { app: mgr; clocks: clocks }
        onActivated: (reason) => {
            if (reason === Platform.SystemTrayIcon.Trigger) mgr.setAllVisible(!mgr.anyVisible())
        }
    }
}
