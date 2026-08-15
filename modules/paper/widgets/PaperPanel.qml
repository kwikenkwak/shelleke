import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.paper.common

/**
 * The container primitive — a sheet of paper. Replaces PixPanel.
 *
 * This is NOT a window. Surfaces still build their own `PanelWindow` /
 * `PopupWindow` (see HANDOFF.md §Windowing) and put a PaperPanel inside it,
 * exactly as the pixel family puts a PixPanel inside its windows.
 *
 *   PaperPanel { anchors.fill: parent }                        // a floating sheet
 *   PaperPanel { kind: "sheet"; docked: true; edgeRight: false } // a right-docked sidebar
 *   PaperPanel { kind: "card" }                                 // an inline card
 *   PaperPanel { kind: "well" }                                 // a recessed log box
 *
 * Per variant:
 *   hairline   — sheet = `paper` + one 1 px `rule` border, radius 0, no shadow,
 *                no grain. `card` draws NOTHING (hairline has no cards; blocks
 *                are separated by whitespace and rules), `well` is a tone shift
 *                with no border. This is deliberate: writing `kind: "card"` in
 *                shared surface code stays correct, it just disappears in A.
 *   ledger     — sheet = `paperRaise` + 1 px `rule2` + radius 3 + shadow when
 *                floating; card = `paperRaise` + 1 px `rule` + radius 2;
 *                well = `paperSunk` + 1 px `rule`.
 *   broadsheet — sheet = `paper` + 1 px `rule2` + radius 0 + grain + shadow when
 *                floating + optional corner ticks; card = `paperSunk` + `rule`.
 *
 * A sheet that touches a screen edge drops the border on that edge: set
 * `edgeLeft/edgeRight/edgeTop/edgeBottom` false. The bar sets everything false
 * except `edgeBottom` and gets an Oxford rule there in broadsheet by setting
 * `bottomWeight: "oxford"`.
 */
Rectangle {
    id: root

    /// sheet | card | well
    property string kind: "sheet"
    /// A surface that genuinely floats over the desktop takes the shadow.
    /// Docked sidebars never do.
    property bool floating: false
    /// Corner ticks on a floating or focused sheet (broadsheet only).
    property bool ticks: false
    /// Tick colour. `rule2` is the resting tick; a SELECTED tile (the focused
    /// exposé workspace, the active profile card) ticks in `accent` instead, so
    /// the mark says "this one" rather than "this floats".
    property color tickColor: PaperTheme.rule2
    /// Border edges. Drop the one that meets a screen edge.
    property bool edgeTop: true
    property bool edgeBottom: true
    property bool edgeLeft: true
    property bool edgeRight: true
    /// Per-edge rule weight overrides — see PaperRule.
    property string edgeWeight: root.kind === "sheet" ? "fine" : "hair"
    property string bottomWeight: root.edgeWeight
    /// Accent the whole frame (an active card, a failed log box).
    property string frameTone: ""
    /// Suppress the grain on this surface.
    property bool grain: PaperTheme.ornament.grain

    readonly property bool drawsFrame: !(PaperTheme.isHairline && root.kind !== "sheet")

    color: root.kind === "well" ? PaperTheme.paperSunk : root.kind === "card" ? (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise) : PaperTheme.paperRaise
    radius: root.kind === "sheet" ? PaperTheme.radiusSheet : PaperTheme.radiusCard
    antialiasing: root.radius > 0
    border.width: 0

    Behavior on color {
        ColorAnimation {
            duration: PaperTheme.motion.fast
            easing.type: PaperTheme.motion.type
            easing.bezierCurve: PaperTheme.motion.bezierCurve
        }
    }

    // The grain: one 140 px noise tile multiplied over every paper ground at
    // 3 % (light) / 5.5 % (dusk). Below the threshold of notice at arm's
    // length — you feel it, you do not see it.
    Image {
        anchors.fill: parent
        visible: root.grain && PaperTheme.ornament.grainOpacity > 0
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/images/paper-grain.png"))
        fillMode: Image.Tile
        opacity: PaperTheme.ornament.grainOpacity
        cache: true
        smooth: false
        z: 0
    }

    // Edges. Drawn individually rather than with border.width so a docked panel
    // can drop the edge that meets the screen and the bar can carry an Oxford
    // rule on its bottom only.
    PaperRule {
        visible: root.edgeTop && root.drawsFrame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        weight: root.edgeWeight
        tone: root.frameTone
        z: 2
    }
    PaperRule {
        visible: root.edgeBottom && root.drawsFrame
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        weight: root.bottomWeight
        tone: root.frameTone
        z: 2
    }
    PaperRule {
        visible: root.edgeLeft && root.drawsFrame
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        vertical: true
        weight: root.edgeWeight
        tone: root.frameTone
        z: 2
    }
    PaperRule {
        visible: root.edgeRight && root.drawsFrame
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        vertical: true
        weight: root.edgeWeight
        tone: root.frameTone
        z: 2
    }

    // Corner ticks — a 6 × 6 px L inset 4 px, marking a floating or focused
    // sheet. Broadsheet only.
    Repeater {
        model: (root.ticks && PaperTheme.ornament.cornerTicks) ? 4 : 0
        delegate: Item {
            id: tick
            required property int index
            readonly property bool atRight: tick.index === 1 || tick.index === 2
            readonly property bool atBottom: tick.index >= 2
            x: tick.atRight ? root.width - 4 - 6 : 4
            y: tick.atBottom ? root.height - 4 - 6 : 4
            width: 6
            height: 6
            z: 3
            Rectangle {
                x: 0
                y: tick.atBottom ? 5 : 0
                width: 6
                height: 1
                color: root.tickColor
                antialiasing: false
            }
            Rectangle {
                x: tick.atRight ? 5 : 0
                y: 0
                width: 1
                height: 6
                color: root.tickColor
                antialiasing: false
            }
        }
    }

    // A whisper of shadow, and only on surfaces that genuinely float.
    // NOTE: because this is a layer effect, the shadow is clipped to the sheet's
    // own bounds. That is fine for a 5 %/9 % warm drop; a surface that wants the
    // full bloom should wrap the panel in an Item with `PaperTheme.shadow.radius`
    // of margin and put the MultiEffect there.
    layer.enabled: root.floating && PaperTheme.ornament.shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: PaperTheme.shadow.color
        shadowBlur: 1.0
        shadowVerticalOffset: PaperTheme.shadow.verticalOffset
        blurMax: PaperTheme.shadow.radius
    }
}
