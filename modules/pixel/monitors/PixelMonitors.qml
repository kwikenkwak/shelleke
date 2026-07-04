import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.pixel.common

/**
 * Left-side "Displays" panel for the pixel family: a GUI for hyprdynamicmonitors.
 * Anchored left so it doesn't overlap the right-side notifications/quick settings.
 *
 * Structure mirrors PixelQuickSettings exactly — the PanelWindow is always
 * instantiated and toggled with `visible` (not created on-demand by a Loader), so
 * the HyprlandFocusGrab attaches correctly and click-out close works.
 *
 * Gated by GlobalStates.monitorsOpen. Opened by the bar's "Displays" button;
 * closed on focus loss or Escape.
 */
Scope {
    id: root

    PanelWindow {
        id: panelRoot
        visible: GlobalStates.monitorsOpen

        function hide() {
            GlobalStates.monitorsOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: 380 // matches PixelMonitorsContent's fixed width
        WlrLayershell.namespace: "quickshell:pixelMonitors"
        // OnDemand lets the profile-editor text fields take keyboard focus (via
        // forceActiveFocus) without stealing it from the compositor otherwise.
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
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide();
                    event.accepted = true;
                }
            }

            sourceComponent: PixelMonitorsContent {}
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
