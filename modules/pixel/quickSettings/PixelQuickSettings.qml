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
            // Hyprland 0.49: focus is always exclusive and setting
            // WlrLayershell.keyboardFocus breaks the mouse focus grab (the panel
            // never receives `cleared`, so it can't be clicked-out closed and it
            // swallows global keybinds). Leave it unset, matching the
            // KNOWN-WORKING ii sidebarRight.
            color: "transparent"

            // Full screen height: anchor top + bottom + right so the panel fills
            // the entire right edge. Width is content-driven (360px).
            anchors {
                top: true
                bottom: true
                right: true
            }

            implicitWidth: content.implicitWidth

            // Click-outside-to-close. `active` tracks the open flag; guarding
            // onCleared with `if (!active)` suppresses the spurious clear that
            // fires during activation, matching the ii sidebarRight pattern.
            HyprlandFocusGrab {
                id: focusGrab
                windows: [panelWindow]
                active: GlobalStates.sidebarRightOpen
                onCleared: () => {
                    if (!active)
                        GlobalStates.sidebarRightOpen = false;
                }
            }

            PixelQuickSettingsContent {
                id: content
                // Window height is driven by the screen (top+bottom anchors), so
                // give the content the full window height to fill.
                anchors.fill: parent

                // Escape closes the panel. focus follows the open flag so the
                // key handler is live whenever the panel is shown, scoped to the
                // content item rather than grabbing keyboard focus globally.
                focus: GlobalStates.sidebarRightOpen
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.sidebarRightOpen = false;
                        event.accepted = true;
                    }
                }
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
