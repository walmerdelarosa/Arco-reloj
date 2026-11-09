import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Una página de la ventana de ajustes: título, descripción breve y contenido con desplazamiento.
ScrollView {
    id: page
    default property alias content: col.data
    property string heading: ""
    property string intro: ""

    contentWidth: availableWidth
    bottomPadding: 18
    clip: true

    ColumnLayout {
        id: col
        x: 18
        width: page.availableWidth - 36
        spacing: 6

        Label {
            Layout.topMargin: 16
            text: page.heading
            font.pixelSize: 17
            font.bold: true
        }
        Label {
            visible: page.intro !== ""
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            text: page.intro
            wrapMode: Text.WordWrap
            opacity: 0.6
            font.pixelSize: 11
        }
    }
}
