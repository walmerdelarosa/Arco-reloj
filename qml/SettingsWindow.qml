import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "clocklogic.js" as Logic

ApplicationWindow {
    id: sw
    property var conf
    property var clock

    title: "Arco · Ajustes"
    width: 500
    height: 760
    minimumWidth: 430
    minimumHeight: 300
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
    function openHelp() { openIt(); helpPopup.open() }

    ColorDialog {
        id: colorDlg
        property string key: ""
        title: "Elegir color"
        onAccepted: sw.conf[key] = selectedColor.toString()
    }
    function pickColor(key) {
        colorDlg.key = key
        colorDlg.selectedColor = conf[key]
        colorDlg.open()
    }

    // ---------- Componentes ----------
    component Section: Label {
        Layout.topMargin: 16
        font.bold: true
        font.pixelSize: 13
        color: "#b9a8ff"
    }

    // Botón «?»: muestra la explicación al pasar el ratón; un clic la deja fija.
    component Help: Rectangle {
        id: hb
        property string tip: ""
        property bool pinned: false
        visible: tip !== ""
        implicitWidth: 20; implicitHeight: 20; radius: 10
        color: hbArea.containsMouse || pinned ? "#7c5cff" : "#2e2f3b"
        border.color: "#ffffff30"
        Text { anchors.centerIn: parent; text: "?"; color: "white"; font.bold: true; font.pixelSize: 12 }
        MouseArea {
            id: hbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.WhatsThisCursor
            onEntered: tt.open()
            onExited: if (!hb.pinned) tt.close()
            onClicked: { hb.pinned = !hb.pinned; if (hb.pinned) tt.open(); else tt.close() }
        }
        ToolTip {
            id: tt
            delay: 200
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
        Label { id: lbl; Layout.preferredWidth: 150 }
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

    component PosButton: Button {
        property real h
        property real v
        implicitWidth: 52; implicitHeight: 34
        font.pixelSize: 16
        onClicked: sw.clock.place(h, v)
    }

    // ---------- Contenido ----------
    ScrollView {
        id: scroller
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroller.availableWidth - 32
            x: 16
            spacing: 6

            RowLayout {
                Layout.topMargin: 12
                Layout.fillWidth: true
                Label { text: "Ajustes de Arco"; font.pixelSize: 17; font.bold: true; Layout.fillWidth: true }
                Button { text: "Guía rápida"; onClicked: helpPopup.open() }
            }
            Label {
                text: "Pasa el ratón por los botones «?» para ver qué hace cada opción. Haz clic en uno para dejar la ayuda abierta."
                wrapMode: Text.WordWrap; Layout.fillWidth: true; opacity: 0.6; font.pixelSize: 11
            }

            // ----- Anillos -----
            RowLayout {
                Section { text: "Anillos (de fuera hacia dentro)"; Layout.fillWidth: true }
                Help {
                    Layout.topMargin: 16
                    tip: "Cada anillo muestra cuánto ha pasado de esa unidad de tiempo. La parte coloreada es lo transcurrido y la pista tenue es lo que queda. Marca o desmarca para mostrar u ocultar; el cuadro de color abre el selector."
                }
            }
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
                Label { text: "Paleta"; Layout.preferredWidth: 150 }
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

            // ----- Estilo y tamaño -----
            Section { text: "Estilo y tamaño" }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Estilo"; Layout.preferredWidth: 150 }
                ComboBox {
                    Layout.fillWidth: true
                    model: Logic.styles
                    currentIndex: sw.conf.style
                    onActivated: (i) => sw.conf.style = i
                }
                Help { tip: "Anillos: arcos gruesos con puntas redondeadas.\nSegmentos: cada anillo dividido en bloques (meses, días, horas, segundos).\nFino: líneas delgadas con un punto en la punta.\nNeón: arcos con halo luminoso.\nBloque: anillos anchos sin separación." }
            }
            SliderRow { label: "Tamaño"; key: "dialSize"; from: 90; to: 1800; stepSize: 2; decimals: 0; suffix: " px"
                        help: "Diámetro del reloj, de 90 a 1800 px. También puedes cambiarlo con la rueda del ratón sobre el reloj; crece desde el centro." }
            SliderRow { label: "Opacidad"; key: "contentOpacity"; from: 0.1; to: 1; factor: 100; decimals: 0; suffix: " %"
                        help: "Transparencia general del reloj. Atajo: Mayús + rueda del ratón sobre el reloj." }
            SliderRow { label: "Grosor"; key: "thickScale"; from: 0.4; to: 1.6; factor: 100; decimals: 0; suffix: " %"
                        help: "Grosor de los anillos respecto al valor por defecto del estilo elegido." }
            SliderRow { label: "Pista de fondo"; key: "trackOpacity"; from: 0; to: 0.5; factor: 100; decimals: 0; suffix: " %"
                        help: "Intensidad del recorrido tenue que muestra lo que falta de cada anillo. En 0 % solo se ve lo transcurrido." }
            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    text: "Disco de fondo"
                    Layout.preferredWidth: 150
                    checked: sw.conf.showBackdrop
                    onToggled: sw.conf.showBackdrop = checked
                }
                Swatch { key: "cBack" }
                Slider {
                    Layout.fillWidth: true; from: 0; to: 1
                    enabled: sw.conf.showBackdrop
                    value: sw.conf.backdropOpacity
                    onMoved: sw.conf.backdropOpacity = value
                }
                Help { tip: "Círculo detrás de los anillos para que se lean sobre cualquier fondo. Elige su color y con la barra su opacidad." }
            }
            Opt { key: "hoverReveal"; text: "Opacidad completa al pasar el ratón"
                  help: "Si el reloj está semitransparente, se vuelve totalmente visible mientras el ratón está encima." }

            // ----- Posición -----
            Section { text: "Posición" }
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
                    id: spinX
                    from: -20000; to: 20000; editable: true
                    Layout.preferredWidth: 110
                    value: sw.clock ? Math.round(sw.clock.x) : 0
                    onValueModified: { sw.clock.x = value; value = Qt.binding(() => Math.round(sw.clock.x)) }
                }
                Label { text: "Y" }
                SpinBox {
                    id: spinY
                    from: -20000; to: 20000; editable: true
                    Layout.preferredWidth: 110
                    value: sw.clock ? Math.round(sw.clock.y) : 0
                    onValueModified: { sw.clock.y = value; value = Qt.binding(() => Math.round(sw.clock.y)) }
                }
                Item { Layout.fillWidth: true }
                Help { tip: "Posición exacta de la esquina superior izquierda del reloj, en píxeles del escritorio. Con varios monitores, los valores pueden ser negativos." }
            }

            // ----- Texto central -----
            Section { text: "Texto central" }
            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    text: "Mostrar hora y tiempo restante"
                    Layout.fillWidth: true
                    checked: sw.conf.showText
                    onToggled: sw.conf.showText = checked
                }
                Label { text: "Color" }
                Swatch { key: "cText" }
                Help { tip: "Muestra la hora en el centro y, debajo, cuánto queda del día o de la jornada. Al pasar el ratón sobre un anillo, el centro muestra su nombre, el porcentaje y el tiempo restante." }
            }
            Opt { key: "showSeconds"; text: "Mostrar segundos"
                  help: "Añade los segundos a la hora y al tiempo restante. Si lo desactivas junto con el anillo «Minuto», el reloj solo se actualiza una vez por minuto." }
            Opt { key: "h12"; text: "Formato 12 h"; help: "Muestra la hora de 1 a 12 en lugar de 0 a 23." }
            Opt { key: "smooth"; text: "Movimiento suave del segundero"
                  help: "El anillo «Minuto» avanza de forma continua en vez de a saltos de un segundo. Redibuja unas 30 veces por segundo, así que usa algo más de GPU." }

            // ----- Día o jornada -----
            Section { text: "Día o jornada" }
            Opt { key: "workMode"; text: "El anillo «Día» mide solo mi jornada"
                  help: "En lugar de las 24 horas, el anillo «Día» va de la hora de inicio a la de fin. Antes de empezar indica cuánto falta; después muestra «jornada terminada»." }
            RowLayout {
                enabled: sw.conf.workMode
                Label { text: "Desde"; Layout.preferredWidth: 60 }
                SpinBox {
                    from: 0; to: 48; stepSize: 1
                    value: Math.round(sw.conf.workStart * 2)
                    textFromValue: (v) => Logic.pad(Math.floor(v / 2)) + ":" + (v % 2 ? "30" : "00")
                    valueFromText: (t) => { const p = t.split(":"); return parseInt(p[0]) * 2 + (parseInt(p[1]) >= 30 ? 1 : 0) }
                    onValueModified: sw.conf.workStart = value / 2
                }
                Label { text: "hasta" }
                SpinBox {
                    from: 0; to: 48; stepSize: 1
                    value: Math.round(sw.conf.workEnd * 2)
                    textFromValue: (v) => Logic.pad(Math.floor(v / 2)) + ":" + (v % 2 ? "30" : "00")
                    valueFromText: (t) => { const p = t.split(":"); return parseInt(p[0]) * 2 + (parseInt(p[1]) >= 30 ? 1 : 0) }
                    onValueModified: sw.conf.workEnd = value / 2
                }
            }

            // ----- Ventana -----
            Section { text: "Ventana" }
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
                Help { tip: "Abre Arco automáticamente al iniciar sesión en Windows." }
            }

            // ----- Burn-in -----
            Section { text: "Protección contra burn-in" }
            Opt { key: "antiBurn"; text: "Desplazar el reloj periódicamente"
                  help: "Mueve el reloj unos píxeles cada cierto tiempo (pixel shift), con una transición suave y sin repetir posición en ciclos cortos. Así ningún píxel queda encendido siempre con el mismo color." }
            SliderRow { label: "Radio"; key: "burnRadius"; from: 2; to: 40; stepSize: 1; decimals: 0; suffix: " px"; enabled: sw.conf.antiBurn
                        help: "Distancia máxima que se aleja el reloj de su posición. 6–12 px suele bastar." }
            SliderRow { label: "Cada"; key: "burnInterval"; from: 30; to: 900; stepSize: 10; decimals: 0; suffix: " s"; enabled: sw.conf.antiBurn
                        help: "Cada cuántos segundos se desplaza." }
            Opt { key: "burnDimTracks"; text: "Atenuar a la mitad las pistas fijas"
                  help: "Las pistas de fondo son la parte que menos cambia. Atenuarlas reduce el riesgo de marcas en pantallas OLED." }

            RowLayout {
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: "Cerrar"; onClicked: sw.hide() }
            }
        }
    }

    // ---------- Guía rápida ----------
    Popup {
        id: helpPopup
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(sw.width - 32, 460)
        height: Math.min(sw.height - 32, 620)
        padding: 0
        background: Rectangle { color: "#1c1d24"; radius: 10; border.color: "#7c5cff80" }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Guía rápida"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                Button { text: "✕"; flat: true; onClicked: helpPopup.close() }
            }
            ScrollView {
                id: helpScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                Label {
                    width: helpScroll.availableWidth
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    lineHeight: 1.2
                    text:
"<b>Con el ratón sobre el reloj</b><br>" +
"• Arrastrar: mover.<br>" +
"• Rueda: cambiar tamaño (90–1800 px).<br>" +
"• Mayús + rueda: cambiar opacidad.<br>" +
"• Doble clic: abrir estos ajustes.<br>" +
"• Clic derecho: menú.<br>" +
"• Pasar por un anillo: el centro muestra su nombre, % y tiempo restante.<br><br>" +
"<b>Menú (clic derecho o icono de la bandeja)</b><br>" +
"• <b>Ocultar / Mostrar reloj</b>: lo esconde sin cerrar la app. Un clic en el icono de la bandeja hace lo mismo.<br>" +
"• <b>Ajustes…</b>: abre esta ventana.<br>" +
"• <b>Ayuda</b>: abre esta guía.<br>" +
"• <b>Posición</b>: centrar, esquinas, bordes o pasar al siguiente monitor.<br>" +
"• <b>Siempre visible</b>: lo mantiene encima de las demás ventanas.<br>" +
"• <b>Fijar posición</b>: bloquea mover y redimensionar con el ratón.<br>" +
"• <b>Dejar pasar los clics</b>: el reloj ignora el ratón. Desactívalo desde el icono de la bandeja.<br>" +
"• <b>Anti burn-in</b>: activa o desactiva el desplazamiento periódico.<br>" +
"• <b>Estilo</b>: Anillos, Segmentos, Fino, Neón o Bloque.<br>" +
"• <b>Salir</b>: cierra Arco por completo.<br><br>" +
"<b>Qué mide cada anillo</b> (de fuera hacia dentro)<br>" +
"Año, Mes, Semana, Día (o jornada), Hora y Minuto. La parte coloreada es lo transcurrido y la pista tenue lo que queda. El anillo Minuto es el segundero.<br><br>" +
"<b>Consumo</b><br>" +
"El dibujo lo hace la GPU. La app se actualiza una vez por segundo, o una vez por minuto si apagas el anillo Minuto y los segundos. Oculta no hace ningún trabajo.<br><br>" +
"<b>¿Dónde está el icono de la bandeja?</b><br>" +
"Junto al reloj de Windows, abajo a la derecha. Si no aparece, búscalo en la flecha «^» de iconos ocultos."
                }
            }
        }
    }
}
