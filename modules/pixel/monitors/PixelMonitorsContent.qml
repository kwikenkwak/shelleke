pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Body of the Displays overlay. A small screen-stack:
 *   main     — quick Extend/Mirror/Single, connected monitors, profile list
 *   editor   — full profile create/edit (ProfileEditor), shown as an overlay
 *   settings — HDM global settings + daemon (SettingsScreen), shown as an overlay
 *
 * The quick-layout bar at the top of `main` is intentionally unchanged. All writes
 * go through the Monitors service -> hdm-control.py.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.popupBorderWidth

    readonly property int pad: 12
    readonly property int gap: 10
    implicitWidth: 380

    property string screen: "main"        // "main" | "settings"
    property var editingProfile: null     // null | profile object | {__new__:true}

    Component.onCompleted: Monitors.refresh()
    Connections {
        target: GlobalStates
        function onMonitorsOpenChanged() {
            if (GlobalStates.monitorsOpen) {
                root.screen = "main";
                root.editingProfile = null;
                Monitors.refresh();
            }
        }
    }

    // ============ MAIN ============
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap
        visible: root.screen === "main" && root.editingProfile === null

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PixTitle { Layout.fillWidth: true; text: "DISPLAYS"; font.pixelSize: PixTheme.font.pixelSize.title }
            PixButton {
                id: refreshBtn
                implicitWidth: 34; implicitHeight: 30
                enabled: !Monitors.busy
                onClicked: Monitors.refresh()
                PixIcon { anchors.centerIn: parent; name: "refresh"; size: 14; color: refreshBtn.contentColor }
                PixTooltip { text: "Refresh"; anchorEdges: Edges.Right; anchorGravity: Edges.Right }
            }
            PixButton {
                id: settingsBtn
                implicitWidth: 34; implicitHeight: 30
                onClicked: root.screen = "settings"
                PixIcon { anchors.centerIn: parent; name: "gear"; size: 14; color: settingsBtn.contentColor }
                PixTooltip { text: "Settings & daemon"; anchorEdges: Edges.Right; anchorGravity: Edges.Right }
            }
        }

        // daemon + active status
        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Rectangle {
                Layout.preferredWidth: 14; Layout.preferredHeight: 14; radius: 0; antialiasing: false
                color: Monitors.daemonRunning ? PixTheme.colors.fg : "transparent"
                border.width: PixTheme.borderWidth; border.color: PixTheme.colors.line
            }
            PixText { text: Monitors.daemonRunning ? "Daemon on" : "Daemon off"
                font.pixelSize: PixTheme.font.pixelSize.smaller; color: PixTheme.colors.grey }
            Item { Layout.fillWidth: true }
            PixText {
                text: Monitors.quickActive ? ("Quick: " + Monitors.quickMode)
                    : (Monitors.activeProfile ? ("Active: " + Monitors.activeProfile) : "No profile")
                font.pixelSize: PixTheme.font.pixelSize.smaller; color: PixTheme.colors.grey
                elide: Text.ElideRight; Layout.maximumWidth: 200
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

        // scrollable body
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

                // ---- QUICK LAYOUT (unchanged) ----
                PixText { text: "QUICK LAYOUT"; font.bold: true; color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.smaller }
                QuickModeBar { Layout.fillWidth: true }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

                // ---- CONNECTED ----
                PixText { text: "CONNECTED (" + Monitors.monitors.length + ")"; font.bold: true
                    color: PixTheme.colors.grey; font.pixelSize: PixTheme.font.pixelSize.smaller }
                Repeater {
                    model: Monitors.monitors
                    delegate: MonitorCard {
                        required property var modelData
                        Layout.fillWidth: true
                        monitor: modelData
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

                // ---- PROFILES ----
                RowLayout {
                    Layout.fillWidth: true
                    PixText { Layout.fillWidth: true; text: "PROFILES"; font.bold: true
                        color: PixTheme.colors.grey; font.pixelSize: PixTheme.font.pixelSize.smaller }
                    PixButton {
                        id: newBtn
                        implicitHeight: 28
                        implicitWidth: newT.implicitWidth + 18
                        onClicked: root.editingProfile = ({ __new__: true })
                        PixText { id: newT; anchors.centerIn: parent; text: "+ New"; font.bold: true
                            font.pixelSize: PixTheme.font.pixelSize.smaller; color: newBtn.contentColor }
                    }
                }
                Repeater {
                    model: Monitors.profiles
                    delegate: ProfileRow {
                        required property var modelData
                        Layout.fillWidth: true
                        profile: modelData
                        onClicked: root.editingProfile = modelData
                    }
                }
                PixText {
                    visible: Monitors.profiles.length === 0
                    text: "No profiles yet — tap + New or use a quick layout"
                    color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.small
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.preferredHeight: 2 }
            }
        }

        // status line
        PixText {
            Layout.fillWidth: true
            visible: Monitors.busy || Monitors.lastMessage.length > 0
            text: Monitors.busy ? "Working…" : Monitors.lastMessage
            font.pixelSize: PixTheme.font.pixelSize.smaller
            color: (!Monitors.busy && !Monitors.lastOk) ? PixTheme.colors.fg : PixTheme.colors.grey
            elide: Text.ElideRight
        }
    }

    // ============ OVERLAY (editor / settings) ============
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
        active: root.editingProfile !== null || root.screen !== "main"
        visible: active
        sourceComponent: root.editingProfile !== null ? editorComp : settingsComp
    }
    Component {
        id: editorComp
        ProfileEditor {
            profile: root.editingProfile
            onDone: root.editingProfile = null
        }
    }
    Component {
        id: settingsComp
        SettingsScreen {
            onDone: root.screen = "main"
        }
    }
}
