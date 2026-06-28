import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/** Popup value row prefixed with a small PixIcon: icon + label + bold value. */
Row {
    id: root
    property string icon: ""
    property string label: ""
    property string value: ""
    property int iconSize: 12
    spacing: 7

    PixIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: root.iconSize
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
