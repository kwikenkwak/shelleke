pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.services.network
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Inline Wi-Fi management panel (pixel-styled). Header with a radio toggle and
 * a rescan button, then a scrollable list of nearby networks. Click a network
 * to connect (or disconnect the active one). Null-safe against Network not
 * being ready. The container fills the height it is given (anchors / Layout),
 * so the embedding panel controls how much vertical space it occupies.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.borderWidth

    // Rescan whenever shown so the list is fresh.
    onVisibleChanged: if (visible) Network.rescanWifi()
    Component.onCompleted: Network.rescanWifi()

    readonly property bool enabled: Network.wifiStatus !== "disabled"

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header: title + radio toggle + rescan.
        Item {
            width: parent.width
            height: 30

            PixTitle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "WI-FI"
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
                    onClicked: {
                        Network.toggleWifi();
                        Network.rescanWifi();
                    }
                    PixIcon {
                        anchors.centerIn: parent
                        name: "wifi"
                        size: 15
                        color: radioBtn.contentColor
                    }
                }
                PixButton {
                    id: rescanBtn
                    implicitWidth: 30
                    implicitHeight: 28
                    interactive: !Network.wifiScanning
                    onClicked: Network.rescanWifi()
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

        // Network list fills remaining height.
        ListView {
            id: list
            width: parent.width
            height: parent.height - 30 - PixTheme.borderWidth - parent.spacing * 2
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds

            model: ScriptModel {
                values: Network.friendlyWifiNetworks ?? []
            }
            delegate: PixButton {
                id: netBtn
                required property var modelData
                width: list.width
                implicitHeight: 40
                readonly property bool isActive: modelData?.active ?? false
                filled: isActive
                fillOnHover: !isActive
                onClicked: {
                    if (!modelData)
                        return;
                    if (isActive)
                        Network.disconnectWifiNetwork();
                    else
                        Network.connectToWifiNetwork(modelData);
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    PixIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "wifi"
                        size: 16
                        color: netBtn.contentColor
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16 - 8 - lockIcon.width - 8
                        spacing: 1
                        PixText {
                            width: parent.width
                            text: netBtn.modelData?.ssid ?? "Unknown"
                            font.bold: true
                            font.pixelSize: PixTheme.font.pixelSize.normal
                            elide: Text.ElideRight
                            color: netBtn.contentColor
                        }
                        PixText {
                            width: parent.width
                            text: {
                                if (netBtn.isActive)
                                    return "Connected";
                                if (netBtn.modelData === Network.wifiConnectTarget && Network.wifiConnecting)
                                    return "Connecting...";
                                return (netBtn.modelData?.strength ?? 0) + "%";
                            }
                            font.pixelSize: PixTheme.font.pixelSize.smaller
                            color: netBtn.active ? PixTheme.colors.bg : PixTheme.colors.grey
                            elide: Text.ElideRight
                        }
                    }
                    PixIcon {
                        id: lockIcon
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bolt"
                        size: 12
                        visible: netBtn.modelData?.isSecure ?? false
                        color: netBtn.contentColor
                    }
                }
            }

            PixText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.enabled ? "Scanning..." : "Wi-Fi off"
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.small
            }
        }
    }
}
