import QtQuick
import QtQuick.Shapes

// Un anillo de progreso. Se dibuja con Qt Quick Shapes: la curva se rasteriza en la GPU
// (CurveRenderer) y solo se recalcula la geometría cuando cambia el progreso.
Item {
    id: ring

    property real radius: 50
    property real thickness: 10
    property color color: "white"
    property real progress: 0
    property int segments: 12
    property int style: 0            // 0 Anillos, 1 Segmentos, 2 Fino, 3 Neón, 4 Bloque
    property real trackOpacity: 0.18
    property bool highlighted: false

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property bool segmented: style === 1
    readonly property bool roundCaps: style === 0 || style === 3
    readonly property real w: thickness * (highlighted ? 1.18 : 1.0)
    readonly property real sweep: 360 * Math.max(0, Math.min(1, progress))
    readonly property real segLen: 2 * Math.PI * radius / Math.max(1, segments)
    // dashPattern se expresa en múltiplos del grosor del trazo
    readonly property var dash: [segLen * 0.74 / Math.max(0.5, w), segLen * 0.26 / Math.max(0.5, w)]

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Halo del estilo Neón: un trazo ancho y translúcido debajo del principal
    Shape {
        anchors.fill: parent
        visible: ring.style === 3 && ring.sweep > 0.2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: ring.withAlpha(ring.color, 0.22)
            strokeWidth: ring.w * 2.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.cx; centerY: ring.cy
                radiusX: ring.radius; radiusY: ring.radius
                startAngle: -90; sweepAngle: ring.sweep
            }
        }
    }

    Shape {
        anchors.fill: parent
        // El trazo discontinuo (segmentos) usa el renderizador de geometría, que admite guiones.
        preferredRendererType: ring.segmented ? Shape.GeometryRenderer : Shape.CurveRenderer

        // Pista (el recorrido completo, tenue)
        ShapePath {
            strokeColor: ring.withAlpha(ring.color, ring.trackOpacity)
            strokeWidth: ring.style === 2 ? Math.max(1, ring.w * 0.5) : ring.w
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            strokeStyle: ring.segmented ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: ring.dash
            PathAngleArc {
                centerX: ring.cx; centerY: ring.cy
                radiusX: ring.radius; radiusY: ring.radius
                startAngle: -90; sweepAngle: 360
            }
        }

        // Progreso
        ShapePath {
            strokeColor: ring.sweep > 0.2 ? ring.color : "transparent"
            strokeWidth: ring.w
            fillColor: "transparent"
            capStyle: ring.roundCaps ? ShapePath.RoundCap : ShapePath.FlatCap
            strokeStyle: ring.segmented ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: ring.dash
            PathAngleArc {
                centerX: ring.cx; centerY: ring.cy
                radiusX: ring.radius; radiusY: ring.radius
                startAngle: -90; sweepAngle: ring.sweep
            }
        }
    }

    // Punto en la punta (estilo Fino)
    Rectangle {
        visible: ring.style === 2
        readonly property real a: (ring.sweep - 90) * Math.PI / 180
        width: ring.w * 2.6; height: width; radius: width / 2
        color: ring.color
        x: ring.cx + ring.radius * Math.cos(a) - width / 2
        y: ring.cy + ring.radius * Math.sin(a) - height / 2
    }
}
