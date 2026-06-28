pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common.models.quickToggles
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * The 360px-wide quick-settings panel body, laid out top->bottom per
 * design/PixelQuickSettings.html. Backed by the shared quickToggles models.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.popupBorderWidth

    readonly property int pad: 12
    readonly property int gap: 11

    implicitWidth: 360
    implicitHeight: column.implicitHeight + pad * 2

    // ---- Backing toggle models ----
    NetworkToggle { id: networkToggle }
    BluetoothToggle { id: bluetoothToggle }
    IdleInhibitorToggle { id: idleToggle }
    MicToggle { id: micToggle }
    NightLightToggle { id: nightLightToggle }
    CloudflareWarpToggle { id: warpToggle }
    GameModeToggle { id: gameModeToggle }
    EasyEffectsToggle { id: easyEffectsToggle }
    AntiFlashbangToggle { id: antiFlashbangToggle }
    ColorPickerToggle { id: colorPickerToggle }

    readonly property bool internetConnected: Network.wifiStatus === "connected" || Network.ethernet
    readonly property bool micActive: !(Audio.source?.audio?.muted ?? true)
    readonly property bool audioMuted: Audio.sink?.audio?.muted ?? false

    Column {
        id: column
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap

        // ============ HEADER ============
        Item {
            width: parent.width
            height: 34

            // Uptime chip
            Rectangle {
                id: uptimeChip
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: uptimeRow.implicitWidth + 20
                radius: 0
                antialiasing: false
                color: "transparent"
                border.width: PixTheme.borderWidth
                border.color: PixTheme.colors.line

                Row {
                    id: uptimeRow
                    anchors.centerIn: parent
                    spacing: 7
                    PixIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "note"
                        size: 14
                    }
                    PixText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Up " + DateTime.uptime
                        font.bold: true
                        font.pixelSize: PixTheme.font.pixelSize.large
                    }
                }
            }

            // Action buttons
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: [
                        { icon: "pencil", action: "edit" },
                        { icon: "refresh", action: "refresh" },
                        { icon: "gear", action: "settings" },
                        { icon: "power", action: "power" }
                    ]
                    delegate: PixButton {
                        required property var modelData
                        implicitWidth: 38
                        implicitHeight: 34
                        onClicked: {
                            if (modelData.action === "power") {
                                GlobalStates.sessionOpen = true;
                                GlobalStates.sidebarRightOpen = false;
                            } else if (modelData.action === "settings") {
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
                                GlobalStates.sidebarRightOpen = false;
                            }
                            // edit/refresh: harmless stubs.
                        }
                        PixIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: 15
                            color: parent.contentColor
                        }
                    }
                }
            }
        }

        // ============ CONNECTIVITY ROW A ============
        Row {
            width: parent.width
            spacing: 8

            PixToggleTile {
                width: (parent.width - 8 * 2 - 44) / 2
                iconName: "wifi"
                title: "Internet"
                status: Network.networkName !== "" ? Network.networkName
                    : (root.internetConnected ? "Connected" : "Not connected")
                active: root.internetConnected
                onActivated: networkToggle.mainAction()
            }
            PixToggleTile {
                width: (parent.width - 8 * 2 - 44) / 2
                iconName: "bluetooth"
                title: "Bluetooth"
                status: bluetoothToggle.statusText
                active: bluetoothToggle.toggled
                onActivated: bluetoothToggle.mainAction()
            }
            PixButton {
                width: 44
                implicitHeight: 46
                filled: idleToggle.toggled
                onClicked: idleToggle.mainAction()
                PixIcon {
                    anchors.centerIn: parent
                    name: "coffee"
                    size: 18
                    color: parent.contentColor
                }
            }
        }

        // ============ ROW B ============
        Row {
            width: parent.width
            spacing: 8

            PixButton {
                width: 44
                implicitHeight: 46
                filled: root.micActive
                onClicked: micToggle.mainAction()
                PixIcon {
                    anchors.centerIn: parent
                    name: "mic"
                    size: 18
                    color: parent.contentColor
                }
            }
            PixToggleTile {
                width: (parent.width - 8 * 2 - 44) / 2
                iconName: "speaker"
                title: "Audio output"
                status: root.audioMuted ? "Muted" : "Unmuted"
                active: !root.audioMuted
                onActivated: Audio.toggleMute()
            }
            PixToggleTile {
                width: (parent.width - 8 * 2 - 44) / 2
                iconName: "moon"
                title: "Night Light"
                status: nightLightToggle.toggled ? "Active" : "Inactive"
                active: nightLightToggle.toggled
                onActivated: nightLightToggle.mainAction()
            }
        }

        // ============ ROW C ============
        Row {
            id: rowC
            width: parent.width
            spacing: 8
            readonly property real btnW: (width - spacing * 4) / 5

            Repeater {
                model: [
                    { icon: "nodes", toggle: warpToggle },
                    { icon: "fullscreen", toggle: gameModeToggle },
                    { icon: "sliders", toggle: easyEffectsToggle },
                    { icon: "flashoff", toggle: antiFlashbangToggle },
                    { icon: "dropper", toggle: colorPickerToggle }
                ]
                delegate: PixButton {
                    required property var modelData
                    width: rowC.btnW
                    implicitHeight: 38
                    filled: modelData.toggle.toggled
                    onClicked: modelData.toggle.mainAction()
                    PixIcon {
                        anchors.centerIn: parent
                        name: modelData.icon
                        size: 16
                        color: parent.contentColor
                    }
                }
            }
        }

        // ============ NOTIFICATIONS ============
        Rectangle {
            width: parent.width
            height: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        Item {
            width: parent.width
            height: Math.min(220, Math.max(notifList.contentHeight, 32))

            ListView {
                id: notifList
                anchors.fill: parent
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: Notifications.appNameList
                }
                delegate: PixNotifRow {
                    required property var modelData
                    width: notifList.width
                    group: Notifications.groupsByAppName[modelData] ?? null
                }
            }

            PixText {
                anchors.centerIn: parent
                visible: Notifications.appNameList.length === 0
                text: "No notifications"
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.small
            }
        }

        // ============ NOTIF FOOTER ============
        Row {
            width: parent.width
            spacing: 8

            PixButton {
                id: markReadButton
                width: 44
                implicitHeight: 36
                onClicked: Notifications.markAllRead()
                PixIcon {
                    anchors.centerIn: parent
                    name: "bell"
                    size: 16
                    color: markReadButton.contentColor
                }
            }
            PixButton {
                id: notifCountLabel
                width: parent.width - 44 * 2 - 8 * 2
                implicitHeight: 36
                fillOnHover: false
                interactive: false
                PixText {
                    anchors.centerIn: parent
                    text: {
                        const n = Notifications.list.length;
                        return n + (n === 1 ? " notification" : " notifications");
                    }
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.normal
                    color: notifCountLabel.contentColor
                }
            }
            PixButton {
                width: 44
                implicitHeight: 36
                onClicked: Notifications.discardAllNotifications()
                PixIcon {
                    anchors.centerIn: parent
                    name: "trash"
                    size: 16
                    color: parent.contentColor
                }
            }
        }

        // ============ CALENDAR ============
        Rectangle {
            width: parent.width
            height: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        PixCalendar {
            width: parent.width
        }
    }
}
