pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Monochrome wallpaper for the pixel family.
 *
 * Pipeline: desaturate -> boost contrast -> (dark mode) invert. The invert is
 * done by swapping LevelAdjust's output levels based on PixTheme.dark, so it
 * reliably flips when the theme toggles: black/grey on white in light mode,
 * white/grey on black in dark mode. The theme background fills behind it.
 *
 * Parallax: the wallpaper is zoomed slightly and panned with the active
 * workspace (and a nudge when the sidebar opens), like the ii background.
 */
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot
        required property var modelData
        screen: modelData

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
        readonly property bool wallpaperIsVideo: {
            const p = Config.options.background.wallpaperPath ?? "";
            return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
        }
        readonly property string wallpaperPath: wallpaperIsVideo
            ? (Config.options.background.thumbnailPath ?? "")
            : (Config.options.background.wallpaperPath ?? "")

        // ---- Parallax ----
        readonly property real zoom: Math.max(1.0, Config.options.background.parallax.workspaceZoom ?? 1.08)
        readonly property int workspacesShown: Config.options.bar.workspaces.shown ?? 10
        readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
        readonly property int wsGroupLower: Math.floor((activeWsId - 1) / workspacesShown) * workspacesShown
        readonly property real wsFraction: workspacesShown > 1
            ? (activeWsId - wsGroupLower - 1) / (workspacesShown - 1) : 0.5
        readonly property real valueX: {
            let v = (Config.options.background.parallax.enableWorkspace ?? true) ? wsFraction : 0.5;
            if (Config.options.background.parallax.enableSidebar ?? true)
                v += 0.12 * (GlobalStates.sidebarRightOpen ? 1 : 0) - 0.12 * (GlobalStates.sidebarLeftOpen ? 1 : 0);
            return Math.max(0, Math.min(1, v));
        }
        readonly property real movableX: bgRoot.screen.width * (zoom - 1) / 2
        readonly property real movableY: bgRoot.screen.height * (zoom - 1) / 2

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:pixelBackground"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        // Theme background fills any uncovered area (and shows if no wallpaper).
        color: PixTheme.colors.bg

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: wallpaper
                visible: false
                width: bgRoot.screen.width * bgRoot.zoom
                height: bgRoot.screen.height * bgRoot.zoom
                x: -bgRoot.movableX - (bgRoot.valueX - 0.5) * 2 * bgRoot.movableX
                y: -bgRoot.movableY
                Behavior on x {
                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                }
                source: bgRoot.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                sourceSize.width: bgRoot.screen.width * bgRoot.zoom
                sourceSize.height: bgRoot.screen.height * bgRoot.zoom
            }

            // Grayscale (intermediate, fed to the next stage).
            Desaturate {
                id: gray
                anchors.fill: wallpaper
                source: wallpaper
                desaturation: 1.0
                visible: false
                layer.enabled: true
            }

            // Boost contrast so it reads as crisp black/grey/white, not washed out.
            BrightnessContrast {
                id: punch
                anchors.fill: wallpaper
                source: gray
                brightness: 0.0
                contrast: 0.45
                visible: false
                layer.enabled: true
            }

            // Final stage: identity in light mode, inverted output in dark mode.
            // Swapping the output levels (bound to PixTheme.dark) flips reliably
            // whenever the theme toggles.
            LevelAdjust {
                anchors.fill: wallpaper
                source: punch
                visible: wallpaper.status === Image.Ready
                minimumOutput: PixTheme.dark ? "#ffffffff" : "#00000000"
                maximumOutput: PixTheme.dark ? "#00000000" : "#ffffffff"
            }
        }
    }
}
