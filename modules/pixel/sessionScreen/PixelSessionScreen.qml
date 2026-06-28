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
 * Behavior mirrors modules/ii/sessionScreen/SessionScreen.qml:
 *   - gated by GlobalStates.sessionOpen (Loader),
 *   - keyboard-focus-exclusive overlay, closes on Escape / scrim click,
 *   - same Session.* action calls,
 *   - same IPC ("pixelSession") + GlobalShortcut names so the bar/ii triggers
 *     keep working.
 *
 * Pixel idiom: a translucent scrim (the one sanctioned translucency) over a
 * centered "SESSION" heading and a row of large bordered PixButton tiles. Each
 * tile is a PixIcon over a Silkscreen label, with a number accelerator hint.
 * The selected tile is inverted (filled). Arrow keys move the selection, Enter
 * activates, number keys 1-6 jump+activate, and clicking a tile activates it.
 */
Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    // Action model. Icons are from the 7x7 PixIcon set; there is no dedicated
    // lock/logout glyph, so the least-misleading picks are used: gear (system),
    // swap (switch user / sign out), moon (suspend), snow (hibernate),
    // refresh (reboot), power (shutdown). `accel` is the number accelerator.
    readonly property var actionModel: [
        { key: "lock",      icon: "gear",    label: Translation.tr("Lock"),      accel: "1" },
        { key: "logout",    icon: "swap",    label: Translation.tr("Logout"),    accel: "2" },
        { key: "suspend",   icon: "moon",    label: Translation.tr("Suspend"),   accel: "3" },
        { key: "hibernate", icon: "snow",    label: Translation.tr("Hibernate"), accel: "4" },
        { key: "reboot",    icon: "refresh", label: Translation.tr("Reboot"),    accel: "5" },
        { key: "shutdown",  icon: "power",   label: Translation.tr("Shutdown"),  accel: "6" },
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
        onActiveChanged: {
            if (sessionLoader.active)
                SessionWarnings.refresh();
        }

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

            // Currently highlighted tile. Reset to the first action on open.
            property int selectedIndex: 0
            onVisibleChanged: if (visible) selectedIndex = 0

            function hide() {
                GlobalStates.sessionOpen = false;
            }

            function move(delta) {
                let n = root.actionModel.length;
                selectedIndex = ((selectedIndex + delta) % n + n) % n;
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

            // Dim scrim — the one sanctioned translucency. Click anywhere to cancel.
            Rectangle {
                id: scrim
                anchors.fill: parent
                color: PixTheme.colors.bg
                opacity: PixTheme.dark ? 0.82 : 0.86
                antialiasing: false
                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionRoot.hide()
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: sessionRoot.visible

                Keys.onPressed: event => {
                    const n = root.actionModel.length;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        sessionRoot.hide();
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                    case Qt.Key_Down:
                    case Qt.Key_Tab:
                        sessionRoot.move(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                    case Qt.Key_Up:
                    case Qt.Key_Backtab:
                        sessionRoot.move(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Home:
                        sessionRoot.selectedIndex = 0;
                        event.accepted = true;
                        break;
                    case Qt.Key_End:
                        sessionRoot.selectedIndex = n - 1;
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.runAction(root.actionModel[sessionRoot.selectedIndex].key);
                        event.accepted = true;
                        break;
                    default:
                        // Number accelerators 1-6.
                        if (event.text.length === 1) {
                            const idx = root.actionModel.findIndex(a => a.accel === event.text);
                            if (idx >= 0) {
                                sessionRoot.selectedIndex = idx;
                                root.runAction(root.actionModel[idx].key);
                                event.accepted = true;
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 26

                    PixTitle {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: PixTheme.font.pixelSize.huge
                        text: Translation.tr("SESSION")
                    }

                    // Centered row of large bordered action tiles.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 18

                        Repeater {
                            model: root.actionModel

                            delegate: PixButton {
                                id: actionButton
                                required property int index
                                required property var modelData
                                implicitWidth: 132
                                implicitHeight: 132
                                borderWidth: PixTheme.popupBorderWidth
                                // Keyboard selection forces the inverted/filled look.
                                filled: sessionRoot.selectedIndex === actionButton.index

                                // Opaque backing so the dim scrim never bleeds
                                // through an un-filled tile.
                                Rectangle {
                                    anchors.fill: parent
                                    z: -1
                                    visible: !actionButton.active
                                    color: PixTheme.colors.bg
                                    radius: 0
                                    antialiasing: false
                                }

                                onClicked: root.runAction(actionButton.modelData.key)
                                onHoveredChanged: if (hovered) sessionRoot.selectedIndex = actionButton.index

                                // Accelerator hint, top-left corner.
                                PixText {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        topMargin: 7
                                        leftMargin: 8
                                    }
                                    text: actionButton.modelData.accel
                                    font.pixelSize: PixTheme.font.pixelSize.smaller
                                    color: actionButton.active ? actionButton.contentColor
                                        : PixTheme.colors.grey
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 14
                                    PixIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        name: actionButton.modelData.icon
                                        size: 42
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

                    // Hint line + selected-action confirmation.
                    PixText {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.small
                        text: Translation.tr("Arrows or 1-6 to choose, Enter to confirm — Esc or click anywhere to cancel")
                    }

                    // Session warnings (package manager / download in progress).
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        WarningChip {
                            visible: SessionWarnings.packageManagerRunning
                            text: Translation.tr("Your package manager is running")
                        }
                        WarningChip {
                            visible: SessionWarnings.downloadRunning
                            text: Translation.tr("There might be a download in progress")
                        }
                    }
                }
            }
        }
    }

    // A bordered monochrome warning pill (filled, like an "active" chip) so it
    // stands out against the scrim without using any accent color.
    component WarningChip: PixButton {
        property alias text: chipLabel.text
        interactive: false
        fillOnHover: false
        filled: true
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: chipLabel.implicitWidth + 28
        implicitHeight: chipLabel.implicitHeight + 14
        PixText {
            id: chipLabel
            anchors.centerIn: parent
            color: parent.contentColor
            font.pixelSize: PixTheme.font.pixelSize.smaller
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
