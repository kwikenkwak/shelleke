import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.pixel.common

/**
 * Centered "New worktree" dialog for the pixel family: spin up a task folder under
 * ~/pleevi with a git worktree per related repo, then open kitty on it with a shell tab,
 * a claude tab and a `vitulina up` tab per selected server.
 *
 * Opened by keybind (quickshell:worktreesToggle) rather than from the bar, so it lives on
 * the focused screen and takes keyboard focus exclusively — the name field has to be
 * typeable the moment it appears. Escape or a click on the scrim closes it.
 *
 * Gated by GlobalStates.worktreesOpen. All work happens in services/Worktrees.qml.
 */
Scope {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    PanelWindow {
        id: panelRoot
        visible: GlobalStates.worktreesOpen
        screen: root.focusedScreen

        function hide() {
            GlobalStates.worktreesOpen = false;
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:pixelWorktrees"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Dim scrim — same treatment as the session screen. Click anywhere to cancel.
        Rectangle {
            anchors.fill: parent
            color: PixTheme.colors.bg
            opacity: PixTheme.dark ? 0.82 : 0.86
            antialiasing: false
            MouseArea {
                anchors.fill: parent
                onClicked: panelRoot.hide()
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.worktreesOpen
            anchors.centerIn: parent

            focus: GlobalStates.worktreesOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide();
                    event.accepted = true;
                }
            }

            sourceComponent: PixelWorktreesContent {
                onCloseRequested: panelRoot.hide()
            }
        }
    }

    IpcHandler {
        target: "worktrees"

        function toggle(): void {
            GlobalStates.worktreesOpen = !GlobalStates.worktreesOpen;
        }
        function close(): void {
            GlobalStates.worktreesOpen = false;
        }
        function open(): void {
            GlobalStates.worktreesOpen = true;
        }
    }

    GlobalShortcut {
        name: "worktreesToggle"
        description: "Toggles the New worktree dialog on press"
        onPressed: GlobalStates.worktreesOpen = !GlobalStates.worktreesOpen
    }
    GlobalShortcut {
        name: "worktreesOpen"
        description: "Opens the New worktree dialog on press"
        onPressed: GlobalStates.worktreesOpen = true
    }
    GlobalShortcut {
        name: "worktreesClose"
        description: "Closes the New worktree dialog on press"
        onPressed: GlobalStates.worktreesOpen = false
    }
}
