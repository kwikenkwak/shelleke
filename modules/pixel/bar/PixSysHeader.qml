import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/** Column header for the system-monitor popup: icon + bold label + bottom rule. */
Column {
    id: root
    property string icon: ""
    property string label: ""
    spacing: 6

    Row {
        spacing: 7
        PixIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 16
        }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.title
        }
    }
    Rectangle {
        width: root.width
        height: 2
        color: PixTheme.colors.line
        antialiasing: false
    }
}
