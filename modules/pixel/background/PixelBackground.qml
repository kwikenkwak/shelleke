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
 * A separate Rust process (modules/pixel/background/pixelscape) renders the
 * world one SEGMENT at a time on demand: `pixelscape segment <k> <out> <w> <h>`
 * draws the slice whose left edge is world X = k*w. Adjacent segments tile
 * seamlessly (the scene is a pure function of pan), so we lay several screen-wide
 * image tiles side by side and slide them continuously to the left — true smooth
 * scrolling, no per-frame file reload and no stutter. When a tile slides fully
 * off the left it is recycled to the right with the next segment index and its
 * PNG is re-rendered (off-screen, so no flash).
 *
 * Output is pure 1-bit black-on-white; it is inverted in dark mode (opaque
 * LevelAdjust outputs) so it tracks the theme.
 */
Scope {
    id: root
    readonly property string dir: "/tmp/quickshell/pixel-bg"
    readonly property string bin: Quickshell.shellPath("modules/pixel/background/pixelscape/target/release/pixelscape")
    readonly property int segW: 480
    readonly property int segH: 270
    readonly property int tiles: 3
    readonly property real speed: 22 // screen px per second (gentle drift)

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

            readonly property real screenW: width
            readonly property real screenH: height

            // Monotonic scroll offset (screen px). `phase` animates one screen
            // width then re-bases into `baseOffset`, so motion is continuous and
            // the per-leg animation duration stays a sane integer.
            property real baseOffset: 0
            property real phase: 0
            readonly property real offsetPx: baseOffset + phase

            NumberAnimation {
                id: scrollAnim
                target: bgRoot
                property: "phase"
                from: 0
                to: bgRoot.screenW
                duration: Math.max(1, Math.round(bgRoot.screenW / root.speed * 1000))
                easing.type: Easing.Linear
                onFinished: {
                    bgRoot.baseOffset += bgRoot.screenW;
                    bgRoot.phase = 0;
                    scrollAnim.start();
                }
            }

            Component.onCompleted: {
                if (bgRoot.screenW > 0)
                    scrollAnim.start();
                recycleTimer.start();
            }

            // Recycle tiles that have fully exited the left edge.
            Timer {
                id: recycleTimer
                interval: 150
                repeat: true
                running: false
                onTriggered: {
                    for (let i = 0; i < root.tiles; i++) {
                        const t = rep.itemAt(i);
                        if (t && (t.seg * bgRoot.screenW - bgRoot.offsetPx + bgRoot.screenW) < -2)
                            t.recycle();
                    }
                }
            }

            Item {
                id: stack
                anchors.fill: parent
                clip: true
                layer.enabled: true

                Repeater {
                    id: rep
                    model: root.tiles

                    delegate: Item {
                        id: tile
                        required property int index
                        property int seg: index
                        readonly property string file: root.dir + "/seg_" + index + ".png"

                        width: bgRoot.screenW
                        height: bgRoot.screenH
                        x: tile.seg * bgRoot.screenW - bgRoot.offsetPx

                        Image {
                            id: im
                            anchors.fill: parent
                            smooth: false
                            mipmap: false
                            cache: false
                            asynchronous: true
                            fillMode: Image.Stretch // exact fill so tiles abut seamlessly
                        }

                        // One-shot renderer per tile; reload (off-screen) when done.
                        Process {
                            id: gen
                            onExited: {
                                im.source = "";
                                im.source = "file://" + tile.file;
                            }
                        }

                        function render(): void {
                            gen.running = false;
                            gen.command = [root.bin, "segment", String(tile.seg), tile.file, String(root.segW), String(root.segH)];
                            gen.running = true;
                        }
                        function recycle(): void {
                            tile.seg += root.tiles;
                            tile.render();
                        }

                        Component.onCompleted: render()
                    }
                }
            }

            // Identity in light mode; swapped OPAQUE output levels invert it in
            // dark mode (black on white -> white on black). Tracks PixTheme.dark.
            LevelAdjust {
                anchors.fill: parent
                source: stack
                minimumOutput: PixTheme.dark ? "#ffffff" : "#000000"
                maximumOutput: PixTheme.dark ? "#000000" : "#ffffff"
            }
        }
    }
}
