import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "clocklogic.js" as Logic

// Ajustes de un reloj. Un índice a la izquierda muestra una sola sección a la vez.
ApplicationWindow {
    id: sw
    property var conf
    property var clock
    property var app

    readonly property var pageNames: ["Relojes", "Anillos", "Estilo y tamaño", "Transparencias",
                                      "Texto y formato", "Jornada", "Posición", "Ventana",
                                      "Sincronización", "Burn-in", "Guía rápida"]
    readonly property int pageCount: pageNames.length
    readonly property int helpPage: 10

    title: "Arco · Ajustes" + (app && app.count > 1 && clock ? " · reloj " + clock.number : "")
    width: 700
    height: 620
    minimumWidth: 560
    minimumHeight: 360
    visible: false
    // Ventana normal e independiente del reloj: barra de título con mover, minimizar, maximizar y cerrar.
    transientParent: null
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
           | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint
           | (conf && conf.onTop ? Qt.WindowStaysOnTopHint : 0)

    palette.window: "#15161b"
    palette.windowText: "#e8e8ee"
    palette.base: "#1f2028"
    palette.alternateBase: "#262731"
    palette.text: "#e8e8ee"
    palette.button: "#262731"
    palette.buttonText: "#e8e8ee"
    palette.highlight: "#7c5cff"
    palette.highlightedText: "#ffffff"
    palette.mid: "#3a3b47"
    palette.light: "#3a3b47"
    palette.dark: "#0c0c10"
    palette.placeholderText: "#8a8a99"
    palette.toolTipBase: "#2a2b36"
    palette.toolTipText: "#f0f0f5"
    color: palette.window

    function openIt() {
        if (visibility === Window.Minimized) showNormal(); else show()
        raise(); requestActivate()
    }
    function showPage(i) { nav.currentIndex = Math.max(0, Math.min(pageCount - 1, i)) }
    function openHelp() { openIt(); showPage(helpPage) }

    ColorDialog {
        id: colorDlg
        property string key: ""
        title: "Elegir color"
        onAccepted: sw.conf[key] = selectedColor.toString()
    }
    FolderDialog {
        id: folderDlg
        title: "Carpeta para sincronizar la configuración"
        onAccepted: sync.setFolder(selectedFolder.toString())
    }

    function pickColor(key) {
        colorDlg.key = key
        colorDlg.selectedColor = conf[key]
        colorDlg.open()
    }

    // ---------- Componentes ----------
    component Section: Label {
        Layout.topMargin: 14
        font.bold: true
        font.pixelSize: 13
        color: "#b9a8ff"
    }

    // Ayuda discreta: un «?» pequeño y tenue. Al pasar el ratón muestra la explicación;
    // un clic la deja fija.
    component Help: Rectangle {
        id: hb
        property string tip: ""
        property bool pinned: false
        readonly property bool active: hbArea.containsMouse || pinned
        visible: tip !== ""
        implicitWidth: 14; implicitHeight: 14; radius: 7
        color: active ? "#7c5cff40" : "transparent"
        border.color: active ? "#7c5cffaa" : "#ffffff1f"
        Text {
            anchors.centerIn: parent
            text: "?"
            color: hb.active ? "#ffffff" : "#7d7d8c"
            font.pixelSize: 9
            font.bold: true
        }
        MouseArea {
            id: hbArea
            anchors.fill: parent
            anchors.margins: -4                    // zona de clic algo mayor que el dibujo
            hoverEnabled: true
            cursorShape: Qt.WhatsThisCursor
            onEntered: tt.open()
            onExited: if (!hb.pinned) tt.close()
            onClicked: { hb.pinned = !hb.pinned; if (hb.pinned) tt.open(); else tt.close() }
        }
        ToolTip {
            id: tt
            delay: 250
            x: -width + hb.width
            y: hb.height + 6
            width: Math.min(320, sw.width - 40)
            contentItem: Text {
                text: hb.tip
                wrapMode: Text.WordWrap
                color: "#f0f0f5"
                font.pixelSize: 12
                lineHeight: 1.15
            }
            background: Rectangle { color: "#2a2b36"; radius: 6; border.color: "#7c5cff80" }
            onClosed: hb.pinned = false
        }
    }

    component Swatch: Rectangle {
        property string key
        implicitWidth: 34; implicitHeight: 22; radius: 5
        color: sw.conf[key]
        border.color: "#ffffff40"
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.pickColor(parent.key) }
    }

    component SliderRow: RowLayout {
        property alias label: lbl.text
        property alias from: sl.from
        property alias to: sl.to
        property alias stepSize: sl.stepSize
        property string key
        property int decimals: 2
        property string suffix: ""
        property real factor: 1
        property string help: ""
        Layout.fillWidth: true
        Label { id: lbl; Layout.preferredWidth: 150; elide: Text.ElideRight }
        Slider {
            id: sl
            Layout.fillWidth: true
            value: sw.conf[parent.key]
            onMoved: sw.conf[parent.key] = value
        }
        Label {
            Layout.preferredWidth: 62
            horizontalAlignment: Text.AlignRight
            text: (sl.value * parent.factor).toFixed(parent.decimals) + parent.suffix
            opacity: 0.8
        }
        Help { tip: parent.help }
    }

    // Casilla con ayuda a la derecha
    component Opt: RowLayout {
        property string key
        property alias text: cb.text
        property string help: ""
        Layout.fillWidth: true
        CheckBox {
            id: cb
            Layout.fillWidth: true
            checked: sw.conf[parent.key]
            onToggled: sw.conf[parent.key] = checked
        }
        Help { tip: parent.help }
    }

    // Campo de formato con plantillas y vista previa
    component FormatRow: ColumnLayout {
        id: fr
        property string key
        property var presets: []
        Layout.fillWidth: true
        Layout.leftMargin: 28
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            TextField {
                Layout.fillWidth: true
                text: sw.conf[fr.key]
                selectByMouse: true
                placeholderText: "Escribe los códigos, p. ej. HH:mm"
                onTextEdited: sw.conf[fr.key] = text
            }
            ComboBox {
                Layout.preferredWidth: 150
                model: fr.presets
                displayText: "Plantillas"
                onActivated: (i) => sw.conf[fr.key] = fr.presets[i]
            }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.65
            font.pixelSize: 11
            text: "Vista previa: " + (sw.clock ? Logic.formatDate(sw.clock.now, sw.conf[fr.key]).replace(/\n/g, " ⏎ ") : "")
        }
    }

    // Hora de la jornada: flechas en pasos de 30 min o cualquier hora escrita a mano
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
        implicitWidth: 52; implicitHeight: 34
        font.pixelSize: 16
        onClicked: sw.clock.place(h, v)
    }

    // ---------- Estructura: índice + página ----------
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 176
            color: "#101116"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Label {
                    text: "Ajustes de Arco"
                    font.pixelSize: 15
                    font.bold: true
                }
                Label {
                    visible: sw.app && sw.app.count > 1
                    text: sw.clock ? "Reloj " + sw.clock.number + " de " + (sw.app ? sw.app.count : 1) : ""
                    opacity: 0.6
                    font.pixelSize: 11
                }
                ListView {
                    id: nav
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    clip: true
                    spacing: 1
                    currentIndex: 0
                    model: sw.pageNames
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ItemDelegate {
                        required property int index
                        required property string modelData
                        width: ListView.view.width
                        height: 32
                        text: modelData
                        font.pixelSize: 13
                        highlighted: ListView.isCurrentItem
                        onClicked: nav.currentIndex = index
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: "Cerrar"
                    onClicked: sw.hide()
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: nav.currentIndex

            // ===== 0 · Relojes =====
            SettingsPage {
                heading: "Relojes"
                intro: "Puedes tener un reloj en cada monitor. Cada uno guarda sus propios ajustes."

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: sw.clock && sw.app
                          ? "Estás editando el reloj " + sw.clock.number + " de " + sw.app.count + "."
                          : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "Añadir reloj para otro monitor"
                        Layout.fillWidth: true
                        onClicked: sw.app.addClock(sw.clock)
                    }
                    Help { tip: "Crea un reloj nuevo con la misma configuración que este y lo coloca en la misma posición del siguiente monitor. Si solo tienes un monitor, aparece un poco desplazado. Después puedes cambiar sus ajustes sin afectar a este." }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: sw.clock && sw.clock.visible ? "Ocultar este reloj" : "Mostrar este reloj"
                        Layout.fillWidth: true
                        onClicked: sw.clock.visible = !sw.clock.visible
                    }
                    Button {
                        text: "Cerrar este reloj"
                        Layout.fillWidth: true
                        enabled: sw.app && sw.app.count > 1
                        onClicked: sw.app.removeClock(sw.clock)
                    }
                    Help { tip: "«Cerrar este reloj» lo elimina junto con sus ajustes. Siempre queda al menos un reloj. Para ocultarlos todos usa el icono de la bandeja." }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: 11
                    text: "También puedes añadir o cerrar relojes con clic derecho sobre cualquiera de ellos. Desde el icono de la bandeja se abren los ajustes de cada reloj."
                }
            }

            // ===== 1 · Anillos =====
            SettingsPage {
                heading: "Anillos"
                intro: "Qué unidades de tiempo se muestran (de fuera hacia dentro, o de arriba abajo en las barras) y su color."

                Repeater {
                    model: sw.clock ? sw.clock.ringDefs : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        CheckBox {
                            text: modelData.name
                            Layout.preferredWidth: 110
                            checked: sw.conf[modelData.show]
                            onToggled: sw.conf[modelData.show] = checked
                        }
                        Swatch { key: modelData.col }
                        Label {
                            Layout.fillWidth: true
                            opacity: 0.6
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            text: ({ year: "avance del año", month: "avance del mes", week: "avance de la semana (lun–dom)",
                                     day: "avance del día o de la jornada", hour: "avance de la hora",
                                     minute: "avance del minuto (segundero)" })[modelData.key]
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Label { text: "Paleta"; Layout.preferredWidth: 110 }
                    ComboBox {
                        Layout.fillWidth: true
                        model: Logic.palettes.map(p => p.name)
                        currentIndex: sw.conf.paletteIndex
                        onActivated: (i) => {
                            const c = Logic.palettes[i].c
                            sw.conf.paletteIndex = i
                            sw.conf.cYear = c[0]; sw.conf.cMonth = c[1]; sw.conf.cWeek = c[2]
                            sw.conf.cDay = c[3]; sw.conf.cHour = c[4]; sw.conf.cMinute = c[5]
                        }
                    }
                    Help { tip: "Aplica un juego de colores a todos los anillos. Después puedes cambiar cada color por separado. «OLED tenue» usa colores menos brillantes para cuidar pantallas OLED." }
                }
                Help {
                    Layout.topMargin: 6
                    tip: "Cada anillo o barra muestra cuánto ha pasado de esa unidad de tiempo. La parte coloreada es lo transcurrido y la pista tenue es lo que queda. El cuadro de color abre el selector. La transparencia de cada uno está en «Transparencias»."
                }
            }

            // ===== 2 · Estilo y tamaño =====
            SettingsPage {
                heading: "Estilo y tamaño"

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Estilo"; Layout.preferredWidth: 150 }
                    ComboBox {
                        Layout.fillWidth: true
                        model: Logic.styles
                        currentIndex: sw.conf.style
                        onActivated: (i) => sw.conf.style = i
                    }
                    Help { tip: "Anillos: arcos gruesos con puntas redondeadas.\nSegmentos: cada anillo dividido en bloques.\nFino: líneas delgadas con un punto en la punta.\nNeón: arcos con halo luminoso.\nBloque: anillos anchos sin separación.\nBarras horizontales: una barra recta por unidad, con nombre y porcentaje.\nBarras verticales: columnas rectas una al lado de otra.\nAnalógico: esfera con manecillas y los anillos alrededor." }
                }
                SliderRow { label: "Tamaño"; key: "dialSize"; from: 90; to: 1800; stepSize: 2; decimals: 0; suffix: " px"
                            help: "Diámetro del reloj (o ancho de las barras), de 90 a 1800 px. También puedes cambiarlo con la rueda del ratón sobre el reloj; crece desde el centro." }
                SliderRow { label: "Grosor"; key: "thickScale"; from: 0.4; to: 1.6; factor: 100; decimals: 0; suffix: " %"
                            help: "Grosor de los anillos o las barras respecto al valor por defecto del estilo elegido." }
                SliderRow { label: "Radio del centro"; key: "centerRatio"; from: 0.15; to: 0.85; factor: 100; decimals: 0; suffix: " %"
                            help: "Tamaño del círculo central donde va la hora, respecto al radio del reloj. Más pequeño deja anillos más anchos; más grande da más espacio al texto o a la esfera analógica. En los estilos de barras ajusta el tamaño del bloque de texto." }
                SliderRow { label: "Tamaño del texto"; key: "textScale"; from: 0.5; to: 1.8; factor: 100; decimals: 0; suffix: " %"
                            help: "Escala del texto central respecto al espacio disponible. Si el texto no cabe en una línea, continúa en la de abajo." }
                SliderRow { label: "Pista de fondo"; key: "trackOpacity"; from: 0; to: 0.5; factor: 100; decimals: 0; suffix: " %"
                            help: "Intensidad del recorrido tenue que muestra lo que falta de cada anillo o barra. En 0 % solo se ve lo transcurrido." }
                RowLayout {
                    Layout.fillWidth: true
                    CheckBox {
                        text: "Fondo"
                        Layout.preferredWidth: 150
                        checked: sw.conf.showBackdrop
                        onToggled: sw.conf.showBackdrop = checked
                    }
                    Swatch { key: "cBack" }
                    Item { Layout.fillWidth: true }
                    Help { tip: "Disco (o rectángulo, en las barras) detrás del reloj para que se lea sobre cualquier fondo. Su transparencia está en «Transparencias»." }
                }
                Opt { key: "hoverReveal"; text: "Opacidad completa al pasar el ratón"
                      help: "Si el reloj está semitransparente, se vuelve totalmente visible mientras el ratón está encima." }

                Section { text: "Reloj analógico" }
                Opt { key: "secondHand"; text: "Mostrar segundero"
                      help: "Manecilla de los segundos en el estilo Analógico. Si la quitas y apagas el anillo «Minuto», el reloj se actualiza solo una vez por minuto." }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Manecillas"; Layout.preferredWidth: 150 }
                    Swatch { key: "cHands" }
                    Label { text: "Segundero"; Layout.leftMargin: 12 }
                    Swatch { key: "cSecond" }
                    Item { Layout.fillWidth: true }
                    Help { tip: "Colores de las manecillas de hora y minuto, y del segundero. Las marcas de la esfera usan el color del texto." }
                }
            }

            // ===== 3 · Transparencias =====
            SettingsPage {
                heading: "Transparencias"
                intro: "La opacidad general afecta a todo el reloj. Las demás se aplican a cada elemento por separado (100 % = opaco)."

                SliderRow { label: "General"; key: "contentOpacity"; from: 0.1; to: 1; factor: 100; decimals: 0; suffix: " %"
                            help: "Transparencia de todo el reloj. Atajo: Mayús + rueda del ratón sobre el reloj." }

                Section { text: "Anillos y barras" }
                Repeater {
                    model: sw.clock ? sw.clock.ringDefs : []
                    delegate: SliderRow {
                        required property var modelData
                        label: modelData.name
                        key: modelData.op
                        from: 0; to: 1; factor: 100; decimals: 0; suffix: " %"
                    }
                }
                SliderRow { label: "Pista de fondo"; key: "trackOpacity"; from: 0; to: 0.5; factor: 100; decimals: 0; suffix: " %"
                            help: "Intensidad del recorrido tenue de todos los anillos." }

                Section { text: "Texto" }
                SliderRow { label: "Hora"; key: "oTime"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %" }
                SliderRow { label: "Fecha"; key: "oDate"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %" }
                SliderRow { label: "Tiempo restante"; key: "oSub"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %" }
                SliderRow { label: "Etiquetas de barras"; key: "oLabels"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %"
                            help: "Nombres y porcentajes que acompañan a las barras horizontales y verticales." }

                Section { text: "Fondo y analógico" }
                SliderRow { label: "Fondo"; key: "backdropOpacity"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %"
                            help: "Opacidad del disco o rectángulo de fondo. Se activa en «Estilo y tamaño»." }
                SliderRow { label: "Marcas de la esfera"; key: "oTicks"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %" }
                SliderRow { label: "Manecillas"; key: "oHands"; from: 0; to: 1; factor: 100; decimals: 0; suffix: " %" }
            }

            // ===== 4 · Texto y formato =====
            SettingsPage {
                heading: "Texto y formato"
                intro: "El centro del reloj tiene tres líneas. La hora y la fecha usan códigos de formato; si el texto es largo, continúa en la línea de abajo."

                RowLayout {
                    Layout.fillWidth: true
                    CheckBox {
                        text: "Mostrar texto central"
                        Layout.fillWidth: true
                        checked: sw.conf.showText
                        onToggled: sw.conf.showText = checked
                    }
                    Label { text: "Color" }
                    Swatch { key: "cText" }
                    Help { tip: "Activa o desactiva todo el texto. Al pasar el ratón sobre un anillo, el centro muestra su nombre, el porcentaje y el tiempo restante." }
                }

                Section { text: "Línea 1 · hora" }
                Opt { key: "showTime"; text: "Mostrar"; enabled: sw.conf.showText }
                FormatRow { key: "timeFormat"; presets: Logic.timePresets; enabled: sw.conf.showText && sw.conf.showTime }

                Section { text: "Línea 2 · fecha" }
                Opt { key: "showDate"; text: "Mostrar"; enabled: sw.conf.showText }
                FormatRow { key: "dateFormat"; presets: Logic.datePresets; enabled: sw.conf.showText && sw.conf.showDate }

                Section { text: "Línea 3 · tiempo restante" }
                Opt { key: "showSub"; text: "Mostrar cuánto queda del día o de la jornada"; enabled: sw.conf.showText }
                Opt { key: "showSeconds"; text: "Incluir segundos en el tiempo restante"
                      help: "Muestra los segundos en «quedan…». Si no hay segundos en ningún texto ni anillo «Minuto», el reloj solo se actualiza una vez por minuto." }

                Section { text: "Códigos de formato" }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 12
                    lineHeight: 1.25
                    text:
"<b>H</b> / <b>HH</b> hora 0–23 (8 / 08) · <b>h</b> / <b>hh</b> hora 1–12<br>" +
"<b>m</b> / <b>mm</b> minutos · <b>s</b> / <b>ss</b> segundos<br>" +
"<b>A</b> AM/PM · <b>a</b> am/pm<br>" +
"<b>d</b> / <b>dd</b> día (8 / 08) · <b>ddd</b> lun · <b>dddd</b> lunes<br>" +
"<b>M</b> / <b>MM</b> mes (11) · <b>MMM</b> nov · <b>MMMM</b> noviembre<br>" +
"<b>yy</b> año (26) · <b>yyyy</b> año (2026) · <b>Q</b> trimestre<br>" +
"<b>w</b> / <b>ww</b> semana del año (ISO) · <b>D</b> / <b>DDD</b> día del año<br>" +
"<b>'texto'</b> se escribe tal cual · <b>''</b> una comilla · <b>|</b> salto de línea<br>" +
"Ejemplo: <i>dddd d 'de' MMMM | yyyy</i>"
                }
                Opt { key: "smooth"; text: "Movimiento suave del segundero"
                      help: "El anillo «Minuto» y el segundero analógico avanzan de forma continua en vez de a saltos de un segundo. Redibuja unas 30 veces por segundo, así que usa algo más de GPU." }
            }

            // ===== 5 · Jornada =====
            SettingsPage {
                heading: "Día o jornada"

                Opt { key: "workMode"; text: "El anillo «Día» mide solo mi jornada"
                      help: "En lugar de las 24 horas, el anillo «Día» va de la hora de inicio a la de fin. Antes de empezar indica cuánto falta; después muestra «jornada terminada»." }
                RowLayout {
                    enabled: sw.conf.workMode
                    Label { text: "Desde"; Layout.preferredWidth: 60 }
                    TimeSpin { key: "workStart" }
                    Label { text: "hasta"; Layout.leftMargin: 8 }
                    TimeSpin { key: "workEnd" }
                    Help { tip: "Usa las flechas para cambiar en pasos de 30 minutos, o escribe cualquier hora: 7:45, 7.45, 7h45 o 0745. Pulsa Enter o cambia de campo para aplicarla. Formato de 24 h; 24:00 es medianoche." }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: 11
                    color: sw.conf.workMode && sw.conf.workEnd <= sw.conf.workStart ? "#ff8a8a" : palette.windowText
                    text: sw.conf.workMode && sw.conf.workEnd <= sw.conf.workStart
                          ? "La hora de fin debe ser posterior a la de inicio; mientras tanto el anillo mide el día completo."
                          : "Escribe la hora exacta o usa las flechas (±30 min)."
                }
            }

            // ===== 6 · Posición =====
            SettingsPage {
                heading: "Posición"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    GridLayout {
                        columns: 3
                        rowSpacing: 4; columnSpacing: 4
                        PosButton { text: "↖"; h: 0;   v: 0;   ToolTip.text: "Arriba a la izquierda"; ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "↑"; h: 0.5; v: 0;   ToolTip.text: "Arriba al centro";      ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "↗"; h: 1;   v: 0;   ToolTip.text: "Arriba a la derecha";   ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "←"; h: 0;   v: 0.5; ToolTip.text: "Centro a la izquierda"; ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "◉"; h: 0.5; v: 0.5; ToolTip.text: "Centrar en la pantalla"; ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "→"; h: 1;   v: 0.5; ToolTip.text: "Centro a la derecha";   ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "↙"; h: 0;   v: 1;   ToolTip.text: "Abajo a la izquierda";  ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "↓"; h: 0.5; v: 1;   ToolTip.text: "Abajo al centro";       ToolTip.visible: hovered; ToolTip.delay: 400 }
                        PosButton { text: "↘"; h: 1;   v: 1;   ToolTip.text: "Abajo a la derecha";    ToolTip.visible: hovered; ToolTip.delay: 400 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Button { text: "Centrar en la pantalla"; Layout.fillWidth: true; onClicked: sw.clock.centerOnScreen() }
                        Button {
                            text: "Pasar al siguiente monitor"
                            Layout.fillWidth: true
                            enabled: plat.screenCount() > 1
                            onClicked: sw.clock.moveToNextScreen()
                        }
                        Label {
                            text: "Los botones usan el monitor donde está el reloj y respetan la barra de tareas."
                            wrapMode: Text.WordWrap; Layout.fillWidth: true; opacity: 0.6; font.pixelSize: 11
                        }
                    }
                    Help { Layout.alignment: Qt.AlignTop; tip: "La cuadrícula lleva el reloj a una esquina, a un borde o al centro del monitor actual. «Pasar al siguiente monitor» lo mueve a la misma posición relativa en la otra pantalla. Estos botones funcionan aunque la posición esté fijada." }
                }
                SliderRow { label: "Distancia al borde"; key: "edgeGap"; from: 0; to: 300; stepSize: 1; decimals: 0; suffix: " px"
                            help: "Separación que dejan los botones de posición entre el reloj y el borde de la pantalla." }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Mover poco a poco"; Layout.preferredWidth: 150 }
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
                    Label { text: "px" }
                    Item { Layout.fillWidth: true }
                    Help { tip: "Desplaza el reloj en pasos exactos. El número indica cuántos píxeles se mueve en cada clic." }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Coordenadas"; Layout.preferredWidth: 150 }
                    Label { text: "X" }
                    SpinBox {
                        from: -20000; to: 20000; editable: true
                        Layout.preferredWidth: 110
                        value: sw.clock ? Math.round(sw.clock.x) : 0
                        onValueModified: { sw.clock.x = value; value = Qt.binding(() => Math.round(sw.clock.x)) }
                    }
                    Label { text: "Y" }
                    SpinBox {
                        from: -20000; to: 20000; editable: true
                        Layout.preferredWidth: 110
                        value: sw.clock ? Math.round(sw.clock.y) : 0
                        onValueModified: { sw.clock.y = value; value = Qt.binding(() => Math.round(sw.clock.y)) }
                    }
                    Item { Layout.fillWidth: true }
                    Help { tip: "Posición exacta de la esquina superior izquierda del reloj, en píxeles del escritorio. Con varios monitores, los valores pueden ser negativos." }
                }
            }

            // ===== 7 · Ventana =====
            SettingsPage {
                heading: "Ventana"

                Opt { key: "onTop"; text: "Siempre visible"
                      help: "Mantiene el reloj por encima de las demás ventanas. Windows no permite superponerlo a juegos en pantalla completa exclusiva." }
                Opt { key: "locked"; text: "Fijar posición y tamaño"
                      help: "Evita moverlo o cambiar su tamaño por accidente con el ratón. Los botones de posición de esta ventana siguen funcionando." }
                Opt { key: "clickThrough"; text: "Dejar pasar los clics"
                      help: "El reloj ignora el ratón: los clics llegan a la ventana de abajo. Para desactivarlo, usa el icono de Arco en la bandeja del sistema (junto al reloj de Windows)." }
                RowLayout {
                    visible: plat.autostartSupported()
                    Layout.fillWidth: true
                    CheckBox {
                        text: "Iniciar con Windows"
                        Layout.fillWidth: true
                        checked: plat.autostartEnabled()
                        onToggled: plat.setAutostart(checked)
                    }
                    Help { tip: "Abre Arco automáticamente al iniciar sesión en Windows, con todos tus relojes. Es un ajuste común a todos los relojes." }
                }
            }

            // ===== 8 · Sincronización =====
            SettingsPage {
                heading: "Sincronización"
                intro: "Usa la misma configuración en varios equipos. La posición de cada reloj no se sincroniza, porque depende de los monitores de cada equipo."

                RadioButton {
                    text: "Desactivada"
                    checked: sync.mode === "off"
                    onClicked: { sync.setMode("off"); checked = Qt.binding(() => sync.mode === "off") }
                }

                RowLayout {
                    Layout.fillWidth: true
                    RadioButton {
                        text: "Cuenta de Google"
                        Layout.fillWidth: true
                        enabled: sync.googleAvailable
                        autoExclusive: false
                        checked: sync.mode === "google"
                        onClicked: { sync.setMode("google"); checked = Qt.binding(() => sync.mode === "google") }
                    }
                    Help { tip: "Guarda la configuración en una carpeta oculta de tu Google Drive que solo Arco puede ver. Arco no tiene acceso a tus demás archivos. Inicia sesión con la misma cuenta en cada equipo." }
                }
                ColumnLayout {
                    visible: sync.mode === "google"
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: sync.account !== "" ? "Conectado como " + sync.account : "No has iniciado sesión."
                    }
                    RowLayout {
                        Button {
                            visible: sync.account === "" && !sync.loggingIn
                            text: "Iniciar sesión con Google"
                            onClicked: sync.login()
                        }
                        Button {
                            visible: sync.loggingIn
                            text: "Cancelar inicio de sesión"
                            onClicked: sync.cancelLogin()
                        }
                        Button {
                            visible: sync.account !== ""
                            text: "Cerrar sesión"
                            onClicked: sync.logout()
                        }
                    }
                }
                Label {
                    visible: !sync.googleAvailable
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: 11
                    text: "Esta versión no incluye acceso a Google. Puedes usar una carpeta de Google Drive para escritorio con la opción de abajo."
                }

                RowLayout {
                    Layout.fillWidth: true
                    RadioButton {
                        text: "Carpeta sincronizada"
                        Layout.fillWidth: true
                        autoExclusive: false
                        checked: sync.mode === "folder"
                        onClicked: {
                            if (sync.folder !== "") sync.setMode("folder"); else folderDlg.open()
                            checked = Qt.binding(() => sync.mode === "folder")
                        }
                    }
                    Help { tip: "Guarda la configuración en una carpeta que otro programa mantiene sincronizada: Google Drive para escritorio, OneDrive, Dropbox… Elige la misma carpeta en cada equipo. No necesita iniciar sesión en Arco." }
                }
                RowLayout {
                    visible: sync.mode === "folder"
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        text: sync.folder
                        placeholderText: "Ninguna carpeta elegida"
                    }
                    Button { text: "Elegir…"; onClicked: folderDlg.open() }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    enabled: sync.mode !== "off"
                    CheckBox {
                        Layout.fillWidth: true
                        text: "Igualar también el número de relojes"
                        checked: sync.syncCount
                        onToggled: sync.setSyncCount(checked)
                    }
                    Help { tip: "Desactivado: cada equipo conserva sus relojes y recibe los ajustes en orden (el reloj 1 con el reloj 1, etc.). Activado: si otro equipo tiene más relojes, aquí se crean los que falten, y si tiene menos, se cierran los que sobran." }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    enabled: sync.ready && !sync.busy
                    Button { text: "Sincronizar ahora"; onClicked: sync.syncNow() }
                    Button { text: "Subir este equipo"; onClicked: sync.pushNow() }
                    Button { text: "Descargar"; onClicked: sync.pullNow() }
                    Item { Layout.fillWidth: true }
                    Help { tip: "La sincronización es automática: los cambios se suben unos segundos después y se comprueba la nube cada pocos minutos. Si dos equipos cambian a la vez, gana el cambio más reciente. «Subir este equipo» reemplaza lo guardado por la configuración de aquí; «Descargar» hace lo contrario." }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    font.pixelSize: 11
                    text: sync.status
                }
            }

            // ===== 9 · Burn-in =====
            SettingsPage {
                heading: "Protección contra burn-in"

                Opt { key: "antiBurn"; text: "Desplazar el reloj periódicamente"
                      help: "Mueve el reloj unos píxeles cada cierto tiempo (pixel shift), con una transición suave y sin repetir posición en ciclos cortos. Así ningún píxel queda encendido siempre con el mismo color." }
                SliderRow { label: "Radio"; key: "burnRadius"; from: 2; to: 40; stepSize: 1; decimals: 0; suffix: " px"; enabled: sw.conf.antiBurn
                            help: "Distancia máxima que se aleja el reloj de su posición. 6–12 px suele bastar." }
                SliderRow { label: "Cada"; key: "burnInterval"; from: 30; to: 900; stepSize: 10; decimals: 0; suffix: " s"; enabled: sw.conf.antiBurn
                            help: "Cada cuántos segundos se desplaza." }
                Opt { key: "burnDimTracks"; text: "Atenuar a la mitad las pistas fijas"
                      help: "Las pistas de fondo son la parte que menos cambia. Atenuarlas reduce el riesgo de marcas en pantallas OLED." }
            }

            // ===== 10 · Guía rápida =====
            SettingsPage {
                heading: "Guía rápida"

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    lineHeight: 1.2
                    text:
"<b>Con el ratón sobre el reloj</b><br>" +
"• Arrastrar: mover.<br>" +
"• Rueda: cambiar tamaño (90–1800 px).<br>" +
"• Mayús + rueda: cambiar opacidad.<br>" +
"• Doble clic: abrir los ajustes de ese reloj.<br>" +
"• Clic derecho: menú del reloj.<br>" +
"• Pasar por un anillo: el centro muestra su nombre, % y tiempo restante.<br><br>" +
"<b>Varios monitores</b><br>" +
"Clic derecho → <b>Nuevo reloj para otro monitor</b> crea una copia con la misma configuración en la pantalla siguiente. Cada reloj tiene sus propios ajustes y se puede cerrar por separado.<br><br>" +
"<b>Menú del reloj (clic derecho)</b><br>" +
"• <b>Ocultar este reloj</b>, <b>Ajustes…</b> y <b>Ayuda</b>.<br>" +
"• <b>Nuevo reloj</b> / <b>Cerrar este reloj</b>.<br>" +
"• <b>Posición</b>: centrar, esquinas, bordes o pasar al siguiente monitor.<br>" +
"• <b>Siempre visible</b>, <b>Fijar posición</b>, <b>Dejar pasar los clics</b> y <b>Anti burn-in</b>.<br>" +
"• <b>Estilo</b>: Anillos, Segmentos, Fino, Neón, Bloque, Barras horizontales, Barras verticales o Analógico.<br><br>" +
"<b>Sincronización</b><br>" +
"En «Sincronización» puedes compartir la configuración entre equipos con tu cuenta de Google o con una carpeta sincronizada. La posición de los relojes no se comparte.<br><br>" +
"<b>Icono de la bandeja</b><br>" +
"Un clic muestra u oculta todos los relojes. Su menú permite añadir relojes, abrir los ajustes de cada uno, volver a recibir clics y salir. Está junto al reloj de Windows; si no aparece, búscalo en la flecha «^» de iconos ocultos.<br><br>" +
"<b>Qué mide cada anillo</b><br>" +
"Año, Mes, Semana, Día (o jornada), Hora y Minuto. La parte coloreada es lo transcurrido y la pista tenue lo que queda. El anillo Minuto es el segundero.<br><br>" +
"<b>Consumo</b><br>" +
"El dibujo lo hace la GPU. Cada reloj se actualiza una vez por segundo, o una vez por minuto si no muestra segundos. Oculto no hace ningún trabajo."
                }
            }
        }
    }
}
