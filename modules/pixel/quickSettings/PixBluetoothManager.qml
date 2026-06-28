pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Inline Bluetooth management panel (pixel-styled). Header with a radio toggle
 * and a discovery/rescan button, then a scrollable list of devices (connected,
 * paired, then discovered). Click a device to connect/disconnect. Null-safe
 * against the adapter not being present.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.borderWidth

    readonly property var adapter: Bluetooth.defaultAdapter ?? null
    readonly property bool enabled: adapter?.enabled ?? false

    // Toggle discovery with visibility so the list stays fresh while shown.
    onVisibleChanged: {
        if (!adapter)
            return;
        if (visible && enabled)
            adapter.discovering = true;
        else
            adapter.discovering = false;
    }
    Component.onDestruction: {
        if (adapter)
            adapter.discovering = false;
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Item {
            width: parent.width
            height: 30

            PixTitle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "BLUETOOTH"
                font.pixelSize: PixTheme.font.pixelSize.title
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                PixButton {
                    id: radioBtn
                    implicitWidth: 30
                    implicitHeight: 28
                    filled: root.enabled
                    interactive: root.adapter !== null
                    onClicked: {
                        if (!root.adapter)
                            return;
                        root.adapter.enabled = !root.adapter.enabled;
                        root.adapter.discovering = root.adapter.enabled;
                    }
                    PixIcon {
                        anchors.centerIn: parent
                        name: "bluetooth"
                        size: 15
                        color: radioBtn.contentColor
                    }
                }
                PixButton {
                    id: rescanBtn
                    implicitWidth: 30
                    implicitHeight: 28
                    interactive: root.enabled && !(root.adapter?.discovering ?? false)
                    onClicked: if (root.adapter) root.adapter.discovering = true
                    PixIcon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 15
                        color: rescanBtn.contentColor
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 30 - PixTheme.borderWidth - parent.spacing * 2
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds

            model: ScriptModel {
                values: BluetoothStatus.friendlyDeviceList ?? []
            }
            delegate: PixButton {
                id: devBtn
                required property var modelData
                width: list.width
                implicitHeight: 40
                readonly property bool isConnected: modelData?.connected ?? false
                filled: isConnected
                fillOnHover: !isConnected
                onClicked: {
                    if (!modelData)
                        return;
                    if (modelData.connected)
                        modelData.disconnect();
                    else
                        modelData.connect();
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    PixIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bluetooth"
                        size: 16
                        color: devBtn.contentColor
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16 - 8
                        spacing: 1
                        PixText {
                            width: parent.width
                            text: devBtn.modelData?.name || "Unknown device"
                            font.bold: true
                            font.pixelSize: PixTheme.font.pixelSize.normal
                            elide: Text.ElideRight
                            color: devBtn.contentColor
                        }
                        PixText {
                            width: parent.width
                            text: {
                                const d = devBtn.modelData;
                                if (!d)
                                    return "";
                                if (d.connected) {
                                    let s = "Connected";
                                    if (d.batteryAvailable)
                                        s += " - " + Math.round(d.battery * 100) + "%";
                                    return s;
                                }
                                if (d.paired)
                                    return "Paired";
                                return "Tap to connect";
                            }
                            font.pixelSize: PixTheme.font.pixelSize.smaller
                            color: devBtn.active ? PixTheme.colors.bg : PixTheme.colors.grey
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            PixText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.enabled ? "Searching..." : "Bluetooth off"
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.small
            }
        }
    }
}
