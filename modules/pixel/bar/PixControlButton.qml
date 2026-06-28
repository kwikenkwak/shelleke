import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A bare clickable PixIcon control for the bar's controls cluster. Dims to grey
 * when `active` is false; full fg when active or hovered.
 */
MouseArea {
    id: root
    property string icon: ""
    property bool active: true
    signal triggered()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    implicitWidth: 22
    implicitHeight: 22
    onClicked: root.triggered()

    PixIcon {
        anchors.centerIn: parent
        name: root.icon
        size: 16
        color: (root.active || root.containsMouse) ? PixTheme.colors.fg : PixTheme.colors.grey
    }
}
