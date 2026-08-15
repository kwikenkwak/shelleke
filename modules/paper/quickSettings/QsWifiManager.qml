pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The Wi-Fi management overlay. It COVERS the quick-settings panel rather than
 * floating a dialog over it: same paper, same padding, one level down.
 *
 * A back bar (chevron + the section name + a rescan button), the masthead rule,
 * a radio control, then the networks one hairline apart. Click a network to
 * connect, or the connected one to disconnect. Rescans whenever it appears, and
 * is null-safe against Network not being ready yet.
 *
 * Per variant:
 *   hairline   — the back bar is a chevron plus micro-caps; the radio is a
 *                PaperSwitch on its own row; the connected network takes the
 *                6 px dot in the left gutter and goes to `ink`.
 *   ledger     — a Charter 16 title, an `On` toggle button in the masthead, and
 *                the rows ruled one hairline apart. The connected entry carries
 *                the ORDINARY selected mark, so "connected" looks exactly like
 *                "selected" everywhere else in the shell.
 *   broadsheet — Pagella small caps, an Oxford rule, an `On` button, and a blue
 *                `On` stamp on the connected row.
 */
Item {
    id: root

    /// The back chevron was pressed.
    signal back

    readonly property bool radioOn: Network.wifiStatus !== "disabled"
    readonly property var networks: Network.friendlyWifiNetworks ?? []

    // Keep the list fresh while the screen is up.
    onVisibleChanged: if (root.visible)
        Network.rescanWifi()
    Component.onCompleted: Network.rescanWifi()

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
                text: "Internet"
                elide: Text.ElideRight
            }

            PaperButton {
                id: rescanButton
                anchors.right: radioButton.visible ? radioButton.left : parent.right
                anchors.rightMargin: radioButton.visible ? PaperTheme.gap.icon : 0
                anchors.verticalCenter: parent.verticalCenter
                shape: "icon"
                icon: "refresh"
                enabled: root.radioOn && !Network.wifiScanning
                onClicked: Network.rescanWifi()

                PaperTooltip {
                    text: "Rescan"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }

            // Ledger and broadsheet put the radio in the masthead as an On
            // button; hairline gives it a switch on its own row below.
            PaperButton {
                id: radioButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !PaperTheme.isHairline
                label: root.radioOn ? "On" : "Off"
                checked: root.radioOn
                connected: true
                onClicked: {
                    Network.toggleWifi();
                    Network.rescanWifi();
                }
            }
        }

        // The masthead rule. Degrades to a plain hairline outside broadsheet.
        PaperRule {
            Layout.fillWidth: true
            weight: "oxford"
        }

        // ---- radio row (hairline only) ------------------------------------
        PaperToggleRow {
            Layout.fillWidth: true
            visible: PaperTheme.isHairline
            title: "Wi-Fi"
            status: root.radioOn ? "Radio on" : "Radio off"
            on: root.radioOn
            connected: true
            minHeight: PaperTheme.size.listRow
            onToggled: {
                Network.toggleWifi();
                Network.rescanWifi();
            }
        }

        PaperRule {
            Layout.fillWidth: true
            visible: PaperTheme.isHairline
        }

        // ---- the networks -------------------------------------------------
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
                    values: root.networks
                }

                delegate: PaperListRow {
                    id: netRow
                    required property int index
                    required property var modelData

                    readonly property bool isActive: netRow.modelData?.active ?? false
                    readonly property bool isConnecting: netRow.modelData === Network.wifiConnectTarget && Network.wifiConnecting

                    width: list.width
                    icon: "wifi"
                    dotColumn: PaperTheme.isHairline
                    dotFilled: netRow.isActive
                    title: netRow.modelData?.ssid ?? "Unknown"
                    subtitle: {
                        if (netRow.isActive)
                            return "Connected";
                        if (netRow.isConnecting)
                            return "Connecting…";
                        const s = (netRow.modelData?.strength ?? 0) + " %";
                        return (!PaperTheme.isHairline && (netRow.modelData?.isSecure ?? false)) ? "Secured · " + s : s;
                    }
                    on: netRow.isActive
                    selected: netRow.isActive && !PaperTheme.isHairline
                    connected: true
                    separator: netRow.index > 0
                    onActivated: {
                        if (!netRow.modelData)
                            return;
                        if (netRow.isActive)
                            Network.disconnectWifiNetwork();
                        else
                            Network.connectToWifiNetwork(netRow.modelData);
                    }

                    PaperIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: netRow.modelData?.isSecure ?? false
                        name: "lock"
                        size: PaperTheme.icon.tiny
                        color: PaperTheme.ink4
                    }

                    // Broadsheet stamps the connected entry.
                    PaperStamp {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: netRow.isActive && PaperTheme.isBroadsheet
                        text: "On"
                        tone: "link"
                    }
                }
            }

            PaperEmpty {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: list.count === 0
                text: root.radioOn ? "Scanning…" : "Wi-Fi off"
            }
        }
    }
}
