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

            // Click-outside-to-close. `active` tracks the open flag rather than
            // being hardcoded `true`: if it were always on, activating the grab
            // while the triggering click is still on the *bar* surface (outside
            // [panelWindow]) makes the compositor emit `cleared` immediately and
            // the panel would close the instant it opens. Guarding onCleared with
            // `if (!active)` further suppresses that spurious clear that fires
            // during activation, matching the ii sidebarRight pattern.
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
                anchors.fill: parent

                // Escape closes the panel. focus follows the open flag so the
                // key handler is live whenever the panel is shown.
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
