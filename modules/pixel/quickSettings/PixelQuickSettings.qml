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
 * Mirrors WaffleActionCenter's structure (Loader -> PanelWindow gated by a
 * GlobalStates open flag + HyprlandFocusGrab), but anchored top + right and
 * styled monochrome. Gated by GlobalStates.sidebarRightOpen.
 */
Scope {
    id: root

    function toggleOpen() {
        GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
    }

    Connections {
        target: GlobalStates

        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen)
                panelLoader.active = true;
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.sidebarRightOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:pixelQuickSettings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                right: true
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            HyprlandFocusGrab {
                id: focusGrab
                active: true
                windows: [panelWindow]
                onCleared: GlobalStates.sidebarRightOpen = false
            }

            PixelQuickSettingsContent {
                id: content
            }
        }
    }

    IpcHandler {
        target: "pixelSidebar"

        function toggle() {
            root.toggleOpen();
        }
    }

    GlobalShortcut {
        name: "pixelSidebarToggle"
        description: "Toggles the pixel quick-settings sidebar on press"

        onPressed: root.toggleOpen()
    }
}
