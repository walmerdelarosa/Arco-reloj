import QtQuick
import QtQuick.Window
import QtCore
import Qt.labs.platform as Platform
import "clocklogic.js" as Logic

Window {
    id: win
    visible: false
    title: "Arco"
    color: "transparent"

    // ---------- Ajustes persistentes ----------
    Settings {
        id: cfg
        category: "reloj"
        // anillos (de fuera hacia dentro)
        property bool showYear: true
        property bool showMonth: true
        property bool showWeek: false
        property bool showDay: true
        property bool showHour: true
        property bool showMinute: true
        property string cYear: "#8B5CF6"
        property string cMonth: "#3B82F6"
        property string cWeek: "#06B6D4"
        property string cDay: "#10B981"
        property string cHour: "#F59E0B"
        property string cMinute: "#EF4444"
        property int paletteIndex: 0
        // apariencia
        property int style: 0
        property real dialSize: 240
        property real contentOpacity: 0.85
        property real thickScale: 1.0
        property real trackOpacity: 0.16
        property bool showBackdrop: true
        property real backdropOpacity: 0.35
        property string cBack: "#000000"
        property string cText: "#FFFFFF"
        property bool hoverReveal: true
        // texto central
        property bool showText: true
        property bool showSeconds: false
        property bool h12: false
        property bool smooth: false
        // día / jornada
        property bool workMode: false
        property real workStart: 8
        property real workEnd: 18
        // ventana
        property bool onTop: true
        property bool locked: false
        property bool clickThrough: false
        property real winX: -100000
        property real winY: -100000
        property int edgeGap: 16
        property int nudgeStep: 10
        // anti burn-in
        property bool antiBurn: true
        property int burnRadius: 8
        property int burnInterval: 120
        property bool burnDimTracks: false
    }

    readonly property var ringDefs: [
        { key: "year",   name: "Año",    show: "showYear",   col: "cYear"   },
        { key: "month",  name: "Mes",    show: "showMonth",  col: "cMonth"  },
        { key: "week",   name: "Semana", show: "showWeek",   col: "cWeek"   },
        { key: "day",    name: "Día",    show: "showDay",    col: "cDay"    },
        { key: "hour",   name: "Hora",   show: "showHour",   col: "cHour"   },
        { key: "minute", name: "Minuto", show: "showMinute", col: "cMinute" }
    ]
    readonly property var activeRings: ringDefs.filter(d => cfg[d.show])

    // ---------- Tiempo ----------
    property date now: new Date()
    readonly property var t: Logic.compute(now, { workMode: cfg.workMode, workStart: cfg.workStart, workEnd: cfg.workEnd })
    readonly property bool needSeconds: cfg.showMinute || (cfg.showText && cfg.showSeconds) || hoverIdx >= 0
    readonly property bool smoothOn: cfg.smooth && cfg.showMinute

    onNeedSecondsChanged: kick()
    onSmoothOnChanged: kick()
    function kick() { if (!visible) return; ticker.interval = 1; ticker.restart() }
    onVisibleChanged: visible ? kick() : ticker.stop()   // oculto = cero trabajo

    Timer {
        id: ticker
        interval: 1
        repeat: false
        onTriggered: {
            win.now = new Date()
            interval = Logic.nextDelay(win.now, win.needSeconds, win.smoothOn)
            restart()
        }
    }

    // ---------- Geometría ----------
    readonly property int margin: cfg.antiBurn ? cfg.burnRadius + 1 : 1
    width: Math.round(cfg.dialSize + 2 * margin)
    height: width

    readonly property real pad: cfg.dialSize * 0.035 + 2
    readonly property real rOuter: cfg.dialSize / 2 - pad
    readonly property int n: activeRings.length
    readonly property real inner: n === 0 ? rOuter : (cfg.showText ? rOuter * 0.45 : rOuter * 0.16)
    readonly property real band: (rOuter - inner) / Math.max(1, n)
    readonly property var styleFactor: [0.62, 0.80, 0.20, 0.34, 0.95]
    readonly property real thick: Math.min(band * 0.97, band * styleFactor[cfg.style] * cfg.thickScale)
    function ringRadius(i) { return rOuter - band * (i + 0.5) }

    property int hoverIdx: -1

    // ---------- Anti burn-in ----------
    property int burnStep: 0
    readonly property var burn: cfg.antiBurn ? Logic.burnOffset(burnStep, cfg.burnRadius) : ({ x: 0, y: 0 })
    Timer {
        interval: Math.max(10, cfg.burnInterval) * 1000
        repeat: true
        running: win.visible && cfg.antiBurn
        onTriggered: {
            win.burnStep++
            if (cfg.onTop) win.raise()     // recupera la capa superior si otra ventana la tomó
        }
    }

    // ---------- Ventana ----------
    flags: Qt.FramelessWindowHint
           | Qt.NoDropShadowWindowHint
           | Qt.WindowDoesNotAcceptFocus
           | (Qt.platform.os === "osx" ? Qt.Window : Qt.Tool)
           | (cfg.onTop ? Qt.WindowStaysOnTopHint : 0)
           | (cfg.clickThrough ? Qt.WindowTransparentForInput : 0)

    function isOnScreen(px, py) {
        const ss = Qt.application.screens
        for (let i = 0; i < ss.length; i++) {
            const s = ss[i]
            if (px >= s.virtualX && px < s.virtualX + s.width && py >= s.virtualY && py < s.virtualY + s.height)
                return true
        }
        return false
    }
    // ---------- Posición ----------
    readonly property int edgeGap: cfg.edgeGap
    function centerX() { return Math.round(x + width / 2) }
    function centerY() { return Math.round(y + height / 2) }
    // Coloca el reloj en una posición relativa del área útil: h, v ∈ {0, 0.5, 1}
    // (0 = izquierda/arriba, 0.5 = centro, 1 = derecha/abajo).
    function placeIn(g, h, v) {
        x = Math.round(g.x + edgeGap + (g.width - width - 2 * edgeGap) * h)
        y = Math.round(g.y + edgeGap + (g.height - height - 2 * edgeGap) * v)
    }
    function place(h, v) {
        placeIn(plat.availableGeometry(centerX(), centerY()), h, v)
    }
    function centerOnScreen() { place(0.5, 0.5) }
    function resetPosition() { place(1, 0) }
    function moveToNextScreen() {
        const g = plat.availableGeometry(centerX(), centerY())
        const h = Math.max(0, Math.min(1, (x - g.x - edgeGap) / Math.max(1, g.width - width - 2 * edgeGap)))
        const v = Math.max(0, Math.min(1, (y - g.y - edgeGap) / Math.max(1, g.height - height - 2 * edgeGap)))
        placeIn(plat.nextScreenGeometry(centerX(), centerY()), h, v)   // misma posición relativa
    }
    function nudge(dx, dy) { x += dx; y += dy }
    function setSize(v) {
        const nv = Math.max(90, Math.min(1800, Math.round(v)))
        const d = nv - cfg.dialSize
        cfg.dialSize = nv
        x -= d / 2; y -= d / 2             // crece desde el centro
    }

    property bool ready: false
    Component.onCompleted: {
        if (isOnScreen(cfg.winX + width / 2, cfg.winY + height / 2)) { x = cfg.winX; y = cfg.winY }
        else resetPosition()
        ready = true
        visible = true
    }
    onXChanged: if (ready) cfg.winX = x
    onYChanged: if (ready) cfg.winY = y

    // ---------- Dial ----------
    Item {
        id: dial
        width: cfg.dialSize
        height: cfg.dialSize
        x: win.margin + win.burn.x
        y: win.margin + win.burn.y
        Behavior on x { NumberAnimation { duration: 1600; easing.type: Easing.InOutSine } }
        Behavior on y { NumberAnimation { duration: 1600; easing.type: Easing.InOutSine } }

        opacity: (cfg.hoverReveal && hover.hovered) ? 1.0 : cfg.contentOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        // Capa en GPU: opacidad de grupo correcta y antialiasing MSAA para el estilo Segmentos
        layer.enabled: true
        layer.samples: cfg.style === 1 ? 4 : 0

        Rectangle {
            visible: cfg.showBackdrop
            anchors.centerIn: parent
            width: 2 * (win.rOuter + win.pad * 0.6); height: width; radius: width / 2
            color: cfg.cBack
            opacity: cfg.backdropOpacity
        }

        Repeater {
            model: win.activeRings
            delegate: Ring {
                required property var modelData
                required property int index
                anchors.fill: parent
                radius: win.ringRadius(index)
                thickness: win.thick
                color: cfg[modelData.col]
                progress: win.t[modelData.key].p
                segments: win.t[modelData.key].segs
                style: cfg.style
                trackOpacity: cfg.burnDimTracks ? cfg.trackOpacity * 0.5 : cfg.trackOpacity
                highlighted: win.hoverIdx === index
            }
        }

        Column {
            anchors.centerIn: parent
            visible: cfg.showText && win.inner > 16
            spacing: 0
            readonly property real boxW: win.inner * (win.n === 0 ? 1.8 : 1.62)
            readonly property var hr: win.hoverIdx >= 0 && win.hoverIdx < win.n ? win.activeRings[win.hoverIdx] : null
            readonly property var hv: hr ? win.t[hr.key] : null

            Text {
                width: parent.boxW
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 6
                font.pixelSize: Math.max(8, win.inner * (win.n === 0 ? 0.5 : 0.40))
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                color: parent.hr ? cfg[parent.hr.col] : cfg.cText
                text: parent.hr ? Math.floor(parent.hv.p * 100) + " %" : Logic.timeText(win.now, cfg.showSeconds, cfg.h12)
            }
            Text {
                width: parent.boxW
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 5
                font.pixelSize: Math.max(6, win.inner * 0.15)
                color: cfg.cText
                opacity: 0.72
                text: parent.hr
                      ? parent.hr.name + " · quedan " + Logic.fmt(parent.hv.remaining, cfg.showSeconds || parent.hr.key === "minute")
                      : Logic.daySubtitle(win.t.day, cfg.showSeconds)
            }
        }

        // ---------- Interacción ----------
        DragHandler {
            target: null
            enabled: !cfg.locked
            onActiveChanged: if (active) win.startSystemMove()
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onDoubleTapped: settingsWin.openIt()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: ctxMenu.open()
        }
        WheelHandler {
            target: null
            enabled: !cfg.locked
            onWheel: (ev) => {
                const d = (ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x) / 120
                if (ev.modifiers & Qt.ShiftModifier)
                    cfg.contentOpacity = Math.max(0.1, Math.min(1, cfg.contentOpacity + d * 0.05))
                else
                    win.setSize(cfg.dialSize + d * Math.max(16, cfg.dialSize * 0.05))
            }
        }


        HoverHandler {
            id: hover
            onPointChanged: win.updateHover(point.position)
            onHoveredChanged: if (!hovered) win.hoverIdx = -1
        }
    }

    function updateHover(p) {
        const dx = p.x - dial.width / 2, dy = p.y - dial.height / 2
        const r = Math.sqrt(dx * dx + dy * dy)
        const i = Math.floor((rOuter - r) / band)
        hoverIdx = (r <= rOuter && i >= 0 && i < n) ? i : -1
    }

    AppMenu { id: ctxMenu; conf: cfg; clock: win; settingsWindow: settingsWin }

    Platform.SystemTrayIcon {
        visible: true
        icon.source: Qt.resolvedUrl("icon.svg")
        tooltip: "Arco · " + Logic.daySubtitle(win.t.day, false)
        menu: AppMenu { conf: cfg; clock: win; settingsWindow: settingsWin }
        onActivated: (reason) => {
            if (reason === Platform.SystemTrayIcon.Trigger) win.visible = !win.visible
        }
    }

    SettingsWindow { id: settingsWin; conf: cfg; clock: win }
}
