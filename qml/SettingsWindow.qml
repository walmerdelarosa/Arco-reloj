import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "clocklogic.js" as Logic

// Ajustes de un reloj, con aspecto similar a PowerToys / Windows 11:
// índice a la izquierda con desplegables y una sola página con tarjetas desplegables.
// El índice resalta la sección visible mientras te desplazas.
ApplicationWindow {
    id: sw
    property var conf
    property var clock
    property var app

    // ---------- Idioma y tema ----------
    function tr(es, en) { return ui.lang === "en" ? en : es }
    readonly property bool dark: ui.dark
    readonly property color cBg:         dark ? "#202020" : "#f3f3f3"
    readonly property color cCard:       dark ? "#2b2b2b" : "#fbfbfb"
    readonly property color cCardHover:  dark ? "#323232" : "#f5f5f5"
    readonly property color cStroke:     dark ? "#1d1d1d" : "#e5e5e5"
    readonly property color cLine:       dark ? "#3a3a3a" : "#ececec"
    readonly property color cText:       dark ? "#ffffff" : "#1b1b1b"
    readonly property color cText2:      dark ? "#c8c8c8" : "#5d5d5d"
    readonly property color cAccent:     dark ? "#60cdff" : "#005fb8"
    readonly property color cAccentText: dark ? "#000000" : "#ffffff"
    readonly property color cNavSel:     dark ? "#2d2d2d" : "#eaeaea"
    readonly property color cNavHover:   dark ? "#292929" : "#ededed"
    readonly property color cControl:    dark ? "#373737" : "#ffffff"
    readonly property bool icons: Qt.platform.os === "windows"     // Segoe MDL2 Assets
    readonly property string iconFont: "Segoe MDL2 Assets"

    title: "Arco · " + tr("Ajustes", "Settings") + (app && app.count > 1 && clock ? " · " + tr("reloj ", "clock ") + clock.number : "")
    width: 980
    height: 720
    minimumWidth: 760
    minimumHeight: 460
    visible: false
    transientParent: null
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
           | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint
           | (conf && conf.onTop ? Qt.WindowStaysOnTopHint : 0)

    font.family: Qt.platform.os === "windows" ? "Segoe UI" : Qt.application.font.family
    font.pixelSize: 13
    color: cBg
    palette.window: cBg
    palette.windowText: cText
    palette.base: cControl
    palette.alternateBase: cCard
    palette.text: cText
    palette.button: cControl
    palette.buttonText: cText
    palette.highlight: cAccent
    palette.highlightedText: cAccentText
    palette.mid: cLine
    palette.light: cLine
    palette.midlight: cLine
    palette.dark: cStroke
    palette.shadow: cStroke
    palette.placeholderText: cText2
    palette.toolTipBase: cCard
    palette.toolTipText: cText

    // ---------- Índice ----------
    readonly property var nav: [
        { key: "appearance", icon: "", es: "Apariencia", en: "Appearance", items: [
            { key: "style",    es: "Estilo y tamaño",         en: "Style and size" },
            { key: "opacity",  es: "Transparencia general",   en: "Overall opacity" },
            { key: "rings",    es: "Anillos",                 en: "Rings" },
            { key: "backdrop", es: "Fondo",                   en: "Background" },
            { key: "analog",   es: "Reloj analógico",         en: "Analog clock" } ] },
        { key: "text", icon: "", es: "Texto", en: "Text", items: [
            { key: "textgeneral", es: "Texto central",        en: "Center text" },
            { key: "time",        es: "Hora",                 en: "Time" },
            { key: "date",        es: "Fecha",                en: "Date" },
            { key: "remaining",   es: "Tiempo restante",      en: "Time remaining" },
            { key: "codes",       es: "Códigos de formato",   en: "Format codes" } ] },
        { key: "clocks", icon: "", es: "Relojes y posición", en: "Clocks and position", items: [
            { key: "clocklist", es: "Relojes",  en: "Clocks" },
            { key: "position",  es: "Posición", en: "Position" } ] },
        { key: "behavior", icon: "", es: "Comportamiento", en: "Behavior", items: [
            { key: "window",  es: "Ventana",                 en: "Window" },
            { key: "workday", es: "Jornada laboral",         en: "Workday" },
            { key: "burnin",  es: "Protección burn-in",      en: "Burn-in protection" } ] },
        { key: "syncCat", icon: "", es: "Sincronización", en: "Sync", items: [
            { key: "sync", es: "Entre equipos", en: "Across devices" } ] },
        { key: "appCat", icon: "", es: "Aplicación", en: "App", items: [
            { key: "language", es: "Idioma y tema",  en: "Language and theme" },
            { key: "about",    es: "Ayuda",          en: "Help" } ] }
    ]
    readonly property var order: {
        const o = []
        nav.forEach(c => { o.push(c.key); c.items.forEach(i => o.push(i.key)) })
        return o
    }
    function navText(o) { return ui.lang === "en" ? o.en : o.es }
    function catOf(key) {
        for (let i = 0; i < nav.length; i++) {
            if (nav[i].key === key) return key
            for (let j = 0; j < nav[i].items.length; j++) if (nav[i].items[j].key === key) return nav[i].key
        }
        return ""
    }
    function navItemVisible(key) { return key !== "analog" || (clock && clock.analog) }

    property var sections: ({})
    property string current: "appearance"
    readonly property string currentCat: catOf(current)
    function registerSection(key, item) { sections[key] = item }

    function updateSpy() {
        let best = order[0]
        const atEnd = flick.contentY >= flick.contentHeight - flick.height - 4
        for (let i = 0; i < order.length; i++) {
            const it = sections[order[i]]
            if (!it || !it.visible) continue
            const y = it.mapToItem(col, 0, 0).y
            if (atEnd || y <= flick.contentY + 90) best = order[i]
            else break
        }
        current = best
    }

    property string pendingKey: ""
    function scrollTo(key) {
        const it = sections[key]
        if (!it) return
        if (it.expanded !== undefined) it.expanded = true
        pendingKey = key
        scrollTimer.restart()            // espera a que el diseño se recoloque tras desplegar
    }
    Timer {
        id: scrollTimer
        interval: 40
        onTriggered: {
            const it = sw.sections[sw.pendingKey]
            if (!it) return
            const y = it.mapToItem(col, 0, 0).y + col.y - 16
            scrollAnim.to = Math.max(0, Math.min(y, flick.contentHeight - flick.height))
            scrollAnim.restart()
        }
    }

    function expandAll() {
        for (const k in sections) if (sections[k].expanded !== undefined) sections[k].expanded = true
    }
    function openIt() {
        if (visibility === Window.Minimized) showNormal(); else show()
        raise(); requestActivate()
    }
    function openHelp() { openIt(); scrollTo("about") }

    ColorDialog {
        id: colorDlg
        property string key: ""
        title: sw.tr("Elegir color", "Choose a color")
        onAccepted: sw.conf[key] = selectedColor.toString()
    }
    function pickColor(key) {
        colorDlg.key = key
        colorDlg.selectedColor = conf[key]
        colorDlg.open()
    }
    FolderDialog {
        id: folderDlg
        title: sw.tr("Carpeta para sincronizar la configuración", "Folder used to sync settings")
        onAccepted: sync.setFolder(selectedFolder.toString())
    }

    // =====================================================================
    // Componentes
    // =====================================================================

    // Interruptor estilo Windows 11, con «Activado / Desactivado» a la izquierda.
    // Con «key» lee y escribe sw.conf[key]; sin ella, se usa checked/onToggled desde fuera.
    component Toggle: Switch {
        id: tg
        property string key: ""
        property bool label: true
        checked: key !== "" && !!sw.conf[key]
        onToggled: if (key !== "") sw.conf[key] = checked
        padding: 0
        indicator: Rectangle {
            implicitWidth: 40; implicitHeight: 20; radius: 10
            x: tg.width - width
            y: (tg.height - height) / 2
            color: tg.checked ? (tg.enabled ? sw.cAccent : sw.cLine) : "transparent"
            border.color: tg.checked ? color : sw.cText2
            opacity: tg.enabled ? 1 : 0.5
            Rectangle {
                width: tg.pressed ? 14 : 12; height: 12; radius: 6
                y: 4
                x: tg.checked ? parent.width - width - 4 : 4
                color: tg.checked ? sw.cAccentText : sw.cText2
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        }
        contentItem: Item {
            implicitWidth: tg.label ? 132 : 40
            implicitHeight: 24
            Text {
                visible: tg.label
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 52
                text: tg.checked ? sw.tr("Activado", "On") : sw.tr("Desactivado", "Off")
                color: sw.cText
                opacity: tg.enabled ? 1 : 0.5
                font.pixelSize: 13
            }
        }
    }

    // Fila de ajuste: título y descripción a la izquierda, control a la derecha.
    component SRow: Item {
        id: r
        property string title: ""
        property string desc: ""
        property bool line: true
        property int indent: 0
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(56, Math.max(txt.implicitHeight, slot.implicitHeight) + 24)
        Rectangle { visible: r.line; width: parent.width; height: 1; color: sw.cLine }
        ColumnLayout {
            id: txt
            anchors.left: parent.left
            anchors.leftMargin: 18 + r.indent
            anchors.right: slot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: r.title
                color: sw.cText
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                opacity: r.enabled ? 1 : 0.5
            }
            Label {
                Layout.fillWidth: true
                visible: r.desc !== ""
                text: r.desc
                color: sw.cText2
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                opacity: r.enabled ? 1 : 0.5
            }
        }
        RowLayout {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
        }
    }

    // Fila que ocupa todo el ancho (campos de formato, cuadrícula de posición…).
    component WideRow: Item {
        id: wr
        default property alias content: wcol.data
        property bool line: true
        Layout.fillWidth: true
        implicitHeight: wcol.implicitHeight + 24
        Rectangle { visible: wr.line; width: parent.width; height: 1; color: sw.cLine }
        ColumnLayout {
            id: wcol
            x: 18
            y: 12
            width: parent.width - 36
            spacing: 6
        }
    }

    // Tarjeta desplegable. Se registra en el índice con «key».
    component Expander: Rectangle {
        id: ex
        property string key: ""
        property string title: ""
        property string desc: ""
        property string icon: ""
        property bool expanded: false
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: head.height + (expanded ? body.implicitHeight : 0)
        radius: 6
        color: sw.cCard
        border.color: sw.cStroke
        clip: true
        Component.onCompleted: sw.registerSection(key, ex)
        onImplicitHeightChanged: Qt.callLater(sw.updateSpy)

        Rectangle {
            id: head
            width: parent.width
            height: Math.max(66, headTxt.implicitHeight + 28)
            radius: 6
            color: headHover.hovered ? sw.cCardHover : "transparent"
            Text {
                id: headIcon
                visible: sw.icons && ex.icon !== ""
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                text: ex.icon
                font.family: sw.iconFont
                font.pixelSize: 18
                color: sw.cText
            }
            ColumnLayout {
                id: headTxt
                anchors.left: parent.left
                anchors.leftMargin: headIcon.visible ? 54 : 18
                anchors.right: chevron.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label { Layout.fillWidth: true; text: ex.title; color: sw.cText; font.pixelSize: 14; wrapMode: Text.WordWrap }
                Label {
                    Layout.fillWidth: true
                    visible: ex.desc !== ""
                    text: ex.desc
                    color: sw.cText2
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
            Text {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: sw.icons ? (ex.expanded ? "" : "") : (ex.expanded ? "▴" : "▾")
                font.family: sw.icons ? sw.iconFont : sw.font.family
                font.pixelSize: sw.icons ? 12 : 16
                color: sw.cText
            }
            HoverHandler { id: headHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: ex.expanded = !ex.expanded }
        }
        ColumnLayout {
            id: body
            y: head.height
            width: parent.width
            spacing: 0
            visible: ex.expanded
        }
    }

    // Título de categoría (también registrado para el índice)
    component CatHeader: Label {
        id: ch
        property string key: ""
        Layout.topMargin: 22
        Layout.bottomMargin: 4
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: sw.cText
        Component.onCompleted: sw.registerSection(key, ch)
    }

    component Swatch: Rectangle {
        property string key
        implicitWidth: 32; implicitHeight: 24; radius: 4
        color: sw.conf[key]
        border.color: sw.cLine
        border.width: 1
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.pickColor(parent.key) }
    }

    // Deslizador con su valor. Con «key» usa sw.conf[key]; si no, getter/setter.
    component SliderCtl: RowLayout {
        id: sc
        property string key: ""
        property var getter: null
        property var setter: null
        property real lo: 0
        property real hi: 1
        property real step: 0
        property real factor: 100
        property int decimals: 0
        property string suffix: " %"
        property int sliderWidth: 200
        spacing: 8
        Slider {
            id: sl
            Layout.preferredWidth: sc.sliderWidth
            from: sc.lo
            to: sc.hi
            stepSize: sc.step
            value: sc.getter ? sc.getter() : (sc.key !== "" ? sw.conf[sc.key] : 0)
            onMoved: {
                if (sc.setter) sc.setter(value)
                else if (sc.key !== "") sw.conf[sc.key] = value
            }
        }
        Label {
            Layout.preferredWidth: 58
            horizontalAlignment: Text.AlignRight
            text: (sl.value * sc.factor).toFixed(sc.decimals) + sc.suffix
            color: sw.cText2
        }
    }

    // Formato con códigos: campo, plantillas y vista previa
    component FormatRow: Item {
        id: fr
        property string key
        property var presets: []
        Layout.fillWidth: true
        implicitHeight: frCol.implicitHeight + 24
        Rectangle { width: parent.width; height: 1; color: sw.cLine }
        ColumnLayout {
        id: frCol
        x: 18
        y: 12
        width: parent.width - 36
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            TextField {
                Layout.fillWidth: true
                text: sw.conf[fr.key]
                selectByMouse: true
                placeholderText: sw.tr("Códigos, p. ej. HH:mm", "Codes, e.g. HH:mm")
                onTextEdited: sw.conf[fr.key] = text
            }
            ComboBox {
                Layout.preferredWidth: 170
                model: fr.presets
                displayText: sw.tr("Plantillas", "Presets")
                onActivated: (i) => sw.conf[fr.key] = fr.presets[i]
            }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: sw.cText2
            font.pixelSize: 12
            text: sw.tr("Vista previa: ", "Preview: ")
                  + (sw.clock ? Logic.formatDate(sw.clock.now, sw.conf[fr.key], ui.lang).replace(/\n/g, " ⏎ ") : "")
        }
        }
    }

    // Hora de la jornada: flechas de 30 en 30 min o cualquier hora escrita
    component TimeSpin: SpinBox {
        id: ts
        property string key
        from: 0; to: 1440; stepSize: 30
        editable: true
        Layout.preferredWidth: 130
        value: Math.round(sw.conf[key] * 60)
        textFromValue: function (v, locale) { return Logic.fmtHM(v) }
        valueFromText: function (text, locale) { const m = Logic.parseHM(text); return m < 0 ? ts.value : m }
        validator: RegularExpressionValidator { regularExpression: /^\s*\d{0,4}(\s*[:.hH]\s*\d{0,2})?\s*$/ }
        onValueModified: sw.conf[key] = value / 60
    }

    component PosButton: Button {
        property real h
        property real v
        implicitWidth: 46; implicitHeight: 34
        font.pixelSize: 15
        onClicked: sw.clock.place(h, v)
    }

    // =====================================================================
    // Estructura: índice + contenido
    // =====================================================================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Índice ----------
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 270

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2

                RowLayout {
                    Layout.leftMargin: 8
                    Layout.topMargin: 6
                    Layout.bottomMargin: 12
                    spacing: 10
                    Image { source: "icon.svg"; sourceSize.width: 22; sourceSize.height: 22 }
                    Label { text: "Arco"; font.pixelSize: 15; font.weight: Font.DemiBold; color: sw.cText }
                    Label {
                        visible: !!sw.app && sw.app.count > 1
                        text: sw.clock ? "· " + sw.tr("reloj ", "clock ") + sw.clock.number : ""
                        color: sw.cText2
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: navCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: navCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: sw.nav
                            delegate: Column {
                                id: catDel
                                required property var modelData
                                property bool open: false
                                readonly property bool isCur: sw.currentCat === modelData.key
                                width: navCol.width
                                spacing: 2

                                Rectangle {
                                    width: parent.width
                                    height: 38
                                    radius: 5
                                    color: catDel.isCur ? sw.cNavSel : (catHover.hovered ? sw.cNavHover : "transparent")
                                    Rectangle {
                                        visible: catDel.isCur
                                        x: 0; width: 3; height: 16; radius: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: sw.cAccent
                                    }
                                    Text {
                                        id: catIcon
                                        visible: sw.icons
                                        x: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: catDel.modelData.icon
                                        font.family: sw.iconFont
                                        font.pixelSize: 16
                                        color: sw.cText
                                    }
                                    Label {
                                        x: sw.icons ? 44 : 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - x - 40
                                        elide: Text.ElideRight
                                        text: sw.navText(catDel.modelData)
                                        color: sw.cText
                                        font.pixelSize: 14
                                    }
                                    HoverHandler { id: catHover; cursorShape: Qt.PointingHandCursor }
                                    MouseArea {
                                        anchors.left: parent.left
                                        anchors.right: chevronArea.left
                                        height: parent.height
                                        onClicked: { catDel.open = true; sw.scrollTo(catDel.modelData.key) }
                                    }
                                    // Desplegable del índice
                                    MouseArea {
                                        id: chevronArea
                                        anchors.right: parent.right
                                        width: 36
                                        height: parent.height
                                        onClicked: catDel.open = !(catDel.open || catDel.isCur)
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sw.icons ? ((catDel.open || catDel.isCur) ? "" : "")
                                                       : ((catDel.open || catDel.isCur) ? "▴" : "▾")
                                        font.family: sw.icons ? sw.iconFont : sw.font.family
                                        font.pixelSize: sw.icons ? 10 : 14
                                        color: sw.cText2
                                    }
                                }

                                Repeater {
                                    model: (catDel.open || catDel.isCur) ? catDel.modelData.items : []
                                    delegate: Rectangle {
                                        id: subDel
                                        required property var modelData
                                        readonly property bool isCur: sw.current === modelData.key
                                        visible: sw.navItemVisible(modelData.key)
                                        width: navCol.width
                                        height: visible ? 32 : 0
                                        radius: 5
                                        color: isCur ? sw.cNavSel : (subHover.hovered ? sw.cNavHover : "transparent")
                                        Label {
                                            x: sw.icons ? 44 : 28
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - x - 10
                                            elide: Text.ElideRight
                                            text: sw.navText(subDel.modelData)
                                            color: subDel.isCur ? sw.cText : sw.cText2
                                            font.pixelSize: 13
                                        }
                                        HoverHandler { id: subHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: sw.scrollTo(subDel.modelData.key) }
                                    }
                                }
                            }
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: sw.tr("Cerrar", "Close")
                    onClicked: sw.hide()
                }
            }
        }

        // ---------- Contenido ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: sw.dark ? "#272727" : "#f9f9f9"
            radius: 8

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: col.implicitHeight + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                onContentYChanged: sw.updateSpy()
                onHeightChanged: sw.updateSpy()
                NumberAnimation { id: scrollAnim; target: flick; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }

                ColumnLayout {
                    id: col
                    x: 28
                    y: 16
                    width: flick.width - 56
                    spacing: 6

                    Label {
                        text: sw.tr("Ajustes", "Settings")
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        color: sw.cText
                    }

                    // ================= Apariencia =================
                    CatHeader { key: "appearance"; text: sw.tr("Apariencia", "Appearance") }

                    Expander {
                        key: "style"
                        icon: ""
                        title: sw.tr("Estilo y tamaño", "Style and size")
                        desc: Logic.styleNames(ui.lang)[sw.conf.style] + (sw.conf.perStyle
                              ? sw.tr(" · cada estilo guarda su aspecto", " · each style keeps its own look") : "")
                        SRow {
                            title: sw.tr("Estilo", "Style")
                            ComboBox {
                                Layout.preferredWidth: 220
                                model: Logic.styleNames(ui.lang)
                                currentIndex: sw.conf.style
                                onActivated: (i) => sw.conf.style = i
                            }
                        }
                        SRow {
                            title: sw.tr("Ajustes propios para cada estilo", "Separate settings for each style")
                            desc: sw.tr("Colores, transparencias, tamaño y grosor se recuerdan por separado en cada estilo. Al cambiar de estilo recuperas su aspecto.",
                                        "Colors, opacity, size and thickness are remembered separately for each style. Switching styles brings back its look.")
                            Toggle { key: "perStyle" }
                        }
                        SRow {
                            title: sw.tr("Tamaño", "Size")
                            desc: sw.tr("También con la rueda del ratón sobre el reloj.", "You can also use the mouse wheel over the clock.")
                            SliderCtl { key: "dialSize"; lo: 90; hi: 1800; step: 2; factor: 1; suffix: " px" }
                        }
                        SRow {
                            title: sw.tr("Grosor", "Thickness")
                            SliderCtl { key: "thickScale"; lo: 0.4; hi: 1.6 }
                        }
                        SRow {
                            title: sw.tr("Radio del centro", "Center radius")
                            desc: sw.tr("Espacio para la hora o la esfera respecto a los anillos. En las barras, tamaño del bloque de texto.",
                                        "Room for the time or the dial relative to the rings. For bars, the size of the text block.")
                            SliderCtl { key: "centerRatio"; lo: 0.15; hi: 0.85 }
                        }
                        SRow {
                            title: sw.tr("Pista de fondo", "Track")
                            desc: sw.tr("Intensidad del recorrido que falta en cada anillo.", "How visible the remaining part of each ring is.")
                            SliderCtl { key: "trackOpacity"; lo: 0; hi: 0.5 }
                        }
                    }

                    Expander {
                        key: "opacity"
                        icon: ""
                        title: sw.tr("Transparencia general", "Overall opacity")
                        desc: sw.tr("Funciona como un mezclador de volumen: sigue al elemento más opaco y, al moverla, todos cambian en proporción.",
                                    "Works like a volume mixer: it follows the most opaque element and scales all of them together.")
                        SRow {
                            title: sw.tr("General", "Overall")
                            desc: sw.tr("Atajo: Mayús + rueda del ratón sobre el reloj.", "Shortcut: Shift + mouse wheel over the clock.")
                            SliderCtl {
                                getter: () => sw.clock ? sw.clock.master : 1
                                setter: (v) => sw.clock.setMaster(v)
                                lo: 0.05; hi: 1
                            }
                        }
                        SRow {
                            title: sw.tr("Opacidad completa al pasar el ratón", "Full opacity on hover")
                            desc: sw.tr("Mientras el ratón está encima, el reloj se ve como si la transparencia general estuviera al 100 %.",
                                        "While the pointer is over the clock it looks as if overall opacity were 100%.")
                            Toggle { key: "hoverReveal" }
                        }
                    }

                    Expander {
                        key: "rings"
                        icon: ""
                        title: sw.tr("Anillos", "Rings")
                        desc: sw.tr("Qué se muestra, con su color y su transparencia.", "What is shown, with its color and opacity.")
                        SRow {
                            line: true
                            title: sw.tr("Paleta", "Palette")
                            desc: sw.tr("Aplica un juego de colores a todos los anillos.", "Applies a color set to every ring.")
                            ComboBox {
                                Layout.preferredWidth: 220
                                model: Logic.paletteNames(ui.lang)
                                currentIndex: sw.conf.paletteIndex
                                onActivated: (i) => {
                                    const c = Logic.palettes[i].c
                                    sw.conf.paletteIndex = i
                                    sw.conf.cYear = c[0]; sw.conf.cMonth = c[1]; sw.conf.cWeek = c[2]
                                    sw.conf.cDay = c[3]; sw.conf.cHour = c[4]; sw.conf.cMinute = c[5]
                                }
                            }
                        }
                        SRow {
                            title: sw.tr("Mostrar el avance como", "Show progress as")
                            desc: sw.tr("Porcentaje o en las unidades de cada anillo: días del año, mes y semana; horas del día o de la jornada; minutos de la hora; segundos del minuto. Se ve en las barras y al pasar el ratón por un anillo.",
                                        "Percentage or each ring's own units: days of the year, month and week; hours of the day or workday; minutes of the hour; seconds of the minute. Shown on bars and when hovering a ring.")
                            ComboBox {
                                Layout.preferredWidth: 240
                                model: Logic.valueModeNames(ui.lang)
                                currentIndex: sw.conf.valueMode
                                onActivated: (i) => sw.conf.valueMode = i
                            }
                        }
                        Repeater {
                            model: sw.clock ? sw.clock.ringDefs : []
                            delegate: SRow {
                                required property var modelData
                                title: sw.clock.ringName(modelData)
                                desc: ({
                                    year:   sw.tr("Avance del año", "Progress through the year"),
                                    month:  sw.tr("Avance del mes", "Progress through the month"),
                                    week:   sw.tr("Avance de la semana (lun–dom)", "Progress through the week (Mon–Sun)"),
                                    day:    sw.tr("Avance del día o de la jornada", "Progress through the day or workday"),
                                    hour:   sw.tr("Avance de la hora", "Progress through the hour"),
                                    minute: sw.tr("Avance del minuto (segundero)", "Progress through the minute (seconds)")
                                })[modelData.key]
                                Swatch { key: modelData.col; opacity: sw.conf[modelData.show] ? 1 : 0.4 }
                                SliderCtl { key: modelData.op; sliderWidth: 150; enabled: sw.conf[modelData.show] }
                                Toggle { key: modelData.show; label: false }
                            }
                        }
                        SRow {
                            visible: !!sw.clock && !sw.clock.radial
                            title: sw.tr("Etiquetas de las barras", "Bar labels")
                            desc: sw.tr("Nombres y valores junto a cada barra.", "Names and values next to each bar.")
                            Swatch { key: "cLabels" }
                            SliderCtl { key: "oLabels"; sliderWidth: 150 }
                        }
                        SRow {
                            title: sw.tr("Movimiento suave", "Smooth motion")
                            desc: sw.tr("El anillo «Minuto» y el segundero avanzan de forma continua. Usa algo más de GPU.",
                                        "The Minute ring and the second hand move continuously. Uses a little more GPU.")
                            Toggle { key: "smooth" }
                        }
                    }

                    Expander {
                        key: "backdrop"
                        icon: ""
                        title: sw.tr("Fondo", "Background")
                        desc: sw.tr("Disco o rectángulo detrás del reloj para leerlo sobre cualquier fondo.",
                                    "A disc or panel behind the clock so it reads well on any wallpaper.")
                        SRow {
                            title: sw.tr("Mostrar fondo", "Show background")
                            Toggle { key: "showBackdrop" }
                        }
                        SRow {
                            enabled: sw.conf.showBackdrop
                            title: sw.tr("Color y transparencia", "Color and opacity")
                            Swatch { key: "cBack" }
                            SliderCtl { key: "backdropOpacity"; sliderWidth: 150 }
                        }
                    }

                    Expander {
                        key: "analog"
                        visible: !!sw.clock && sw.clock.analog
                        icon: ""
                        title: sw.tr("Reloj analógico", "Analog clock")
                        desc: sw.tr("Manecillas y marcas de la esfera.", "Hands and dial marks.")
                        SRow {
                            title: sw.tr("Segundero", "Second hand")
                            Toggle { key: "secondHand" }
                        }
                        SRow {
                            title: sw.tr("Manecillas de hora y minuto", "Hour and minute hands")
                            Swatch { key: "cHands" }
                            SliderCtl { key: "oHands"; sliderWidth: 150 }
                        }
                        SRow {
                            enabled: sw.conf.secondHand
                            title: sw.tr("Color del segundero", "Second hand color")
                            Swatch { key: "cSecond" }
                        }
                        SRow {
                            title: sw.tr("Marcas de la esfera", "Dial marks")
                            desc: sw.tr("Usan el color de la hora.", "They use the time color.")
                            SliderCtl { key: "oTicks"; sliderWidth: 150 }
                        }
                    }

                    // ================= Texto =================
                    CatHeader { key: "text"; text: sw.tr("Texto", "Text") }

                    Expander {
                        key: "textgeneral"
                        icon: ""
                        title: sw.tr("Texto central", "Center text")
                        desc: sw.tr("Tres líneas: hora, fecha y tiempo restante. Si una no cabe, continúa debajo.",
                                    "Three lines: time, date and time remaining. Long lines wrap below.")
                        SRow {
                            title: sw.tr("Mostrar texto", "Show text")
                            desc: sw.tr("Al pasar el ratón por un anillo, el centro muestra su nombre, porcentaje y lo que falta.",
                                        "Hovering a ring shows its name, percentage and time left in the center.")
                            Toggle { key: "showText" }
                        }
                        SRow {
                            enabled: sw.conf.showText
                            title: sw.tr("Mismo color para todo el texto", "Same color for all text")
                            desc: sw.tr("Copia el color de la hora a la fecha, el tiempo restante y las etiquetas de las barras. Cada uno se puede cambiar en su sección.",
                                        "Copies the time color to the date, time remaining and bar labels. Each one can be changed in its own section.")
                            Button {
                                text: sw.tr("Aplicar", "Apply")
                                onClicked: { sw.conf.cDate = sw.conf.cText; sw.conf.cSub = sw.conf.cText; sw.conf.cLabels = sw.conf.cText }
                            }
                        }
                        SRow {
                            enabled: sw.conf.showText
                            title: sw.tr("Tamaño del texto", "Text size")
                            SliderCtl { key: "textScale"; lo: 0.5; hi: 1.8 }
                        }
                    }

                    Expander {
                        key: "time"
                        icon: ""
                        title: sw.tr("Hora", "Time")
                        desc: sw.conf.showTime ? Logic.formatDate(sw.clock ? sw.clock.now : new Date(), sw.conf.timeFormat, ui.lang)
                                               : sw.tr("Oculta", "Hidden")
                        SRow {
                            title: sw.tr("Mostrar hora", "Show time")
                            Toggle { key: "showTime" }
                        }
                        FormatRow { key: "timeFormat"; presets: Logic.timePresets; enabled: sw.conf.showTime }
                        SRow {
                            enabled: sw.conf.showTime
                            title: sw.tr("Color y transparencia", "Color and opacity")
                            desc: sw.tr("Las marcas de la esfera analógica también usan este color.", "The analog dial marks use this color too.")
                            Swatch { key: "cText" }
                            SliderCtl { key: "oTime"; sliderWidth: 150 }
                        }
                    }

                    Expander {
                        key: "date"
                        icon: ""
                        title: sw.tr("Fecha", "Date")
                        desc: sw.conf.showDate ? Logic.formatDate(sw.clock ? sw.clock.now : new Date(), sw.conf.dateFormat, ui.lang).replace(/\n/g, " ")
                                               : sw.tr("Oculta", "Hidden")
                        SRow {
                            title: sw.tr("Mostrar fecha", "Show date")
                            Toggle { key: "showDate" }
                        }
                        FormatRow { key: "dateFormat"; presets: Logic.datePresetsFor(ui.lang); enabled: sw.conf.showDate }
                        SRow {
                            enabled: sw.conf.showDate
                            title: sw.tr("Color y transparencia", "Color and opacity")
                            Swatch { key: "cDate" }
                            SliderCtl { key: "oDate"; sliderWidth: 150 }
                        }
                    }

                    Expander {
                        key: "remaining"
                        icon: ""
                        title: sw.tr("Tiempo restante", "Time remaining")
                        desc: sw.conf.showSub && sw.clock ? Logic.daySubtitle(sw.clock.t.day, sw.conf.showSeconds, ui.lang)
                                                          : sw.tr("Oculto", "Hidden")
                        SRow {
                            title: sw.tr("Mostrar cuánto queda del día o de la jornada", "Show how much of the day or workday is left")
                            Toggle { key: "showSub" }
                        }
                        SRow {
                            enabled: sw.conf.showSub
                            title: sw.tr("Incluir segundos", "Include seconds")
                            desc: sw.tr("Sin segundos en ningún texto ni anillo «Minuto», el reloj se actualiza una vez por minuto.",
                                        "With no seconds anywhere and no Minute ring, the clock updates once a minute.")
                            Toggle { key: "showSeconds" }
                        }
                        SRow {
                            enabled: sw.conf.showSub
                            title: sw.tr("Color y transparencia", "Color and opacity")
                            Swatch { key: "cSub" }
                            SliderCtl { key: "oSub"; sliderWidth: 150 }
                        }
                    }

                    Expander {
                        key: "codes"
                        icon: ""
                        title: sw.tr("Códigos de formato", "Format codes")
                        desc: sw.tr("Letras que puedes usar en los formatos de hora y fecha.", "Letters you can use in time and date formats.")
                        WideRow {
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                textFormat: Text.StyledText
                                color: sw.cText
                                lineHeight: 1.3
                                text: ui.lang === "en"
? "<b>H</b> / <b>HH</b> hour 0–23 (8 / 08) · <b>h</b> / <b>hh</b> hour 1–12<br>" +
  "<b>m</b> / <b>mm</b> minutes · <b>s</b> / <b>ss</b> seconds · <b>A</b> AM/PM · <b>a</b> am/pm<br>" +
  "<b>d</b> / <b>dd</b> day (8 / 08) · <b>ddd</b> Mon · <b>dddd</b> Monday<br>" +
  "<b>M</b> / <b>MM</b> month (11) · <b>MMM</b> Nov · <b>MMMM</b> November<br>" +
  "<b>yy</b> year (26) · <b>yyyy</b> year (2026) · <b>Q</b> quarter<br>" +
  "<b>w</b> / <b>ww</b> ISO week · <b>D</b> / <b>DDD</b> day of the year<br>" +
  "<b>'text'</b> literal text · <b>''</b> a quote · <b>|</b> line break<br>" +
  "Example: <i>dddd, MMMM d | yyyy</i>"
: "<b>H</b> / <b>HH</b> hora 0–23 (8 / 08) · <b>h</b> / <b>hh</b> hora 1–12<br>" +
  "<b>m</b> / <b>mm</b> minutos · <b>s</b> / <b>ss</b> segundos · <b>A</b> AM/PM · <b>a</b> am/pm<br>" +
  "<b>d</b> / <b>dd</b> día (8 / 08) · <b>ddd</b> lun · <b>dddd</b> lunes<br>" +
  "<b>M</b> / <b>MM</b> mes (11) · <b>MMM</b> nov · <b>MMMM</b> noviembre<br>" +
  "<b>yy</b> año (26) · <b>yyyy</b> año (2026) · <b>Q</b> trimestre<br>" +
  "<b>w</b> / <b>ww</b> semana ISO · <b>D</b> / <b>DDD</b> día del año<br>" +
  "<b>'texto'</b> se escribe tal cual · <b>''</b> una comilla · <b>|</b> salto de línea<br>" +
  "Ejemplo: <i>dddd d 'de' MMMM | yyyy</i>"
                            }
                        }
                    }

                    // ================= Relojes y posición =================
                    CatHeader { key: "clocks"; text: sw.tr("Relojes y posición", "Clocks and position") }

                    Expander {
                        key: "clocklist"
                        icon: ""
                        title: sw.tr("Relojes", "Clocks")
                        desc: sw.clock && sw.app ? sw.tr("Estás editando el reloj ", "You are editing clock ") + sw.clock.number
                                                   + sw.tr(" de ", " of ") + sw.app.count : ""
                        SRow {
                            title: sw.tr("Añadir reloj para otro monitor", "Add a clock for another monitor")
                            desc: sw.tr("Copia la configuración de este reloj y lo coloca en el siguiente monitor. Cada reloj guarda sus propios ajustes.",
                                        "Copies this clock's settings and places it on the next monitor. Each clock keeps its own settings.")
                            Button { text: sw.tr("Añadir", "Add"); onClicked: sw.app.addClock(sw.clock) }
                        }
                        SRow {
                            title: sw.tr("Mostrar u ocultar este reloj", "Show or hide this clock")
                            Button {
                                text: sw.clock && sw.clock.visible ? sw.tr("Ocultar", "Hide") : sw.tr("Mostrar", "Show")
                                onClicked: sw.clock.visible = !sw.clock.visible
                            }
                        }
                        SRow {
                            title: sw.tr("Cerrar este reloj", "Close this clock")
                            desc: sw.tr("Lo elimina junto con sus ajustes. Siempre queda al menos uno.", "Removes it and its settings. At least one clock always remains.")
                            Button {
                                text: sw.tr("Cerrar", "Close")
                                enabled: !!sw.app && sw.app.count > 1
                                onClicked: sw.app.removeClock(sw.clock)
                            }
                        }
                    }

                    Expander {
                        key: "position"
                        icon: ""
                        title: sw.tr("Posición", "Position")
                        desc: sw.tr("Esquinas, bordes, centro u otro monitor. Funciona aunque la posición esté fijada.",
                                    "Corners, edges, center or another monitor. Works even when the position is locked.")
                        WideRow {
                            RowLayout {
                                spacing: 16
                                GridLayout {
                                    columns: 3
                                    rowSpacing: 4; columnSpacing: 4
                                    PosButton { text: "↖"; h: 0;   v: 0 }
                                    PosButton { text: "↑"; h: 0.5; v: 0 }
                                    PosButton { text: "↗"; h: 1;   v: 0 }
                                    PosButton { text: "←"; h: 0;   v: 0.5 }
                                    PosButton { text: "◉"; h: 0.5; v: 0.5 }
                                    PosButton { text: "→"; h: 1;   v: 0.5 }
                                    PosButton { text: "↙"; h: 0;   v: 1 }
                                    PosButton { text: "↓"; h: 0.5; v: 1 }
                                    PosButton { text: "↘"; h: 1;   v: 1 }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Button { text: sw.tr("Centrar en la pantalla", "Center on screen"); Layout.fillWidth: true; onClicked: sw.clock.centerOnScreen() }
                                    Button {
                                        text: sw.tr("Pasar al siguiente monitor", "Move to next monitor")
                                        Layout.fillWidth: true
                                        enabled: plat.screenCount() > 1
                                        onClicked: sw.clock.moveToNextScreen()
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        color: sw.cText2
                                        font.pixelSize: 12
                                        text: sw.tr("Usa el monitor donde está el reloj y respeta la barra de tareas.",
                                                    "Uses the monitor the clock is on and respects the taskbar.")
                                    }
                                }
                            }
                        }
                        SRow {
                            title: sw.tr("Distancia al borde", "Edge margin")
                            SliderCtl { key: "edgeGap"; lo: 0; hi: 300; step: 1; factor: 1; suffix: " px" }
                        }
                        SRow {
                            title: sw.tr("Mover poco a poco", "Nudge")
                            desc: sw.tr("Píxeles por clic.", "Pixels per click.")
                            Button { text: "◀"; implicitWidth: 38; onClicked: sw.clock.nudge(-sw.conf.nudgeStep, 0) }
                            Button { text: "▲"; implicitWidth: 38; onClicked: sw.clock.nudge(0, -sw.conf.nudgeStep) }
                            Button { text: "▼"; implicitWidth: 38; onClicked: sw.clock.nudge(0, sw.conf.nudgeStep) }
                            Button { text: "▶"; implicitWidth: 38; onClicked: sw.clock.nudge(sw.conf.nudgeStep, 0) }
                            SpinBox {
                                from: 1; to: 500; editable: true
                                value: sw.conf.nudgeStep
                                onValueModified: sw.conf.nudgeStep = value
                                Layout.preferredWidth: 100
                            }
                        }
                        SRow {
                            title: sw.tr("Coordenadas", "Coordinates")
                            desc: sw.tr("Esquina superior izquierda, en píxeles del escritorio.", "Top-left corner, in desktop pixels.")
                            Label { text: "X"; color: sw.cText2 }
                            SpinBox {
                                from: -20000; to: 20000; editable: true
                                Layout.preferredWidth: 110
                                value: sw.clock ? Math.round(sw.clock.x) : 0
                                onValueModified: { sw.clock.x = value; value = Qt.binding(() => Math.round(sw.clock.x)) }
                            }
                            Label { text: "Y"; color: sw.cText2 }
                            SpinBox {
                                from: -20000; to: 20000; editable: true
                                Layout.preferredWidth: 110
                                value: sw.clock ? Math.round(sw.clock.y) : 0
                                onValueModified: { sw.clock.y = value; value = Qt.binding(() => Math.round(sw.clock.y)) }
                            }
                        }
                    }

                    // ================= Comportamiento =================
                    CatHeader { key: "behavior"; text: sw.tr("Comportamiento", "Behavior") }

                    Expander {
                        key: "window"
                        icon: ""
                        title: sw.tr("Ventana", "Window")
                        desc: sw.tr("Capa, bloqueo, clics e inicio con Windows.", "Layering, locking, clicks and startup.")
                        SRow {
                            title: sw.tr("Siempre visible", "Always on top")
                            desc: sw.tr("Por encima de las demás ventanas (no sobre juegos en pantalla completa exclusiva).",
                                        "Above other windows (not over exclusive full-screen games).")
                            Toggle { key: "onTop" }
                        }
                        SRow {
                            title: sw.tr("Fijar posición y tamaño", "Lock position and size")
                            desc: sw.tr("Evita moverlo o redimensionarlo por accidente con el ratón.", "Prevents moving or resizing it by accident.")
                            Toggle { key: "locked" }
                        }
                        SRow {
                            title: sw.tr("Dejar pasar los clics", "Click-through")
                            desc: sw.tr("El reloj ignora el ratón. Para desactivarlo, usa el menú del icono de Arco en la bandeja del sistema.",
                                        "The clock ignores the mouse. To turn it off, use the Arco icon menu in the system tray.")
                            Toggle { key: "clickThrough" }
                        }
                        SRow {
                            visible: plat.autostartSupported()
                            title: sw.tr("Iniciar con Windows", "Start with Windows")
                            desc: plat.autostartForAll()
                                  ? sw.tr("Activado para todos los usuarios desde el instalador. Para quitarlo, desactívalo en Administrador de tareas → Aplicaciones de arranque.",
                                          "Turned on for all users by the installer. To turn it off, use Task Manager → Startup apps.")
                                  : sw.tr("Común a todos los relojes.", "Shared by all clocks.")
                            Toggle {
                                enabled: !plat.autostartForAll()
                                checked: plat.autostartEnabled()
                                onToggled: plat.setAutostart(checked)
                            }
                        }
                    }

                    Expander {
                        key: "workday"
                        icon: ""
                        title: sw.tr("Jornada laboral", "Workday")
                        desc: sw.conf.workMode ? Logic.fmtHM(sw.conf.workStart * 60) + " – " + Logic.fmtHM(sw.conf.workEnd * 60)
                                               : sw.tr("El anillo «Día» mide el día completo", "The Day ring tracks the whole day")
                        SRow {
                            title: sw.tr("El anillo «Día» mide solo mi jornada", "The Day ring tracks only my workday")
                            desc: sw.tr("Antes de empezar indica cuánto falta; al terminar, cuánto falta para la del día siguiente.",
                                        "Before it starts it shows how long until it begins; once it ends, how long until the next one.")
                            Toggle { key: "workMode" }
                        }
                        SRow {
                            enabled: sw.conf.workMode
                            title: sw.tr("Horario", "Hours")
                            desc: sw.conf.workMode && sw.conf.workEnd <= sw.conf.workStart
                                  ? sw.tr("La hora de fin debe ser posterior a la de inicio.", "The end time must be later than the start time.")
                                  : sw.tr("Flechas: ±30 min. También puedes escribir la hora (7:45, 7h45, 0745) y pulsar Enter.",
                                          "Arrows: ±30 min. You can also type a time (7:45, 7h45, 0745) and press Enter.")
                            TimeSpin { key: "workStart" }
                            Label { text: "–"; color: sw.cText2 }
                            TimeSpin { key: "workEnd" }
                        }
                    }

                    Expander {
                        key: "burnin"
                        icon: ""
                        title: sw.tr("Protección contra burn-in", "Burn-in protection")
                        desc: sw.tr("Desplaza el reloj unos píxeles de vez en cuando para cuidar pantallas OLED.",
                                    "Shifts the clock a few pixels from time to time to protect OLED screens.")
                        SRow {
                            title: sw.tr("Desplazar el reloj periódicamente", "Shift the clock periodically")
                            Toggle { key: "antiBurn" }
                        }
                        SRow {
                            enabled: sw.conf.antiBurn
                            title: sw.tr("Radio", "Radius")
                            SliderCtl { key: "burnRadius"; lo: 2; hi: 40; step: 1; factor: 1; suffix: " px" }
                        }
                        SRow {
                            enabled: sw.conf.antiBurn
                            title: sw.tr("Cada", "Every")
                            SliderCtl { key: "burnInterval"; lo: 30; hi: 900; step: 10; factor: 1; suffix: " s" }
                        }
                        SRow {
                            title: sw.tr("Atenuar a la mitad las pistas fijas", "Dim static tracks by half")
                            Toggle { key: "burnDimTracks" }
                        }
                    }

                    // ================= Sincronización =================
                    CatHeader { key: "syncCat"; text: sw.tr("Sincronización", "Sync") }

                    Expander {
                        key: "sync"
                        icon: ""
                        title: sw.tr("Configuración entre equipos", "Settings across devices")
                        desc: sync.status
                        SRow {
                            title: sw.tr("Método", "Method")
                            desc: sw.tr("La posición de los relojes no se sincroniza: depende de los monitores de cada equipo.",
                                        "Clock positions are not synced, since they depend on each device's monitors.")
                            ComboBox {
                                Layout.preferredWidth: 240
                                model: [sw.tr("Desactivada", "Off"),
                                        sw.tr("Cuenta de Google", "Google account"),
                                        sw.tr("Carpeta sincronizada", "Synced folder")]
                                currentIndex: ["off", "google", "folder"].indexOf(sync.mode)
                                onActivated: (i) => {
                                    const m = ["off", "google", "folder"][i]
                                    if (m === "folder" && sync.folder === "") folderDlg.open()
                                    else sync.setMode(m)
                                    currentIndex = Qt.binding(() => ["off", "google", "folder"].indexOf(sync.mode))
                                }
                            }
                        }
                        SRow {
                            visible: sync.mode === "google"
                            title: sync.account !== "" ? sw.tr("Conectado como ", "Signed in as ") + sync.account
                                                       : sw.tr("Cuenta de Google", "Google account")
                            desc: !sync.googleAvailable
                                  ? sw.tr("Esta versión no incluye acceso a Google. Usa una carpeta sincronizada.",
                                          "This build has no Google access. Use a synced folder instead.")
                                  : sw.tr("Arco solo puede ver su propia carpeta oculta en tu Drive, no tus archivos.",
                                          "Arco can only see its own hidden folder in your Drive, not your files.")
                            Button {
                                visible: sync.googleAvailable && sync.account === "" && !sync.loggingIn
                                text: sw.tr("Iniciar sesión con Google", "Sign in with Google")
                                onClicked: sync.login()
                            }
                            Button {
                                visible: sync.loggingIn
                                text: sw.tr("Cancelar", "Cancel")
                                onClicked: sync.cancelLogin()
                            }
                            Button {
                                visible: sync.account !== ""
                                text: sw.tr("Cerrar sesión", "Sign out")
                                onClicked: sync.logout()
                            }
                        }
                        SRow {
                            visible: sync.mode === "folder"
                            title: sw.tr("Carpeta", "Folder")
                            desc: sync.folder !== "" ? sync.folder : sw.tr("Ninguna carpeta elegida. Por ejemplo, una carpeta de Google Drive para escritorio, OneDrive o Dropbox.",
                                                                           "No folder chosen. For example, a Google Drive for desktop, OneDrive or Dropbox folder.")
                            Button { text: sw.tr("Elegir…", "Browse…"); onClicked: folderDlg.open() }
                        }
                        SRow {
                            enabled: sync.mode !== "off"
                            title: sw.tr("Igualar también el número de relojes", "Also match the number of clocks")
                            desc: sw.tr("Desactivado: cada equipo conserva sus relojes y recibe los ajustes en orden.",
                                        "Off: each device keeps its own clocks and receives settings in order.")
                            Toggle {
                                checked: sync.syncCount
                                onToggled: sync.setSyncCount(checked)
                            }
                        }
                        SRow {
                            enabled: sync.ready && !sync.busy
                            title: sw.tr("Sincronizar", "Sync")
                            desc: sw.tr("Es automático. «Subir» reemplaza lo guardado con este equipo; «Descargar» hace lo contrario.",
                                        "It's automatic. “Upload” replaces the saved copy with this device; “Download” does the opposite.")
                            Button { text: sw.tr("Ahora", "Now"); onClicked: sync.syncNow() }
                            Button { text: sw.tr("Subir", "Upload"); onClicked: sync.pushNow() }
                            Button { text: sw.tr("Descargar", "Download"); onClicked: sync.pullNow() }
                        }
                    }

                    // ================= Aplicación =================
                    CatHeader { key: "appCat"; text: sw.tr("Aplicación", "App") }

                    Expander {
                        key: "language"
                        icon: ""
                        title: sw.tr("Idioma y tema", "Language and theme")
                        desc: sw.tr("Comunes a todos los relojes.", "Shared by all clocks.")
                        SRow {
                            title: sw.tr("Idioma", "Language")
                            ComboBox {
                                Layout.preferredWidth: 200
                                model: ["Español", "English"]
                                currentIndex: ui.lang === "en" ? 1 : 0
                                onActivated: (i) => ui.setLang(i === 1 ? "en" : "es")
                            }
                        }
                        SRow {
                            title: sw.tr("Tema de la ventana de ajustes", "Settings window theme")
                            ComboBox {
                                Layout.preferredWidth: 200
                                model: [sw.tr("Según Windows", "Use system setting"), sw.tr("Claro", "Light"), sw.tr("Oscuro", "Dark")]
                                currentIndex: ["system", "light", "dark"].indexOf(ui.theme)
                                onActivated: (i) => ui.setTheme(["system", "light", "dark"][i])
                            }
                        }
                    }

                    Expander {
                        key: "about"
                        icon: ""
                        title: sw.tr("Ayuda", "Help")
                        desc: "Arco " + appVersion
                        WideRow {
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                textFormat: Text.StyledText
                                color: sw.cText
                                lineHeight: 1.3
                                text: ui.lang === "en"
? "<b>On the clock</b><br>" +
  "Drag: move · Wheel: size · Shift + wheel: opacity · Double-click: settings · Right-click: menu.<br>" +
  "Hover a ring to see its name, percentage and time left.<br><br>" +
  "<b>Tray icon</b> (next to the Windows clock)<br>" +
  "Click: show or hide all clocks. Right-click: settings for each clock, add clocks, make clocks clickable again, quit.<br><br>" +
  "<b>Several monitors</b><br>" +
  "Right-click a clock → New clock for another monitor. Each clock has its own settings.<br><br>" +
  "<b>Resource use</b><br>" +
  "Drawing runs on the GPU. Each clock updates once a second, or once a minute when it shows no seconds. Hidden clocks do no work."
: "<b>Sobre el reloj</b><br>" +
  "Arrastrar: mover · Rueda: tamaño · Mayús + rueda: transparencia · Doble clic: ajustes · Clic derecho: menú.<br>" +
  "Pasa el ratón por un anillo para ver su nombre, porcentaje y lo que falta.<br><br>" +
  "<b>Icono de la bandeja</b> (junto al reloj de Windows)<br>" +
  "Clic: mostrar u ocultar todos los relojes. Clic derecho: ajustes de cada reloj, añadir relojes, volver a recibir clics y salir.<br><br>" +
  "<b>Varios monitores</b><br>" +
  "Clic derecho sobre un reloj → Nuevo reloj para otro monitor. Cada reloj tiene sus propios ajustes.<br><br>" +
  "<b>Consumo</b><br>" +
  "El dibujo lo hace la GPU. Cada reloj se actualiza una vez por segundo, o una vez por minuto si no muestra segundos. Oculto no hace ningún trabajo."
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 24 }
                }
            }
        }
    }
}
