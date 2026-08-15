pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.paper.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PaperOnScreenDisplay — §4.5 On-screen display of the paper family.
 *
 * A `Loader` gated on `GlobalStates.osdVolumeOpen || .osdBrightnessOpen`
 * produces one overlay `PanelWindow` on the focused screen, horizontally
 * centred, anchored top (or bottom when `Config.options.bar.bottom`), at
 * `PaperTheme.size.osdTop` = barHeight + 14. `exclusiveZone: 0`,
 * `ExclusionMode.Ignore`, region-masked to the sheet so it never eats a click.
 * Creating this window on demand is safe: it takes no keyboard focus and no
 * focus grab, so the grab-lifetime trap in HANDOFF.md §5.3 does not apply.
 *
 * The panel is raised by any volume or brightness change — bar scroll, media
 * keys, IPC, global shortcuts — and hidden again after
 * `Config.options.osd.timeout` (1000 ms). Hovering the sheet dismisses it at
 * once.
 *
 * Services: `Audio.sink?.audio` (volume, muted) and
 * `Brightness.getMonitorForScreen(screen)` plus the `Brightness`
 * `onBrightnessChanged` signal, exactly as the pixel OSD wires them.
 *
 * IPC NAMING — deliberate wart, see HANDOFF.md §5.2. The targets and shortcuts
 * keep the pixel family's `pixelOsd*` names ("pixelOsdVolume",
 * "pixelOsdBrightness", "pixelOsdVolumeTrigger", "pixelOsdBrightnessTrigger",
 * "pixelOsdHide") because the user's Hyprland binds point at them. Only one
 * panel family is loaded at a time, so the names cannot collide at runtime.
 * Do not "fix" them.
 */
Scope {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

    /// "volume" | "brightness" — which meter the sheet is showing.
    property string currentIndicator: "volume"
    readonly property bool anyOpen: GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen

    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.focusedScreen)

    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property real volumeValue: Audio.sink?.audio?.volume ?? 0
    readonly property real brightnessValue: root.brightnessMonitor?.brightness ?? 0

    readonly property bool showingBrightness: root.currentIndicator === "brightness"
    readonly property real shownValue: root.showingBrightness ? root.brightnessValue : root.volumeValue
    /// Brightness is never "muted"; only the sink can be.
    readonly property bool shownMuted: !root.showingBrightness && root.muted
    readonly property string shownLabel: root.showingBrightness ? Translation.tr("Brightness") : Translation.tr("Volume")

    function triggerVolume(): void {
        root.currentIndicator = "volume";
        GlobalStates.osdBrightnessOpen = false;
        GlobalStates.osdVolumeOpen = true;
        osdTimeout.restart();
    }

    function triggerBrightness(): void {
        root.currentIndicator = "brightness";
        GlobalStates.osdVolumeOpen = false;
        GlobalStates.osdBrightnessOpen = true;
        osdTimeout.restart();
    }

    function hideOsd(): void {
        GlobalStates.osdVolumeOpen = false;
        GlobalStates.osdBrightnessOpen = false;
    }

    Timer {
        id: osdTimeout
        interval: Config.options?.osd?.timeout ?? 1000
        repeat: false
        running: false
        onTriggered: root.hideOsd()
    }

    // Keep the timer alive when the OSD is raised by something that did not go
    // through trigger*() — an IPC toggle, for instance.
    onAnyOpenChanged: {
        if (root.anyOpen)
            osdTimeout.restart();
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(): void {
            root.triggerBrightness();
        }
    }

    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged(): void {
            if (!Audio.ready)
                return;
            root.triggerVolume();
        }
        function onMutedChanged(): void {
            if (!Audio.ready)
                return;
            root.triggerVolume();
        }
    }

    Loader {
        id: osdLoader
        active: root.anyOpen

        sourceComponent: PanelWindow {
            id: osdWindow

            color: "transparent"
            screen: root.focusedScreen
            visible: osdLoader.active

            // Defensive, and mirrored from the pixel OSD: Quickshell writes to
            // `screen` itself, which can break the binding above. Re-assert it.
            Connections {
                target: root
                function onFocusedScreenChanged(): void {
                    osdWindow.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:paperOnScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: !(Config.options?.bar?.bottom ?? false)
                bottom: Config.options?.bar?.bottom ?? false
            }
            margins {
                top: PaperTheme.size.osdTop
                bottom: PaperTheme.size.osdTop
            }

            implicitWidth: osdPanel.implicitWidth
            implicitHeight: osdPanel.implicitHeight

            mask: Region {
                item: osdPanel
            }

            OsdPanel {
                id: osdPanel
                anchors.horizontalCenter: parent.horizontalCenter

                indicator: root.currentIndicator
                value: root.shownValue
                muted: root.shownMuted
                label: root.shownLabel

                onDismissRequested: root.hideOsd()
            }
        }
    }

    // ------------------------------------------------------------------ IPC
    // The `pixelOsd*` names are intentional — see the class comment.

    IpcHandler {
        target: "pixelOsdVolume"
        function trigger(): void {
            root.triggerVolume();
        }
        function hide(): void {
            root.hideOsd();
        }
        function toggle(): void {
            if (root.anyOpen)
                root.hideOsd();
            else
                root.triggerVolume();
        }
    }

    IpcHandler {
        target: "pixelOsdBrightness"
        function trigger(): void {
            root.triggerBrightness();
        }
        function hide(): void {
            root.hideOsd();
        }
    }

    GlobalShortcut {
        name: "pixelOsdVolumeTrigger"
        description: "Triggers volume OSD on press"
        onPressed: root.triggerVolume()
    }
    GlobalShortcut {
        name: "pixelOsdBrightnessTrigger"
        description: "Triggers brightness OSD on press"
        onPressed: root.triggerBrightness()
    }
    GlobalShortcut {
        name: "pixelOsdHide"
        description: "Hides OSD on press"
        onPressed: root.hideOsd()
    }
}
