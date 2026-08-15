import QtQuick
import qs.modules.paper.common

/**
 * A binary switch. New in this family — the pixel theme had none, because
 * everything was expressed by filling a square.
 *
 *   hairline   — 26 × 9 rail, 6 px knob, 20 px travel, 140 ms. Off: `rule-2`
 *                rail with a hollow `ink-3` knob at the left. On: `ink` rail
 *                with a solid `ink` knob at the right. The knob is the largest
 *                solid ink mark the variant permits.
 *   ledger     — a ruled 30 × 16 slot (1 px `rule-2`, radius 2) with a 10 px
 *                knob. On: blue frame, blue wash, solid blue knob — the same
 *                treatment as every other "on" in the variant.
 *   broadsheet — the same slot with a circular knob (a medallion) and the
 *                oxblood accent; the frame weight never changes, only its
 *                colour, so nothing shifts under the pointer.
 *
 *   PaperSwitch { checked: Audio.sink?.audio?.muted === false
 *                 onToggled: Audio.toggleMute() }
 */
Item {
    id: root

    property bool checked: false
    /// The state means "connected to something out there" — uses the `link` ink.
    property bool connected: false

    /// Emitted on click. The caller owns the state; do not expect the switch to
    /// flip itself (every real toggle here is a round-trip through a service).
    signal toggled

    readonly property bool hovered: mouse.containsMouse && root.enabled
    readonly property color onInk: root.connected ? PaperTheme.link : PaperTheme.accent

    readonly property real railWidth: PaperTheme.pick(26, 30, 30)
    readonly property real railHeight: PaperTheme.pick(9, 16, 16)
    readonly property real knobSize: PaperTheme.pick(6, 10, 10)
    readonly property real inset: PaperTheme.pick(0, 3, 3)

    implicitWidth: root.railWidth
    implicitHeight: Math.max(root.railHeight, root.knobSize)
    opacity: root.enabled ? 1 : 0.55

    // The rail. Hairline draws a bare 1 px line; the other two a ruled slot.
    Rectangle {
        id: rail
        anchors.verticalCenter: parent.verticalCenter
        width: root.railWidth
        height: PaperTheme.isHairline ? PaperTheme.ruleWidth : root.railHeight
        radius: PaperTheme.isHairline ? 0 : PaperTheme.radiusControl
        antialiasing: radius > 0
        color: PaperTheme.isHairline ? (root.checked ? PaperTheme.ink : PaperTheme.rule2) : (root.checked ? (root.connected ? PaperTheme.linkWash : PaperTheme.accentWash) : PaperTheme.paperSunk)
        border.width: PaperTheme.isHairline ? 0 : PaperTheme.ruleWidth
        border.color: root.checked ? root.onInk : (root.hovered ? PaperTheme.ink3 : PaperTheme.rule2)

        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // The knob.
    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        width: root.knobSize
        height: root.knobSize
        // Broadsheet's knob is a medallion; the others are cut square.
        radius: PaperTheme.isBroadsheet ? width / 2 : PaperTheme.pick(width / 2, 1, 1)
        antialiasing: true
        x: root.checked ? root.railWidth - root.knobSize - root.inset : root.inset
        color: root.checked ? root.onInk : (PaperTheme.isHairline ? "transparent" : PaperTheme.paper)
        border.width: root.checked ? 0 : PaperTheme.ruleWidth
        border.color: PaperTheme.ink3

        Behavior on x {
            NumberAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6   // a 9 px rail is not a hit target
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled()
    }
}
