pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.pixel.common
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Auto-playing black & white landscape background for the pixel family.
 *
 * Instead of a wallpaper, a separate Rust/Bevy process
 * (modules/pixel/background/pixelscape) headlessly renders a scrolling
 * monochrome scene — rolling terrain with mountains, forests, villages and
 * castles joined by roads — and writes a PNG frame ~twice a second. quickshell
 * reloads that frame and upscales it nearest-neighbor (chunky pixels). The
 * frame is black-on-white; it is inverted in dark mode so it tracks the theme.
 *
 * The renderer runs as one process for all monitors (a single shared frame),
 * managed by quickshell so it dies with the shell / on family switch.
 */
Scope {
    id: root
    readonly property string framePath: "/tmp/quickshell/pixel-bg/frame.png"
    readonly property int frameWidth: 480
    readonly property int frameHeight: 270

    Process {
        id: pixelscape
        running: true
        command: [
            Quickshell.shellPath("modules/pixel/background/pixelscape/target/release/pixelscape"),
            root.framePath,
            String(root.frameWidth),
            String(root.frameHeight)
        ]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgRoot
            required property var modelData
            screen: modelData

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:pixelBackground"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: PixTheme.colors.bg

            // Reload the frame ~every half second (the renderer's tick rate).
            // Clearing then re-setting the source forces a re-read of the file;
            // a "?query" cache-bust isn't reliable for file:// URLs.
            Timer {
                interval: 500
                running: true
                repeat: true
                onTriggered: {
                    frame.source = "";
                    frame.source = "file://" + root.framePath;
                }
            }

            Item {
                anchors.fill: parent
                clip: true

                Image {
                    id: frame
                    anchors.fill: parent
                    visible: false
                    cache: false
                    smooth: false
                    mipmap: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    // Re-read each tick via the Timer above (atomic writes on the
                    // renderer side mean we never read a torn frame).
                    source: "file://" + root.framePath
                }

                // The frame is already black/white; invert it in dark mode so it
                // matches the theme (black/grey on white -> white/grey on black).
                LevelAdjust {
                    anchors.fill: parent
                    source: frame
                    visible: frame.status === Image.Ready
                    minimumOutput: PixTheme.dark ? "#ffffffff" : "#00000000"
                    maximumOutput: PixTheme.dark ? "#00000000" : "#ffffffff"
                }
            }
        }
    }
}
