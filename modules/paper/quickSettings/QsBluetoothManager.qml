pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The Bluetooth management overlay — the same shell as QsWifiManager, one level
 * down from the panel: back bar, masthead rule, radio, then the devices
 * (connected, then paired, then discovered) one hairline apart.
 *
 * Discovery is turned on while this screen is visible and off again when it
 * goes away or is destroyed, exactly as the pixel implementation does. Null-safe
 * against there being no adapter at all.
 */
Item {
    id: root

    /// The back chevron was pressed.
    signal back

    readonly property var adapter: Bluetooth.defaultAdapter ?? null
    readonly property bool radioOn: root.adapter?.enabled ?? false
    readonly property bool discovering: root.adapter?.discovering ?? false
    readonly property var devices: BluetoothStatus.friendlyDeviceList ?? []

    onVisibleChanged: {
        if (!root.adapter)
            return;
        root.adapter.discovering = root.visible && root.radioOn;
    }
    Component.onCompleted: {
        if (root.adapter && root.radioOn)
            root.adapter.discovering = true;
    }
    Component.onDestruction: {
        if (root.adapter)
            root.adapter.discovering = false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: PaperTheme.pick(16, 10, 12)

        // ---- back bar -----------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(PaperTheme.size.button, title.implicitHeight)

            PaperButton {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                shape: "icon"
                icon: "chevL"
                onClicked: root.back()
            }

            PaperTitle {
                id: title
                anchors.left: backButton.right
                anchors.leftMargin: PaperTheme.pick(14, 9, 10)
                anchors.right: rescanButton.left
                anchors.rightMargin: PaperTheme.pick(14, 9, 10)
                anchors.verticalCenter: parent.verticalCenter
                text: "Devices"
                elide: Text.ElideRight
            }

            PaperButton {
                id: rescanButton
                anchors.right: radioButton.visible ? radioButton.left : parent.right
                anchors.rightMargin: radioButton.visible ? PaperTheme.gap.icon : 0
                anchors.verticalCenter: parent.verticalCenter
                shape: "icon"
                icon: "refresh"
                enabled: root.radioOn && !root.discovering
                onClicked: {
                    if (root.adapter)
                        root.adapter.discovering = true;
                }

                PaperTooltip {
                    text: "Discover"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }

            PaperButton {
                id: radioButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !PaperTheme.isHairline
                enabled: root.adapter !== null
                label: root.radioOn ? "On" : "Off"
                checked: root.radioOn
                connected: true
                onClicked: root.toggleRadio()
            }
        }

        PaperRule {
            Layout.fillWidth: true
            weight: "oxford"
        }

        // ---- radio row (hairline only) ------------------------------------
        PaperToggleRow {
            Layout.fillWidth: true
            visible: PaperTheme.isHairline
            enabled: root.adapter !== null
            title: "Bluetooth"
            status: root.radioOn ? "Radio on" : "Radio off"
            on: root.radioOn
            connected: true
            minHeight: PaperTheme.size.listRow
            onToggled: root.toggleRadio()
        }

        PaperRule {
            Layout.fillWidth: true
            visible: PaperTheme.isHairline
        }

        // ---- the devices --------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: root.devices
                }

                delegate: PaperListRow {
                    id: devRow
                    required property int index
                    required property var modelData

                    readonly property bool isConnected: devRow.modelData?.connected ?? false

                    width: list.width
                    icon: "bluetooth"
                    dotColumn: PaperTheme.isHairline
                    dotFilled: devRow.isConnected
                    title: devRow.modelData?.name || "Unknown device"
                    subtitle: {
                        const d = devRow.modelData;
                        if (!d)
                            return "";
                        if (d.connected)
                            return d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + " %" : "Connected";
                        if (d.paired)
                            return "Paired";
                        return "Tap to connect";
                    }
                    on: devRow.isConnected
                    selected: devRow.isConnected && !PaperTheme.isHairline
                    connected: true
                    separator: devRow.index > 0
                    onActivated: {
                        if (!devRow.modelData)
                            return;
                        if (devRow.modelData.connected)
                            devRow.modelData.disconnect();
                        else
                            devRow.modelData.connect();
                    }

                    PaperStamp {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: devRow.isConnected && PaperTheme.isBroadsheet
                        text: "Linked"
                        tone: "link"
                    }
                }
            }

            PaperEmpty {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: list.count === 0
                text: root.radioOn ? "Searching…" : "Bluetooth off"
            }
        }
    }

    function toggleRadio(): void {
        if (!root.adapter)
            return;
        root.adapter.enabled = !root.adapter.enabled;
        root.adapter.discovering = root.adapter.enabled;
    }
}
