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
 * Auto-playing black & white top-down landscape background for the pixel family.
 *
 * A separate Rust/Bevy process (modules/pixel/background/pixelscape) headlessly
 * renders a scrolling top-down monochrome map (terrain, mountains, forests,
 * villages, castles joined by roads, with birds) and writes a PNG frame ~twice
 * a second. The frame is black-on-white and inverted in dark mode so it tracks
 * the theme.
 *
 * To avoid the flash that a single reloading Image produces, frames are
 * double-buffered: the next frame is loaded into the hidden back image and only
 * cross-faded in once it is fully Ready — the visible image is never blanked.
 * The renderer runs as one process for all monitors, managed by quickshell.
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

            // The image currently shown. The other one is the hidden back buffer.
            property Image frontImage: imgA
            function backImage(): Image {
                return frontImage === imgA ? imgB : imgA;
            }

            // Each tick, (re)load the back buffer. It's hidden, so its transient
            // blanking never shows; we swap to it only once it's Ready.
            Timer {
                interval: 500
                running: true
                repeat: true
                onTriggered: {
                    const b = bgRoot.backImage();
                    b.source = "";
                    b.source = "file://" + root.framePath;
                }
            }

            // Composited (cross-faded) frame stack, fed into the dark-mode inverter.
            Item {
                id: stack
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Image {
                    id: imgA
                    anchors.fill: parent
                    cache: false
                    smooth: false
                    mipmap: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    opacity: bgRoot.frontImage === imgA ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
                    }
                    onStatusChanged: {
                        // A freshly-loaded back buffer becomes the new front.
                        if (status === Image.Ready && bgRoot.frontImage !== imgA)
                            bgRoot.frontImage = imgA;
                    }
                }

                Image {
                    id: imgB
                    anchors.fill: parent
                    cache: false
                    smooth: false
                    mipmap: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    opacity: bgRoot.frontImage === imgB ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
                    }
                    onStatusChanged: {
                        if (status === Image.Ready && bgRoot.frontImage !== imgB)
                            bgRoot.frontImage = imgB;
                    }
                }
            }

            // Identity in light mode; swapped output levels invert it in dark mode
            // (black/grey on white -> white/grey on black). Tracks PixTheme.dark.
            LevelAdjust {
                anchors.fill: parent
                source: stack
                minimumOutput: PixTheme.dark ? "#ffffffff" : "#00000000"
                maximumOutput: PixTheme.dark ? "#00000000" : "#ffffffff"
            }
        }
    }
}
