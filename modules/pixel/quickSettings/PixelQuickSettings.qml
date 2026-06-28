import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common

/**
 * Right-side Quick Settings panel for the pixel family.
 *
 * Structure mirrors the KNOWN-WORKING `modules/ii/sidebarRight/SidebarRight.qml`
 * EXACTLY: the PanelWindow is always instantiated and toggled with `visible`
 * (NOT created on-demand by a Loader). A Loader-created surface is mapped at the
 * same instant the focus grab activates, so the grab never attaches and the
 * panel can't be clicked-out closed — keeping the window alive fixes that.
 *
 * Gated by GlobalStates.sidebarRightOpen. Anchored top+bottom+right (full height).
 */
Scope {
    id: root

    PanelWindow {
        id: sidebarRoot
        visible: GlobalStates.sidebarRightOpen

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: 360 // matches PixelQuickSettingsContent's fixed width
        WlrLayershell.namespace: "quickshell:pixelQuickSettings"
        // Hyprland 0.49: focus is always exclusive and setting
        // WlrLayershell.keyboardFocus breaks the mouse focus grab. Leave it unset.
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: grab
            windows: [sidebarRoot]
            active: GlobalStates.sidebarRightOpen
            onCleared: () => {
                if (!active)
                    sidebarRoot.hide();
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.sidebarRightOpen || (Config?.options.sidebar.keepRightSidebarLoaded ?? false)
            anchors.fill: parent

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    sidebarRoot.hide();
                    event.accepted = true;
                }
            }

            sourceComponent: PixelQuickSettingsContent {}
        }
    }

    IpcHandler {
        target: "pixelSidebar"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }
        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "pixelSidebarToggle"
        description: "Toggles the pixel quick-settings sidebar on press"
        onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
    }
    GlobalShortcut {
        name: "pixelSidebarClose"
        description: "Closes the pixel quick-settings sidebar on press"
        onPressed: GlobalStates.sidebarRightOpen = false
    }
}
