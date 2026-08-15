pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.paper.common

/**
 * The arrangement picker: a two-rectangle diagram over a caps label, answering
 * "where do the other screens go?".
 *
 * The diagram is the point — the primary screen is the marked rectangle and the
 * other one shows the direction, stacked for Above/Below. All three variants
 * draw the same two rectangles and disagree only about how "primary" and
 * "selected" are marked:
 *
 *   hairline   — the primary rectangle is `ink`-bordered and the other `rule-2`;
 *                nothing is filled. Selection is the label's 1 px ink underline.
 *   ledger     — the primary rectangle is FILLED (blue when selected, ink
 *                otherwise) and the whole tile takes the blue frame + wash.
 *   broadsheet — the primary rectangle is filled oxblood when selected; the tile
 *                takes the accent frame and its hover underline.
 *
 *   PaperArrange {
 *       direction: "right"; label: "Right"
 *       checked: Monitors.quickArrange === "right"
 *       onClicked: Monitors.setArrange("right")
 *   }
 *
 * `direction` ∈ right | left | up | down. It only drives the diagram: "up" and
 * "down" stack the rectangles, and "left"/"up" put the secondary one first.
 */
Item {
    id: root

    /// right | left | up | down
    property string direction: "right"
    property string label: ""
    property bool checked: false

    signal clicked

    readonly property bool vertical: root.direction === "up" || root.direction === "down"
    /// The secondary screen leads when the others go left of / above the primary.
    readonly property bool secondaryFirst: root.direction === "left" || root.direction === "up"

    readonly property bool hovered: mouse.containsMouse && root.enabled
    readonly property bool framed: PaperTheme.ornament.framedControls

    readonly property color inkColor: !root.enabled ? PaperTheme.ink4 : root.checked ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : root.hovered ? PaperTheme.ink : PaperTheme.ink2

    /// Rectangle geometry per SPEC: 13 × 9 (hairline / ledger), 12 × 8 (broadsheet).
    readonly property real cellW: PaperTheme.pick(13, 13, 12)
    readonly property real cellH: PaperTheme.pick(9, 9, 8)

    implicitWidth: PaperTheme.pick(64, 56, 56)
    implicitHeight: PaperTheme.pick(52, 52, 50)

    Rectangle {
        anchors.fill: parent
        visible: root.framed
        color: root.checked ? PaperTheme.accentWash : root.hovered ? PaperTheme.wash : (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise)
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        border.width: PaperTheme.ruleWidth
        border.color: root.checked ? PaperTheme.accent : root.hovered ? PaperTheme.rule2 : PaperTheme.rule
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
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

    Column {
        id: content
        anchors.centerIn: parent
        spacing: PaperTheme.pick(7, 5, 5)

        // The diagram.
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: root.vertical ? 1 : 2
            rows: root.vertical ? 2 : 1
            spacing: 2

            Repeater {
                model: 2
                delegate: Rectangle {
                    required property int index
                    readonly property bool primary: index === (root.secondaryFirst ? 1 : 0)

                    width: root.cellW
                    height: root.cellH
                    antialiasing: false
                    radius: 0
                    // Hairline never fills a diagram cell — it marks the primary
                    // with ink on the border and lets the other sit at rule-2.
                    color: (primary && !PaperTheme.isHairline) ? root.inkColor : "transparent"
                    border.width: PaperTheme.ruleWidth
                    border.color: primary ? root.inkColor : PaperTheme.rule2
                }
            }
        }

        PaperText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            role: "micro"
            color: root.inkColor
            font.pixelSize: PaperTheme.pick(9, 9, 8.5)
        }
    }

    // Hairline's selection mark, under the label.
    Rectangle {
        visible: PaperTheme.isHairline && root.enabled && (root.checked || root.hovered)
        height: root.checked ? PaperTheme.markWidth : PaperTheme.ruleWidth
        width: content.width
        color: root.checked ? PaperTheme.ink : PaperTheme.rule2
        antialiasing: false
        x: content.x
        y: content.y + content.height + 4
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
