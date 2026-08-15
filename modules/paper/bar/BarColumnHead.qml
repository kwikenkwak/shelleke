import QtQuick
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The head of one column in the system-monitor popup.
 *
 * NOT the same device as `PaperSectionHeader` — that one runs its hairline
 * THROUGH the heading, which is right for a section inside a panel. A column
 * head rules UNDER itself, because the rule is what turns the rows beneath it
 * into a table:
 *
 *   hairline   — a micro-caps label with a hairline running to the column edge
 *                (hairline genuinely does use the inline form here).
 *   ledger     — a line icon and a caps label over a `rule-2` hairline.
 *   broadsheet — a glyph and a kicker over a DOUBLE rule.
 *
 * If a second surface ever wants this, it is a candidate for promotion into
 * `modules/paper/widgets/` as `PaperColumnHead` (or as an `underline:` mode on
 * `PaperSectionHeader`).
 */
Item {
    id: root

    property string label: ""
    /// A leading glyph. Hairline's column heads carry none.
    property string icon: ""

    /// Ledger and broadsheet rule under the head; hairline rules through it.
    readonly property bool underline: !PaperTheme.isHairline
    readonly property real gap: PaperTheme.pick(12, 7, 7)

    implicitWidth: 190
    implicitHeight: head.implicitHeight + (root.underline ? PaperTheme.spacing.xs + underRule.thickness : 0)

    Row {
        id: head
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: root.gap

        PaperIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: PaperTheme.icon.control
            color: PaperTheme.ink2
        }
        PaperText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            role: "micro"
            tone: PaperTheme.isHairline ? "ink3" : "ink2"
        }
    }

    // Hairline: the rule runs from the label to the column edge.
    PaperRule {
        visible: !root.underline
        anchors.left: head.right
        anchors.leftMargin: root.gap
        anchors.right: parent.right
        anchors.verticalCenter: head.verticalCenter
        length: -1
    }

    // Ledger / broadsheet: the rule closes the head and opens the table.
    PaperRule {
        id: underRule
        visible: root.underline
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: PaperTheme.spacing.xs
        weight: PaperTheme.isBroadsheet ? "double" : "fine"
    }
}
