pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The tray cluster: the idle-inhibitor glyph, the pinned `SystemTrayItem`s, and
 * the Wi-Fi / Bluetooth status glyphs.
 *
 * The three status glyphs are coded-but-hidden in the pixel bar. Hairline's
 * SPEC §4.2 explicitly turns them ON ("they cost a hairline of ink each and
 * drop to ink-4 when off"); ledger's and broadsheet's bar inventories list only
 * the tray items, so they stay hidden there. Clicking Wi-Fi or Bluetooth opens
 * quick settings; clicking the snowflake toggles the idle inhibitor.
 *
 * Bound to Idle, TrayService, Network, BluetoothStatus.
 */
Row {
    id: root
    spacing: PaperTheme.pick(18, 6, 12)

    /// Only hairline draws the status glyphs (its §4.2). The others show tray
    /// items alone, exactly as the pixel bar does today.
    readonly property bool showStatusGlyphs: PaperTheme.isHairline

    // Idle inhibitor (snow = keep awake).
    PaperIcon {
        visible: root.showStatusGlyphs
        anchors.verticalCenter: parent.verticalCenter
        name: "snow"
        size: PaperTheme.icon.tray
        color: (Idle?.inhibit ?? false) ? PaperTheme.ink2 : PaperTheme.ink4
        MouseArea {
            id: idleArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Idle.toggleInhibit()
            PaperTooltip {
                text: "Keep awake"
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing
        Repeater {
            model: ScriptModel {
                values: TrayService.pinnedItems
            }
            delegate: BarTrayItem {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                item: modelData
            }
        }
    }

    // Wi-Fi (click opens quick settings).
    PaperIcon {
        visible: root.showStatusGlyphs
        anchors.verticalCenter: parent.verticalCenter
        name: (Network?.wifi || Network?.ethernet) ? "wifi" : "wifiOff"
        size: PaperTheme.icon.tray
        color: (Network?.wifi || Network?.ethernet) ? PaperTheme.ink2 : PaperTheme.ink4
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalStates.sidebarRightOpen = true
            PaperTooltip {
                text: Network?.networkName ?? "Network"
            }
        }
    }

    // Bluetooth (click opens quick settings).
    PaperIcon {
        visible: root.showStatusGlyphs
        anchors.verticalCenter: parent.verticalCenter
        name: "bluetooth"
        size: PaperTheme.icon.tray
        color: (BluetoothStatus?.connected ?? false) ? PaperTheme.ink2 : PaperTheme.ink4
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalStates.sidebarRightOpen = true
            PaperTooltip {
                text: "Bluetooth"
            }
        }
    }
}
