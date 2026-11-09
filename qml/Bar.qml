import QtQuick

// Una barra de progreso recta (estilos «Barras horizontales» y «Barras verticales»).
// La pista ocupa todo el recorrido; el relleno crece de izquierda a derecha o de abajo arriba.
Item {
    id: bar

    property real progress: 0
    property color color: "white"
    property real trackOpacity: 0.18
    property bool vertical: false
    property bool highlighted: false
    property real thickness: 8

    readonly property real p: Math.max(0, Math.min(1, progress))
    readonly property real th: thickness * (highlighted ? 1.3 : 1.0)

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    Item {
        id: lane
        width: bar.vertical ? bar.th : bar.width
        height: bar.vertical ? bar.height : bar.th
        anchors.centerIn: parent

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: bar.withAlpha(bar.color, bar.trackOpacity)
        }
        Rectangle {
            visible: bar.p > 0.001
            radius: Math.min(lane.width, lane.height) / 2
            color: bar.color
            width: bar.vertical ? lane.width : Math.max(lane.height, lane.width * bar.p)
            height: bar.vertical ? Math.max(lane.width, lane.height * bar.p) : lane.height
            y: bar.vertical ? lane.height - height : 0
        }
    }
}
