import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PixelSessionScreen — full-screen monochrome power menu.
 *
 * Gated by GlobalStates.sessionOpen; loader/focus/escape behavior mirrors
 * modules/ii/sessionScreen/SessionScreen.qml. A dim translucent scrim (the one
 * sanctioned place for translucency) over a centered row of large bordered
 * PixButtons: Lock, Logout, Suspend, Hibernate, Reboot, Shutdown. Each is a
 * PixIcon over a Silkscreen label. Esc or a scrim click closes it; actions are
 * wired to the same Session.* calls the ii screen uses.
 */
Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    // Action model — icon names are from the PixIcon set.
    readonly property var actionModel: [
        { key: "lock",      icon: "gear",    label: Translation.tr("Lock") },
        { key: "logout",    icon: "swap",    label: Translation.tr("Logout") },
        { key: "suspend",   icon: "moon",    label: Translation.tr("Suspend") },
        { key: "hibernate", icon: "snow",    label: Translation.tr("Hibernate") },
        { key: "reboot",    icon: "refresh", label: Translation.tr("Reboot") },
        { key: "shutdown",  icon: "power",   label: Translation.tr("Shutdown") },
    ]

    function runAction(key) {
        switch (key) {
        case "lock":      Session.lock(); break;
        case "logout":    Session.logout(); break;
        case "suspend":   Session.suspend(); break;
        case "hibernate": Session.hibernate(); break;
        case "reboot":    Session.reboot(); break;
        case "shutdown":  Session.poweroff(); break;
        }
        GlobalStates.sessionOpen = false;
    }

    Loader {
        id: sessionLoader
        active: GlobalStates.sessionOpen

        Connections {
            target: GlobalStates
            function onScreenLockedChanged() {
                if (GlobalStates.screenLocked)
                    GlobalStates.sessionOpen = false;
            }
        }

        sourceComponent: PanelWindow {
            id: sessionRoot
            visible: sessionLoader.active

            function hide() {
                GlobalStates.sessionOpen = false;
            }

            screen: root.focusedScreen
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:pixelSession"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            implicitWidth: root.focusedScreen?.width ?? 0
            implicitHeight: root.focusedScreen?.height ?? 0

            // Dim scrim — translucent fg overlay. Click anywhere to cancel.
            Rectangle {
                id: scrim
                anchors.fill: parent
                color: PixTheme.colors.fg
                opacity: PixTheme.dark ? 0.55 : 0.35
                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionRoot.hide()
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: sessionRoot.visible

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        sessionRoot.hide();
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 22

                    PixTitle {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: PixTheme.font.pixelSize.huge
                        text: Translation.tr("SESSION")
                    }

                    // Centered row of large bordered action buttons.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Repeater {
                            model: root.actionModel

                            delegate: PixButton {
                                id: actionButton
                                required property var modelData
                                implicitWidth: 116
                                implicitHeight: 116
                                borderWidth: PixTheme.popupBorderWidth
                                // Opaque panel background so the scrim doesn't bleed through.
                                Rectangle {
                                    anchors.fill: parent
                                    z: -1
                                    visible: !actionButton.active
                                    color: PixTheme.colors.bg
                                    radius: 0
                                    antialiasing: false
                                }
                                onClicked: root.runAction(actionButton.modelData.key)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    PixIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        name: actionButton.modelData.icon
                                        size: 35
                                        color: actionButton.contentColor
                                    }
                                    PixTitle {
                                        Layout.alignment: Qt.AlignHCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: PixTheme.font.pixelSize.small
                                        color: actionButton.contentColor
                                        text: actionButton.modelData.label
                                    }
                                }
                            }
                        }
                    }

                    PixText {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.small
                        text: Translation.tr("Esc or click anywhere to cancel")
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "pixelSession"
        function toggle(): void {
            GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
        }
        function close(): void {
            GlobalStates.sessionOpen = false;
        }
        function open(): void {
            GlobalStates.sessionOpen = true;
        }
    }

    GlobalShortcut {
        name: "pixelSessionToggle"
        description: "Toggles pixel session screen on press"
        onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen
    }
    GlobalShortcut {
        name: "pixelSessionOpen"
        description: "Opens pixel session screen on press"
        onPressed: GlobalStates.sessionOpen = true
    }
    GlobalShortcut {
        name: "pixelSessionClose"
        description: "Closes pixel session screen on press"
        onPressed: GlobalStates.sessionOpen = false
    }
}
