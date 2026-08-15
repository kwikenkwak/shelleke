import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.paper.common

/**
 * The desktop ground for the paper family.
 *
 * Deliberately NOT a pixelscape. All three SPECs drop the scrolling 1-bit
 * landscape: a moving picture competes with a theme whose entire vocabulary is
 * a 1 px line. What is left is what the specs actually ask for — a plain
 * paper-token field carrying the same grain the panels carry, so the desktop
 * and the shell are cut from one sheet.
 *
 *   hairline   — a flat `paper` field. No grain at all (hairline has none).
 *   ledger     — `paper` plus the 140 px noise tile at 3 % / 5.5 % in dusk.
 *   broadsheet — `paper` plus the same tile at 5.5 %, and a faint 22 px ruling,
 *                the stand-in the previews use for the desk under the sheet.
 *
 * One Bottom-layer PanelWindow per screen, no input, no GlobalStates gate —
 * exactly the lifecycle PixelBackground has. Sizes come from `screen.width` /
 * `screen.height`, NOT from the window: the layer surface can still be 0 × 0
 * shortly after a reload, which used to produce a blank background.
 */
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgRoot
            required property ShellScreen modelData

            screen: bgRoot.modelData
            WlrLayershell.namespace: "quickshell:paperBackground"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore
            color: PaperTheme.paper

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // See the note above: the ShellScreen is the reliable size source.
            readonly property int screenWidth: bgRoot.modelData?.width ?? 0
            readonly property int screenHeight: bgRoot.modelData?.height ?? 0

            Item {
                id: sheet
                width: bgRoot.screenWidth
                height: bgRoot.screenHeight

                // Broadsheet: the desk ruling under the sheet. 22 px apart, at
                // the faintest rule tone — visible only as texture.
                Repeater {
                    model: PaperTheme.isBroadsheet ? Math.ceil(sheet.height / 22) : 0
                    delegate: Rectangle {
                        required property int index
                        y: index * 22
                        width: sheet.width
                        height: PaperTheme.ruleWidth
                        color: PaperTheme.rule
                        opacity: 0.35
                        antialiasing: false
                    }
                }

                // The grain, shared with every panel.
                Image {
                    anchors.fill: parent
                    visible: PaperTheme.ornament.grain && PaperTheme.ornament.grainOpacity > 0
                    source: Qt.resolvedUrl(Quickshell.shellPath("assets/images/paper-grain.png"))
                    fillMode: Image.Tile
                    opacity: PaperTheme.ornament.grainOpacity
                    cache: true
                    smooth: false
                }
            }
        }
    }
}
