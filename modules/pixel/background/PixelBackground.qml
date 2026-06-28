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
 * Flicker-free updates via double buffering with an INSTANT swap (no fade): the
 * next frame is loaded into the hidden buffer while the current one stays shown;
 * only once the new frame is fully Ready do we flip visibility to it. The shown
 * surface is therefore never blanked, so there is no flash.
 */
Scope {
    id: root
    readonly property string framePath: "/tmp/quickshell/pixel-bg/frame.png"
    readonly property string frameUrl: "file://" + framePath
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

            // Whichever image is currently shown. The other is the back buffer.
            property Image front: imgA

            // Prime the first frame so something appears immediately.
            Component.onCompleted: imgA.source = root.frameUrl

            // Each tick: reload the (hidden) back buffer. The visible front frame
            // stays up untouched; we flip to the back buffer only once it's Ready.
            Timer {
                interval: 500
                running: true
                repeat: true
                onTriggered: {
                    const back = bgRoot.front === imgA ? imgB : imgA;
                    back.source = "";            // force a re-read of the same path
                    back.source = root.frameUrl;
                }
            }

            Item {
                id: stack
                anchors.fill: parent
                // Must stay visible: a non-visible item doesn't render to its
                // layer texture, which would leave LevelAdjust's source empty
                // (the background went pure white). The opaque LevelAdjust on top
                // fully covers it, so showing it underneath is harmless.
                visible: true
                layer.enabled: true

                Image {
                    id: imgA
                    anchors.fill: parent
                    cache: false
                    smooth: false
                    mipmap: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: bgRoot.front === imgA
                    onStatusChanged: {
                        // Back buffer finished loading → swap to it instantly.
                        if (status === Image.Ready && bgRoot.front !== imgA)
                            bgRoot.front = imgA;
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
                    visible: bgRoot.front === imgB
                    onStatusChanged: {
                        if (status === Image.Ready && bgRoot.front !== imgB)
                            bgRoot.front = imgB;
                    }
                }
            }

            // Identity in light mode; swapped output levels invert it in dark mode
            // (black on white -> white on black). Tracks PixTheme.dark.
            // NOTE: outputs must be OPAQUE — an alpha-0 color like "#00000000"
            // makes those pixels transparent (revealing the layer underneath)
            // instead of black, which broke dark-mode inversion.
            LevelAdjust {
                anchors.fill: parent
                source: stack
                minimumOutput: PixTheme.dark ? "#ffffff" : "#000000"
                maximumOutput: PixTheme.dark ? "#000000" : "#ffffff"
            }
        }
    }
}
