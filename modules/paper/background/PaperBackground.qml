import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.modules.paper.common

/**
 * The desktop ground for the paper family: a paper field with a picture on it.
 *
 * Deliberately NOT a pixelscape — a moving picture competes with a theme whose
 * entire vocabulary is a 1 px line. What hangs here instead is a *plate*: one
 * public-domain engraving, chart, map or woodblock, held as pure ink density
 * (see PaperPlates and scripts/paper/fetch_plates.py). Because the plate carries
 * no paper of its own, this file lays it on the variant's `paper` token and
 * tints it with the variant's ink — so a live variant switch or a dark-mode
 * toggle re-inks the same asset with no reload, exactly like the panels.
 *
 * The stack, bottom to top:
 *   paper       the variant's `paper` token, as the window colour
 *   desk ruling broadsheet's faint 22 px ruling — the desk under the sheet.
 *               Dropped while a plate hangs; the picture IS the texture then.
 *   the plate   `bleed` fills the screen, `motif` is a print laid on the sheet
 *   grain       the same 140 px noise tile every panel carries, over everything,
 *               so the desktop and the shell are cut from one sheet
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

                readonly property bool hasPlate: PaperPlates.plate !== null && PaperPlates.inkOpacity > 0

                // Broadsheet: the desk ruling under the sheet. 22 px apart, at
                // the faintest rule tone — visible only as texture.
                Repeater {
                    model: (PaperTheme.backdrop.deskRuling && !sheet.hasPlate) ? Math.ceil(sheet.height / PaperTheme.backdrop.deskRulingPitch) : 0
                    delegate: Rectangle {
                        required property int index
                        y: index * PaperTheme.backdrop.deskRulingPitch
                        width: sheet.width
                        height: PaperTheme.ruleWidth
                        color: PaperTheme.rule
                        opacity: 0.35
                        antialiasing: false
                    }
                }

                // The plate of the day. A Loader keeps the whole image pipeline
                // out of the tree when the backdrop is off or the collection is
                // empty, rather than leaving a 0-opacity texture resident.
                Loader {
                    active: sheet.hasPlate
                    width: sheet.width
                    height: sheet.height

                    sourceComponent: Item {
                        anchors.fill: parent

                        Item {
                            id: slot

                            readonly property bool bleed: PaperPlates.layout === "bleed"
                            readonly property real aspect: Math.max(PaperPlates.aspect, 0.05)

                            /// The slot is ALWAYS exactly the plate's own aspect, and
                            /// the image simply fills it. That is deliberate: the
                            /// ColorOverlay below samples the Image's texture
                            /// directly, which bypasses `fillMode` — matched geometry
                            /// is what keeps the picture undistorted, not a fillMode.
                            ///
                            /// `bleed` sizes the slot to COVER the screen; the
                            /// overhang falls outside the window and is never
                            /// rendered. `motif` is a print laid on the sheet:
                            /// `scale` of the screen's height, but never more than
                            /// 88 % of its width, so a wide plate cannot run off both
                            /// edges of a 16:9 panel.
                            readonly property real motifHeight: Math.min(sheet.height * PaperPlates.plateScale, (sheet.width * 0.88) / slot.aspect)

                            height: Math.round(slot.bleed ? Math.max(sheet.height, sheet.width / slot.aspect) : slot.motifHeight)
                            width: Math.round(slot.height * slot.aspect)
                            y: Math.round((sheet.height - slot.height) / 2)
                            x: {
                                if (slot.bleed)
                                    return Math.round((sheet.width - slot.width) / 2);
                                const inset = Math.round(sheet.width * 0.06);
                                if (PaperPlates.align === "left")
                                    return inset;
                                if (PaperPlates.align === "right")
                                    return sheet.width - slot.width - inset;
                                return Math.round((sheet.width - slot.width) / 2);
                            }

                            // Held at 0 until the plate is decoded, so a new
                            // picture fades in rather than popping — this is the
                            // one animation on the desktop.
                            opacity: plateImage.status === Image.Ready ? PaperPlates.inkOpacity : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: PaperTheme.motion.slow
                                    easing.type: PaperTheme.motion.type
                                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                                }
                            }

                            Image {
                                id: plateImage
                                anchors.fill: parent
                                source: PaperPlates.source
                                // Stretch, and correct: the slot carries the
                                // plate's aspect (see above).
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                                // The ColorOverlay below is what actually shows:
                                // the plate's own pixels are black, the theme's
                                // ink is not.
                                visible: false
                            }

                            ColorOverlay {
                                anchors.fill: plateImage
                                source: plateImage
                                color: PaperTheme.backdrop.plateInk
                            }
                        }
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
