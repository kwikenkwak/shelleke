import QtQuick
import qs.modules.paper.common

/**
 * A checkbox. To-dos, repo selection, "also delete the template file".
 *
 *   hairline   — a 12 px `ink-3` RING that fills to a 6 px `ink` dot. No tick
 *                glyph: hairline says "on" with ink, not with a mark.
 *   ledger     — 14 × 14, 1 px `rule-2`, radius 2. On = a solid blue fill with
 *                an `onAccent` check. This is the ledger tick, and the only
 *                place a solid blue fill appears at small size.
 *   broadsheet — 18 px hairline box, radius 2. On = an oxblood `check` glyph on
 *                `accentWash`; the box is never filled solid.
 *
 *   PaperCheck { checked: item.done; onToggled: Todo.markDone(index) }
 */
Item {
    id: root

    property bool checked: false
    signal toggled

    readonly property bool hovered: mouse.containsMouse && root.enabled
    readonly property real boxSize: PaperTheme.pick(12, 14, 18)

    implicitWidth: root.boxSize
    implicitHeight: root.boxSize
    opacity: root.enabled ? 1 : 0.55

    Rectangle {
        id: box
        anchors.fill: parent
        radius: PaperTheme.isHairline ? width / 2 : PaperTheme.radiusControl
        antialiasing: true
        color: root.checked ? (PaperTheme.isLedger ? PaperTheme.accent : PaperTheme.isBroadsheet ? PaperTheme.accentWash : "transparent") : "transparent"
        border.width: PaperTheme.ruleWidth
        border.color: root.checked ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : (root.hovered ? PaperTheme.ink3 : PaperTheme.rule2)

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

    // Hairline: a 6 px inner dot instead of a tick.
    Rectangle {
        anchors.centerIn: parent
        visible: PaperTheme.isHairline && root.checked
        width: PaperTheme.size.dot
        height: PaperTheme.size.dot
        radius: width / 2
        antialiasing: true
        color: PaperTheme.ink
    }

    // Ledger / broadsheet: a real tick.
    PaperIcon {
        anchors.centerIn: parent
        visible: !PaperTheme.isHairline && root.checked
        name: "check"
        size: root.boxSize - PaperTheme.pick(4, 4, 5)
        color: PaperTheme.isLedger ? PaperTheme.onAccent : PaperTheme.accent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -5
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled()
    }
}
