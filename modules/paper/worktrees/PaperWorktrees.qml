import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.paper.common

/**
 * The "New worktree" dialog for the paper family — §4.10 of all three SPECs.
 * Spin up a task folder under ~/pleevi with a jj workspace per related repo and
 * open kitty on it with a shell tab, a claude tab and a `vitulina up` tab per
 * selected server. All the work happens in services/Worktrees.qml →
 * scripts/worktrees/worktree-setup.py, which this surface never calls directly.
 *
 * A centred modal on the FOCUSED screen. Unlike the docked panels it dodges the
 * focus-grab problem entirely (HANDOFF §5.3): `keyboardFocus: Exclusive` plus a
 * scrim MouseArea, so the name field is typeable the instant it appears and a
 * click anywhere outside closes. No focus grab, no mask.
 *
 * IPC target "worktrees" and the three `worktrees*` GlobalShortcuts keep the
 * pixel family's names so existing Hyprland binds keep working.
 */
Scope {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)

    PanelWindow {
        id: panelRoot
        visible: GlobalStates.worktreesOpen
        screen: root.focusedScreen

        function hide(): void {
            GlobalStates.worktreesOpen = false;
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:paperWorktrees"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // The scrim: tracing paper over the desktop rather than a dimmer —
        // 92 % paper in hairline, 90 % in ledger, a warm 72 % in broadsheet.
        // Clicking it cancels.
        Rectangle {
            anchors.fill: parent
            color: PaperTheme.scrim2

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

            sourceComponent: PaperWorktreesContent {
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
