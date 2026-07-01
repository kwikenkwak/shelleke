pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Body of the Displays overlay. Top: title + daemon status + reapply/reload/refresh.
 * Then a scrollable body: the quick Extend/Mirror/Single controls, the live list of
 * connected monitors, the user's profiles (read-only, active one marked), and a
 * freeze-as-new-profile + validate footer. All actions go through the Monitors
 * service, which only ever manages its own quick profile.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.popupBorderWidth

    readonly property int pad: 12
    readonly property int gap: 10
    implicitWidth: 380

    Component.onCompleted: Monitors.refresh()

    // Refresh whenever the panel becomes visible.
    Connections {
        target: GlobalStates
        function onMonitorsOpenChanged() {
            if (GlobalStates.monitorsOpen)
                Monitors.refresh();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap

        // ============ HEADER ============
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PixTitle {
                Layout.fillWidth: true
                text: "DISPLAYS"
                font.pixelSize: PixTheme.font.pixelSize.title
            }

            Repeater {
                model: [
                    { icon: "refresh", act: "refresh", tip: "Refresh" },
                    { icon: "bolt", act: "reapply", tip: "Re-apply current profile" },
                    { icon: "swap", act: "reload", tip: "Reload HDM config" }
                ]
                delegate: PixButton {
                    id: hbtn
                    required property var modelData
                    implicitWidth: 34
                    implicitHeight: 30
                    enabled: !Monitors.busy
                    onClicked: {
                        if (modelData.act === "refresh")
                            Monitors.refresh();
                        else if (modelData.act === "reapply")
                            Monitors.reapply();
                        else
                            Monitors.reload();
                    }
                    PixIcon {
                        anchors.centerIn: parent
                        name: hbtn.modelData.icon
                        size: 14
                        color: hbtn.contentColor
                    }
                    PixTooltip {
                        text: hbtn.modelData.tip
                        anchorEdges: Edges.Right
                        anchorGravity: Edges.Right
                    }
                }
            }
        }

        // Daemon + active-profile status line.
        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Rectangle {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                radius: 0
                antialiasing: false
                color: Monitors.daemonRunning ? PixTheme.colors.fg : "transparent"
                border.width: PixTheme.borderWidth
                border.color: PixTheme.colors.line
            }
            PixText {
                text: Monitors.daemonRunning ? "Daemon on" : "Daemon off"
                font.pixelSize: PixTheme.font.pixelSize.smaller
                color: PixTheme.colors.grey
            }
            Item { Layout.fillWidth: true }
            PixText {
                text: Monitors.quickActive ? ("Quick: " + Monitors.quickMode)
                    : (Monitors.activeProfile ? ("Active: " + Monitors.activeProfile) : "No profile")
                font.pixelSize: PixTheme.font.pixelSize.smaller
                color: PixTheme.colors.grey
                elide: Text.ElideRight
                Layout.maximumWidth: 200
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

        // ============ SCROLLABLE BODY ============
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: root.gap

                // ---- QUICK LAYOUT ----
                PixText {
                    text: "QUICK LAYOUT"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                    color: PixTheme.colors.grey
                }
                QuickModeBar { Layout.fillWidth: true }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

                // ---- CONNECTED MONITORS ----
                PixText {
                    text: "CONNECTED (" + Monitors.monitors.length + ")"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                    color: PixTheme.colors.grey
                }
                Repeater {
                    model: Monitors.monitors
                    delegate: MonitorCard {
                        required property var modelData
                        Layout.fillWidth: true
                        monitor: modelData
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

                // ---- PROFILES (read-only) ----
                PixText {
                    text: "PROFILES"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                    color: PixTheme.colors.grey
                }
                Repeater {
                    model: Monitors.profiles
                    delegate: ProfileRow {
                        required property var modelData
                        Layout.fillWidth: true
                        profile: modelData
                    }
                }
                PixText {
                    visible: Monitors.profiles.length === 0
                    text: "No profiles defined"
                    color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.small
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

                // ---- SAVE / CHECK ----
                PixText {
                    text: "SAVE CURRENT SETUP"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                    color: PixTheme.colors.grey
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 0
                        antialiasing: false
                        color: "transparent"
                        border.width: PixTheme.borderWidth
                        border.color: PixTheme.colors.line

                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: PixTheme.colors.fg
                            font.family: PixTheme.fontMain
                            font.pixelSize: PixTheme.font.pixelSize.normal
                            selectByMouse: true
                            validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9_-]{0,40}/ }
                            onAccepted: if (text.length > 0) Monitors.freeze(text)
                        }
                        PixText {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: nameInput.text.length === 0
                            text: "new profile name"
                            color: PixTheme.colors.grey
                            font.pixelSize: PixTheme.font.pixelSize.normal
                        }
                    }

                    PixButton {
                        id: saveBtn
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 34
                        enabled: !Monitors.busy && nameInput.text.length > 0
                        interactive: enabled
                        onClicked: Monitors.freeze(nameInput.text)
                        PixIcon {
                            anchors.centerIn: parent
                            name: "note"
                            size: 15
                            color: saveBtn.contentColor
                        }
                        PixTooltip {
                            text: "Freeze current setup as a new profile"
                            anchorEdges: Edges.Left
                            anchorGravity: Edges.Left
                        }
                    }
                }

                PixButton {
                    id: validateBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    enabled: !Monitors.busy
                    onClicked: Monitors.validate()
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 7
                        PixIcon { name: "todo"; size: 14; color: validateBtn.contentColor }
                        PixText {
                            text: "Validate config"
                            font.pixelSize: PixTheme.font.pixelSize.small
                            color: validateBtn.contentColor
                        }
                    }
                }
            }
        }

        // ============ STATUS LINE ============
        PixText {
            Layout.fillWidth: true
            visible: Monitors.busy || Monitors.lastMessage.length > 0
            text: Monitors.busy ? "Working…" : Monitors.lastMessage
            font.pixelSize: PixTheme.font.pixelSize.smaller
            color: (!Monitors.busy && !Monitors.lastOk) ? PixTheme.colors.fg : PixTheme.colors.grey
            elide: Text.ElideRight
        }
    }
}
