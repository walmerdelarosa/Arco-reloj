import QtQuick

// Esfera analógica: 60 marcas y manecillas de hora, minuto y segundo.
// Solo se recalcula cuando cambia «now» (una vez por segundo o por minuto).
Item {
    id: face

    property real r: 50                    // radio de la esfera
    property date now: new Date()
    property bool showSecondHand: true
    property bool smooth: false
    property color tickColor: "white"
    property color handColor: "white"
    property color secondColor: "#EF4444"
    property real tickOpacity: 1
    property real handOpacity: 1

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real sec: now.getSeconds() + (smooth ? now.getMilliseconds() / 1000 : 0)
    readonly property real minuteAngle: (now.getMinutes() + sec / 60) * 6
    readonly property real hourAngle: ((now.getHours() % 12) + now.getMinutes() / 60) * 30

    // Marcas: las de cada hora son más largas y gruesas
    Repeater {
        model: face.r > 8 ? 60 : 0
        delegate: Rectangle {
            id: tick
            required property int index
            readonly property bool major: index % 5 === 0
            readonly property real inset: face.r * 0.04
            width: major ? Math.max(1.5, face.r * 0.035) : Math.max(1, face.r * 0.014)
            height: major ? face.r * 0.13 : face.r * 0.055
            radius: width / 2
            antialiasing: true
            color: face.tickColor
            opacity: face.tickOpacity * (major ? 1 : 0.55)
            x: face.cx - width / 2
            y: face.cy - face.r + inset
            transform: Rotation { origin.x: tick.width / 2; origin.y: face.r - tick.inset; angle: tick.index * 6 }
        }
    }

    Item {
        anchors.fill: parent
        opacity: face.handOpacity

        // Manecillas: rectángulos que giran alrededor del centro de la esfera
        Repeater {
            model: [
                { len: 0.52, tail: 0.08, w: 0.07,  min: 2,   key: "h" },
                { len: 0.78, tail: 0.10, w: 0.045, min: 1.5, key: "m" },
                { len: 0.86, tail: 0.18, w: 0.018, min: 1,   key: "s" }
            ]
            delegate: Rectangle {
                id: hand
                required property var modelData
                readonly property real len: face.r * modelData.len
                visible: modelData.key !== "s" || face.showSecondHand
                width: Math.max(modelData.min, face.r * modelData.w)
                height: len + face.r * modelData.tail
                radius: width / 2
                antialiasing: true
                color: modelData.key === "s" ? face.secondColor : face.handColor
                x: face.cx - width / 2
                y: face.cy - len
                transform: Rotation {
                    origin.x: hand.width / 2
                    origin.y: hand.len
                    angle: hand.modelData.key === "h" ? face.hourAngle
                         : hand.modelData.key === "m" ? face.minuteAngle : face.sec * 6
                }
            }
        }
        Rectangle {
            width: Math.max(4, face.r * 0.09); height: width; radius: width / 2
            x: face.cx - width / 2; y: face.cy - height / 2
            color: face.showSecondHand ? face.secondColor : face.handColor
        }
    }
}
