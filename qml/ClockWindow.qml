import QtQuick
import QtQuick.Window
import QtCore
import "clocklogic.js" as Logic

// Un reloj. Puede haber varios (uno por monitor); cada uno guarda sus propios ajustes.
Window {
    id: win
    visible: false
    title: "Arco · reloj " + number
    color: "transparent"

    property int clockId: 0          // 0 = primer reloj (conserva la sección «reloj» de versiones anteriores)
    property var app: null            // gestor de relojes (main.qml)
    readonly property int number: app ? app.numberOf(clockId, app.revision) : 1
    property alias conf: cfg
    property alias settingsWindow: settingsWin

    // ---------- Ajustes persistentes ----------
    Settings {
        id: cfg
        category: win.clockId === 0 ? "reloj" : "reloj_" + win.clockId
        property int cfgVersion: 1
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
        property real centerRatio: 0.45
        property real textScale: 1.0
        property real trackOpacity: 0.16
        property bool showBackdrop: true
        property real backdropOpacity: 0.35
        property string cBack: "#000000"
        property string cText: "#FFFFFF"
        property bool hoverReveal: true
        // transparencias individuales
        property real oYear: 1
        property real oMonth: 1
        property real oWeek: 1
        property real oDay: 1
        property real oHour: 1
        property real oMinute: 1
        property real oTime: 1
        property real oDate: 0.85
        property real oSub: 0.72
        property real oLabels: 0.8
        property real oTicks: 0.9
        property real oHands: 1
        // texto central
        property bool showText: true
        property bool showTime: true
        property string timeFormat: "HH:mm"
        property bool showDate: false
        property string dateFormat: "ddd d MMM"
        property bool showSub: true
        property bool showSeconds: false      // segundos en el tiempo restante
        property bool h12: false              // solo para migrar ajustes antiguos
        property bool smooth: false
        // analógico
        property bool secondHand: true
        property string cHands: "#FFFFFF"
        property string cSecond: "#EF4444"
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

    // Ajustes que se copian al crear un reloj nuevo a partir de este (todo menos la posición).
    readonly property var cfgKeys: [
        "cfgVersion", "showYear", "showMonth", "showWeek", "showDay", "showHour", "showMinute",
        "cYear", "cMonth", "cWeek", "cDay", "cHour", "cMinute", "paletteIndex",
        "style", "dialSize", "contentOpacity", "thickScale", "centerRatio", "textScale", "trackOpacity",
        "showBackdrop", "backdropOpacity", "cBack", "cText", "hoverReveal",
        "oYear", "oMonth", "oWeek", "oDay", "oHour", "oMinute", "oTime", "oDate", "oSub", "oLabels", "oTicks", "oHands",
        "showText", "showTime", "timeFormat", "showDate", "dateFormat", "showSub", "showSeconds", "h12", "smooth",
        "secondHand", "cHands", "cSecond", "workMode", "workStart", "workEnd",
        "onTop", "locked", "clickThrough", "edgeGap", "nudgeStep",
        "antiBurn", "burnRadius", "burnInterval", "burnDimTracks"
    ]
    function applyValues(v) {
        for (let i = 0; i < cfgKeys.length; i++) {
            const k = cfgKeys[i]
            if (v[k] !== undefined && typeof v[k] === typeof cfg[k] && cfg[k] !== v[k]) cfg[k] = v[k]
        }
    }
    function snapshot() {
        const o = {}
        for (let i = 0; i < cfgKeys.length; i++) o[cfgKeys[i]] = cfg[cfgKeys[i]]
        return o
    }

    readonly property var ringDefs: [
        { key: "year",   name: "Año",    short: "Año",  show: "showYear",   col: "cYear",   op: "oYear"   },
        { key: "month",  name: "Mes",    short: "Mes",  show: "showMonth",  col: "cMonth",  op: "oMonth"  },
        { key: "week",   name: "Semana", short: "Sem",  show: "showWeek",   col: "cWeek",   op: "oWeek"   },
        { key: "day",    name: "Día",    short: "Día",  show: "showDay",    col: "cDay",    op: "oDay"    },
        { key: "hour",   name: "Hora",   short: "Hora", show: "showHour",   col: "cHour",   op: "oHour"   },
        { key: "minute", name: "Minuto", short: "Min",  show: "showMinute", col: "cMinute", op: "oMinute" }
    ]
    readonly property var activeRings: ringDefs.filter(d => cfg[d.show])

    // ---------- Estilo ----------
    readonly property int st: Math.max(0, Math.min(7, cfg.style))
    readonly property bool hBars: st === 5
    readonly property bool vBars: st === 6
    readonly property bool analog: st === 7
    readonly property bool radial: !hBars && !vBars

    // ---------- Tiempo ----------
    property date now: new Date()
    readonly property var t: Logic.compute(now, { workMode: cfg.workMode, workStart: cfg.workStart, workEnd: cfg.workEnd })
    readonly property bool textSeconds: cfg.showText && (
        (cfg.showTime && Logic.usesSeconds(cfg.timeFormat)) ||
        (cfg.showDate && Logic.usesSeconds(cfg.dateFormat)) ||
        (cfg.showSub && cfg.showSeconds))
    readonly property bool secondHandOn: analog && cfg.secondHand
    readonly property bool needSeconds: cfg.showMinute || textSeconds || secondHandOn || hoverIdx >= 0
    readonly property bool smoothOn: cfg.smooth && (cfg.showMinute || secondHandOn)

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
    readonly property real ds: cfg.dialSize        // tamaño del dial
    readonly property real pad: ds * 0.035 + 2
    readonly property int n: activeRings.length

    // Circulares y analógico
    readonly property real rOuter: ds / 2 - pad
    readonly property bool centerUsed: cfg.showText || analog
    readonly property real centerRatio: Math.max(0.1, Math.min(0.9, cfg.centerRatio))
    readonly property real inner: n === 0 ? rOuter : (centerUsed ? rOuter * centerRatio : rOuter * 0.16)
    readonly property real band: (rOuter - inner) / Math.max(1, n)
    readonly property var styleFactor: [0.62, 0.80, 0.20, 0.34, 0.95, 0, 0, 0.40]
    readonly property real thick: Math.min(band * 0.97, band * styleFactor[st] * cfg.thickScale)
    readonly property real faceR: n === 0 ? rOuter : Math.max(4, inner - Math.max(2, band * 0.2))
    function ringRadius(i) { return rOuter - band * (i + 0.5) }

    // Barras
    readonly property real rowH: ds * 0.085 * cfg.thickScale                  // alto de cada barra horizontal
    readonly property real colW: ds * 0.12 * cfg.thickScale                   // ancho de cada columna vertical
    readonly property real labelW: rowH * 1.9
    readonly property real pctW: rowH * 1.7
    readonly property real colLabelH: colW * 0.45
    // En los estilos de barras el texto no cambia al pasar el ratón, para que la ventana no salte de tamaño.
    readonly property bool textShown: cfg.showText || (analog && hoverIdx >= 0)
    readonly property real textH: (!radial && textShown) ? textCol.height + (hBars ? rowH : colW) * 0.35 : 0
    readonly property real barsTop: pad + textH

    readonly property real dialW: hBars ? ds
                                : vBars ? Math.max(ds * 0.45, Math.max(1, n) * colW + 2 * pad)
                                : ds
    readonly property real dialH: hBars ? 2 * pad + textH + Math.max(1, n) * rowH : ds
    readonly property real colsLeft: (dialW - n * colW) / 2

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
    width: Math.round(dialW + 2 * margin)
    height: Math.round(dialH + 2 * margin)
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
        const ow = width, oh = height
        cfg.dialSize = nv
        x -= Math.round((width - ow) / 2)     // crece desde el centro
        y -= Math.round((height - oh) / 2)
    }

    property bool ready: false
    Component.onCompleted: {
        if (cfg.cfgVersion < 2) {          // ajustes de la versión 1: «12 h» y «segundos» pasan al formato
            cfg.timeFormat = (cfg.h12 ? "h:mm" : "HH:mm") + (cfg.showSeconds ? ":ss" : "") + (cfg.h12 ? " A" : "")
            cfg.cfgVersion = 2
        }
        const clone = app ? app.takeClone() : null
        if (clone) {
            for (const k in clone.values) cfg[k] = clone.values[k]
            x = clone.x; y = clone.y
            if (plat.screenCount() > 1) moveToNextScreen()
            else { x += 40; y += 40; if (!isOnScreen(centerX(), centerY())) centerOnScreen() }
        } else if (isOnScreen(cfg.winX + width / 2, cfg.winY + height / 2)) {
            x = cfg.winX; y = cfg.winY
        } else {
            resetPosition()
        }
        cfg.winX = x; cfg.winY = y
        ready = true
        visible = true
    }
    onXChanged: if (ready) cfg.winX = x
    onYChanged: if (ready) cfg.winY = y

    // ---------- Dial ----------
    Item {
        id: dial
        width: win.dialW
        height: win.dialH
        x: win.margin + win.burn.x
        y: win.margin + win.burn.y
        Behavior on x { NumberAnimation { duration: 1600; easing.type: Easing.InOutSine } }
        Behavior on y { NumberAnimation { duration: 1600; easing.type: Easing.InOutSine } }

        opacity: (cfg.hoverReveal && hover.hovered) ? 1.0 : cfg.contentOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        // Capa en GPU: opacidad de grupo correcta y antialiasing MSAA para el estilo Segmentos
        layer.enabled: true
        layer.samples: win.st === 1 ? 4 : 0

        // Fondo: disco en los estilos circulares, rectángulo redondeado en las barras
        Rectangle {
            visible: cfg.showBackdrop
            anchors.centerIn: parent
            width: win.radial ? 2 * (win.rOuter + win.pad * 0.6) : parent.width
            height: win.radial ? width : parent.height
            radius: win.radial ? width / 2 : Math.min(width, height) * 0.08
            color: cfg.cBack
            opacity: cfg.backdropOpacity
        }

        // Anillos (estilos circulares y alrededor de la esfera analógica)
        Repeater {
            model: win.radial ? win.activeRings : []
            delegate: Ring {
                required property var modelData
                required property int index
                anchors.fill: parent
                opacity: cfg[modelData.op]
                radius: win.ringRadius(index)
                thickness: win.thick
                color: cfg[modelData.col]
                progress: win.t[modelData.key].p
                segments: win.t[modelData.key].segs
                style: win.analog ? 0 : win.st
                trackOpacity: cfg.burnDimTracks ? cfg.trackOpacity * 0.5 : cfg.trackOpacity
                highlighted: win.hoverIdx === index
            }
        }

        // Esfera analógica
        AnalogFace {
            visible: win.analog
            anchors.fill: parent
            r: win.faceR
            now: win.now
            smooth: win.smoothOn
            showSecondHand: cfg.secondHand
            tickColor: cfg.cText
            handColor: cfg.cHands
            secondColor: cfg.cSecond
            tickOpacity: cfg.oTicks
            handOpacity: cfg.oHands
        }

        // Barras horizontales: nombre · barra · porcentaje
        Repeater {
            model: win.hBars ? win.activeRings : []
            delegate: Item {
                required property var modelData
                required property int index
                x: win.pad
                y: win.barsTop + index * win.rowH
                width: win.dialW - 2 * win.pad
                height: win.rowH
                opacity: cfg[modelData.op]
                Text {
                    width: win.labelW
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: cfg.cText
                    opacity: cfg.oLabels
                    font.pixelSize: Math.max(6, win.rowH * 0.40)
                    elide: Text.ElideRight
                }
                Bar {
                    x: win.labelW
                    width: parent.width - win.labelW - win.pctW
                    height: parent.height
                    vertical: false
                    thickness: win.rowH * 0.42
                    color: cfg[modelData.col]
                    progress: win.t[modelData.key].p
                    trackOpacity: cfg.burnDimTracks ? cfg.trackOpacity * 0.5 : cfg.trackOpacity
                    highlighted: win.hoverIdx === index
                }
                Text {
                    x: parent.width - win.pctW
                    width: win.pctW
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: Math.floor(win.t[modelData.key].p * 100) + " %"
                    color: cfg.cText
                    opacity: cfg.oLabels
                    font.pixelSize: Math.max(6, win.rowH * 0.40)
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        // Barras verticales: columnas con el nombre abajo
        Repeater {
            model: win.vBars ? win.activeRings : []
            delegate: Item {
                required property var modelData
                required property int index
                x: win.colsLeft + index * win.colW
                y: win.barsTop
                width: win.colW
                height: win.dialH - win.pad - win.barsTop
                opacity: cfg[modelData.op]
                Text {
                    width: parent.width
                    height: win.colLabelH
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Math.floor(win.t[modelData.key].p * 100) + "%"
                    color: cfg.cText
                    opacity: cfg.oLabels
                    font.pixelSize: Math.max(6, win.colW * 0.26)
                    font.features: ({ "tnum": 1 })
                }
                Bar {
                    y: win.colLabelH
                    width: parent.width
                    height: parent.height - 2 * win.colLabelH
                    vertical: true
                    thickness: win.colW * 0.42
                    color: cfg[modelData.col]
                    progress: win.t[modelData.key].p
                    trackOpacity: cfg.burnDimTracks ? cfg.trackOpacity * 0.5 : cfg.trackOpacity
                    highlighted: win.hoverIdx === index
                }
                Text {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: win.colLabelH
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.short
                    color: cfg.cText
                    opacity: cfg.oLabels
                    font.pixelSize: Math.max(6, win.colW * 0.28)
                }
            }
        }

        // ---------- Texto: hora, fecha y tiempo restante ----------
        // Cada línea se ajusta al ancho disponible: si el texto es largo, continúa en la línea de abajo.
        Column {
            id: textCol
            // Anillo bajo el ratón y su valor, calculados juntos para que nunca queden desfasados.
            readonly property var hov: {
                if (!win.radial || win.hoverIdx < 0 || win.hoverIdx >= win.n) return null
                const ring = win.activeRings[win.hoverIdx]
                const val = ring ? win.t[ring.key] : undefined
                return val ? { ring: ring, val: val } : null
            }
            readonly property real boxW: win.analog ? win.faceR * 1.25
                                       : win.radial ? win.inner * (win.n === 0 ? 1.8 : 1.62)
                                       : win.dialW - 2 * win.pad
            readonly property real base: (win.analog ? win.faceR * 0.5
                                       : win.radial ? win.inner
                                       : win.ds * win.centerRatio * 0.74) * cfg.textScale

            visible: (win.textShown && (win.radial ? (win.analog ? win.faceR > 20 : win.inner > 16) : true))
            width: boxW
            spacing: 0
            x: (dial.width - width) / 2
            y: win.analog ? dial.height / 2 + win.faceR * 0.22
             : win.radial ? (dial.height - height) / 2
             : win.pad

            Text {
                width: parent.width
                visible: textCol.hov !== null || (cfg.showText && cfg.showTime)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                font.pixelSize: Math.max(8, textCol.base * (win.radial && win.n === 0 && !win.analog ? 0.5 : 0.40))
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                color: textCol.hov ? cfg[textCol.hov.ring.col] : cfg.cText
                opacity: textCol.hov ? 1 : cfg.oTime
                text: textCol.hov ? Math.floor(textCol.hov.val.p * 100) + " %" : Logic.formatDate(win.now, cfg.timeFormat)
            }
            Text {
                width: parent.width
                visible: textCol.hov === null && cfg.showText && cfg.showDate
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 4
                font.pixelSize: Math.max(6, textCol.base * 0.17)
                color: cfg.cText
                opacity: cfg.oDate
                text: Logic.formatDate(win.now, cfg.dateFormat)
            }
            Text {
                width: parent.width
                visible: textCol.hov !== null || (cfg.showText && cfg.showSub)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                font.pixelSize: Math.max(6, textCol.base * 0.15)
                color: cfg.cText
                opacity: textCol.hov ? 0.85 : cfg.oSub
                text: textCol.hov
                      ? textCol.hov.ring.name + " · quedan " + Logic.fmt(textCol.hov.val.remaining, cfg.showSeconds || textCol.hov.ring.key === "minute")
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
        let i = -1
        if (radial) {
            const dx = p.x - dial.width / 2, dy = p.y - dial.height / 2
            const r = Math.sqrt(dx * dx + dy * dy)
            if (r <= rOuter && r > inner) i = Math.floor((rOuter - r) / band)
        } else if (hBars) {
            if (p.y >= barsTop) i = Math.floor((p.y - barsTop) / rowH)
        } else if (vBars) {
            if (p.y >= barsTop) i = Math.floor((p.x - colsLeft) / colW)
        }
        hoverIdx = (i >= 0 && i < n) ? i : -1
    }

    AppMenu { id: ctxMenu; conf: cfg; clock: win; settingsWindow: settingsWin; app: win.app }

    SettingsWindow { id: settingsWin; conf: cfg; clock: win; app: win.app }
}
