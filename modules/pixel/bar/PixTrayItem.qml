import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A single system-tray item rendered as a monochrome, pixelated PixAppIcon.
 * Left click activates; right click opens the item's menu (reusing the ii
 * SysTrayMenu). Tooltip text comes from TrayService.
 */
MouseArea {
    id: root
    required property SystemTrayItem item

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    implicitWidth: 20
    implicitHeight: 20

    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            root.item?.activate();
            break;
        case Qt.RightButton:
            if (root.item?.hasMenu) menu.open();
            break;
        }
        event.accepted = true;
    }

    PixAppIcon {
        anchors.centerIn: parent
        size: 18
        source: root.item?.icon ?? ""
    }

    QsMenuAnchor {
        id: menu
        menu: root.item?.menu
        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }
    }
}
