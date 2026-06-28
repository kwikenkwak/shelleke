import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/** Popup value row prefixed with a 9x9 swatch (filled = used, hollow = free). */
Row {
    id: root
    property bool filled: true
    property string label: ""
    property string value: ""
    spacing: 7

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 9
        height: 9
        antialiasing: false
        color: root.filled ? PixTheme.colors.fg : "transparent"
        border.width: root.filled ? 0 : 2
        border.color: PixTheme.colors.fg
    }
    PixText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.pixelSize: PixTheme.font.pixelSize.large
    }
    PixText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        font.bold: true
        font.pixelSize: PixTheme.font.pixelSize.large
    }
}
