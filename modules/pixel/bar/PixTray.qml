import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Tray cluster: idle-inhibitor "snow" glyph (dimmed when not inhibiting),
 * system-tray items (monochrome PixAppIcons), and wifi + bluetooth status
 * glyphs (dimmed to grey when disconnected). Bound to Idle, TrayService,
 * Network, BluetoothStatus.
 */
Row {
    id: root
    spacing: 13

    // Idle inhibitor toggle (snow = keep-awake). Click toggles.
    PixIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: "snow"
        size: 16
        color: (Idle?.inhibit ?? false) ? PixTheme.colors.fg : PixTheme.colors.grey
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: Idle.toggleInhibit()
        }
    }

    // System tray items
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 13
        Repeater {
            model: ScriptModel {
                values: TrayService.pinnedItems
            }
            delegate: PixTrayItem {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                item: modelData
            }
        }
    }

    // Wifi status
    PixIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: "wifi"
        size: 16
        color: (Network?.wifi || Network?.ethernet) ? PixTheme.colors.fg : PixTheme.colors.grey
    }

    // Bluetooth status
    PixIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: "bluetooth"
        size: 16
        color: (BluetoothStatus?.connected ?? false) ? PixTheme.colors.fg : PixTheme.colors.grey
    }
}
