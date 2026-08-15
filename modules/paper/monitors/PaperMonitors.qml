import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.paper.common

/**
 * The Displays overlay for the paper family — §4.8 of all three SPECs. A GUI
 * over hyprdynamicmonitors; every write goes through the `Monitors` service →
 * scripts/monitors/hdm-control.py, which this surface never touches directly.
 *
 * Docked LEFT (top+left+bottom) so it never collides with the right-hand
 * quick-settings / notification column, `exclusiveZone: 0`, width
 * `PaperTheme.size.monitors` — a binding, so a live variant switch resizes the
 * panel rather than requiring a reload.
 *
 * Lifecycle notes (HANDOFF §5.3):
 *   · The PanelWindow is instantiated ONCE and only `visible` toggles. A
 *     Loader-created window maps at the same instant the focus grab activates,
 *     the grab never attaches, and click-out-to-close silently breaks.
 *   · `keyboardFocus: OnDemand` is required here (and only here among the docked
 *     panels) so the profile editor's PaperFields can call focusInput().
 *
 * IPC target "monitors" and the three `monitors*` GlobalShortcuts keep the pixel
 * family's names so the user's existing Hyprland binds keep working; the two
 * families never load at the same time, so they cannot collide.
 */
Scope {
    id: root

    PanelWindow {
        id: panelRoot
        visible: GlobalStates.monitorsOpen

        function hide(): void {
            GlobalStates.monitorsOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: PaperTheme.size.monitors
        WlrLayershell.namespace: "quickshell:paperMonitors"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        anchors {
            top: true
            left: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: grab
            windows: [panelRoot]
            active: GlobalStates.monitorsOpen
            onCleared: () => {
                if (!active)
                    panelRoot.hide();
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.monitorsOpen
            anchors.fill: parent

            focus: GlobalStates.monitorsOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide();
                    event.accepted = true;
                }
            }

            sourceComponent: PaperMonitorsContent {}
        }
    }

    IpcHandler {
        target: "monitors"

        function toggle(): void {
            GlobalStates.monitorsOpen = !GlobalStates.monitorsOpen;
        }
        function close(): void {
            GlobalStates.monitorsOpen = false;
        }
        function open(): void {
            GlobalStates.monitorsOpen = true;
        }
    }

    GlobalShortcut {
        name: "monitorsToggle"
        description: "Toggles the Displays panel on press"
        onPressed: GlobalStates.monitorsOpen = !GlobalStates.monitorsOpen
    }
    GlobalShortcut {
        name: "monitorsOpen"
        description: "Opens the Displays panel on press"
        onPressed: GlobalStates.monitorsOpen = true
    }
    GlobalShortcut {
        name: "monitorsClose"
        description: "Closes the Displays panel on press"
        onPressed: GlobalStates.monitorsOpen = false
    }
}
