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
 * The wallpaper image is fully desaturated (grayscale). In light mode it shows
 * as black/grey on the white theme background; in dark mode it is inverted
 * (white/grey on black) so it tracks the theme. Areas with no image fall back
 * to the theme background color. Rendered on the bottom layer.
 *
 * Kept deliberately simple (no parallax/widgets/video) — the goal is a clean,
 * theme-matched monochrome backdrop.
 */
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot
        required property var modelData
        screen: modelData

        readonly property bool wallpaperIsVideo: {
            const p = Config.options.background.wallpaperPath ?? "";
            return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
        }
        readonly property string wallpaperPath: wallpaperIsVideo
            ? (Config.options.background.thumbnailPath ?? "")
            : (Config.options.background.wallpaperPath ?? "")

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
                anchors.fill: parent
                visible: false
                source: bgRoot.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                sourceSize.width: bgRoot.screen.width
                sourceSize.height: bgRoot.screen.height
            }

            // Grayscale (always). layer.enabled so it can feed the inverter below.
            Desaturate {
                id: gray
                anchors.fill: parent
                source: wallpaper
                desaturation: 1.0
                visible: wallpaper.status === Image.Ready
                layer.enabled: true
            }

            // Dark mode: invert the grayscale (white/grey on black). Drawn opaque
            // over `gray`, so it covers it when shown; hidden in light mode.
            LevelAdjust {
                anchors.fill: parent
                source: gray
                visible: PixTheme.dark && wallpaper.status === Image.Ready
                minimumOutput: "#ffffffff"
                maximumOutput: "#00000000"
            }
        }
    }
}
