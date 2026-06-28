import QtQuick
import qs.modules.pixel.common

/** A 2px x 22px vertical divider line with horizontal margins, per the design. */
Item {
    id: root
    implicitWidth: 2 + 28      // 2px line + 14px margin each side
    implicitHeight: 22

    Rectangle {
        anchors.centerIn: parent
        width: 2
        height: 22
        color: PixTheme.colors.line
        antialiasing: false
    }
}
