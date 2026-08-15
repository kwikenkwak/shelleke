import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.modules.paper.common

/**
 * PaperQuickSettings — §4.3 Quick settings of the paper family.
 *
 * Right-side sidebar, full screen height, `PaperTheme.size.quickSettings` wide
 * (380 / 340 / 360 px), gated by `GlobalStates.sidebarRightOpen` and closed by
 * a HyprlandFocusGrab click-out or Escape.
 *
 * The structure mirrors modules/pixel/quickSettings/PixelQuickSettings.qml
 * EXACTLY, and it has to: the PanelWindow is always instantiated and only its
 * `visible` toggles. A Loader-created surface maps at the same instant the
 * focus grab activates, so the grab never attaches and click-out silently stops
 * closing the panel. Only the CONTENT lives in a Loader.
 *
 * `WlrLayershell.keyboardFocus` is deliberately left UNSET — on Hyprland 0.49
 * setting it breaks the mouse focus grab.
 *
 * IPC target and GlobalShortcut names are the pixel/ii ones on purpose, so the
 * user's existing Hyprland binds keep working. Only one panel family loads at a
 * time, so they cannot collide at runtime.
 */
Scope {
    id: root

    PanelWindow {
        id: sidebarRoot
        visible: GlobalStates.sidebarRightOpen

        function hide(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: PaperTheme.size.quickSettings
        WlrLayershell.namespace: "quickshell:paperQuickSettings"
        // Hyprland 0.49: focus is always exclusive and setting
        // WlrLayershell.keyboardFocus breaks the mouse focus grab. Leave unset.
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
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    sidebarRoot.hide();
                    event.accepted = true;
                }
            }

            sourceComponent: PaperQuickSettingsContent {}
        }
    }

    IpcHandler {
        target: "sidebarRight"

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
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"
        onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"
        onPressed: GlobalStates.sidebarRightOpen = true
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"
        onPressed: GlobalStates.sidebarRightOpen = false
    }
}
