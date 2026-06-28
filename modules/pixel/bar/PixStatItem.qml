import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/** A single stat: PixIcon + numeric value (bold), per the bar design. */
Row {
    id: root
    property string icon: ""
    property int value: 0
    spacing: 5

    PixIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 14
    }
    PixText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        font.bold: true
        font.pixelSize: PixTheme.font.pixelSize.larger
    }
}
