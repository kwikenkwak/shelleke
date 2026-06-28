pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common.models.quickToggles
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * The quick-settings panel body. Lays out full-height: fixed sections (header,
 * connectivity rows, toggle rows) pinned at the top, the notifications list
 * flex-grows to fill the remaining vertical space (scrollable), and the notif
 * footer + calendar sit at the bottom. Backed by the shared quickToggles models.
 *
 * Clicking the Internet / Bluetooth tiles opens an inline management overlay
 * (PixWifiManager / PixBluetoothManager) covering the panel.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.popupBorderWidth

    readonly property int pad: 12
    readonly property int gap: 11

    implicitWidth: 360

    // Which management overlay is open: "" | "wifi" | "bluetooth".
    property string overlay: ""

    // ---- Backing toggle models ----
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

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap

        // ============ HEADER ============
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

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
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PixToggleTile {
                Layout.fillWidth: true
                iconName: "wifi"
                title: "Internet"
                status: Network.networkName !== "" ? Network.networkName
                    : (root.internetConnected ? "Connected" : "Not connected")
                active: root.internetConnected
                onActivated: root.overlay = "wifi"
            }
            PixToggleTile {
                Layout.fillWidth: true
                iconName: "bluetooth"
                title: "Bluetooth"
                status: bluetoothToggle.statusText
                active: bluetoothToggle.toggled
                onActivated: root.overlay = "bluetooth"
            }
            PixButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 46
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
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PixButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 46
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
                Layout.fillWidth: true
                iconName: "speaker"
                title: "Audio output"
                status: root.audioMuted ? "Muted" : "Unmuted"
                active: !root.audioMuted
                onActivated: Audio.toggleMute()
            }
            PixToggleTile {
                Layout.fillWidth: true
                iconName: "moon"
                title: "Night Light"
                status: nightLightToggle.toggled ? "Active" : "Inactive"
                active: nightLightToggle.toggled
                onActivated: nightLightToggle.mainAction()
            }
        }

        // ============ ROW C ============
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
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

        // ============ NOTIFICATIONS (flex-grows) ============
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60

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
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PixButton {
                id: markReadButton
                Layout.preferredWidth: 44
                Layout.preferredHeight: 36
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
                Layout.fillWidth: true
                Layout.preferredHeight: 36
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
                Layout.preferredWidth: 44
                Layout.preferredHeight: 36
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
            Layout.fillWidth: true
            Layout.preferredHeight: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        PixCalendar {
            Layout.fillWidth: true
        }
    }

    // ============ MANAGEMENT OVERLAY ============
    // Covers the whole panel with a wifi/bluetooth management UI. Opened by the
    // Internet / Bluetooth tiles; a back button restores the panel.
    // Opaque backdrop so the panel content does not show through the overlay.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.borderWidth
        visible: overlayLoader.active
        color: PixTheme.colors.bg
        radius: 0
        antialiasing: false
    }

    Loader {
        id: overlayLoader
        anchors.fill: parent
        anchors.margins: root.pad
        active: root.overlay !== ""
        visible: active

        sourceComponent: Column {
            spacing: root.gap

            // Back bar.
            Item {
                width: overlayLoader.width
                height: 34
                PixButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 38
                    implicitHeight: 34
                    onClicked: root.overlay = ""
                    PixIcon {
                        anchors.centerIn: parent
                        name: "chevL"
                        size: 15
                        color: parent.contentColor
                    }
                }
                PixTitle {
                    anchors.left: parent.left
                    anchors.leftMargin: 50
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.overlay === "wifi" ? "INTERNET" : "DEVICES"
                    font.pixelSize: PixTheme.font.pixelSize.title
                }
            }

            Loader {
                width: overlayLoader.width
                height: overlayLoader.height - 34 - root.gap
                sourceComponent: root.overlay === "wifi" ? wifiManagerComp
                    : root.overlay === "bluetooth" ? btManagerComp
                    : null
            }
        }
    }

    Component {
        id: wifiManagerComp
        PixWifiManager {}
    }
    Component {
        id: btManagerComp
        PixBluetoothManager {}
    }
}
