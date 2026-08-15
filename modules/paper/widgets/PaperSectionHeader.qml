import QtQuick
import qs.modules.paper.common

/**
 * The theme's ONLY heading device: a micro-caps label, a hairline running to
 * the container edge, and an optional right-hand cut-in (a count, a caps
 * button, a stamp).
 *
 *   PaperSectionHeader { width: parent.width; label: "Connectivity" }
 *   PaperSectionHeader { width: parent.width; label: "Notifications"; meta: "5" }
 *   PaperSectionHeader { width: parent.width; label: "Tasks"; meta: "3 open" }
 *   PaperSectionHeader {                        // a control in the right slot
 *       width: parent.width; label: "Profiles"
 *       PaperButton { shape: "text"; label: "Reload" }
 *   }
 *
 * Per variant:
 *   hairline   — 10 px tracked caps in `ink-3`, a `rule` filling the gap, and
 *                the meta at 11 px `ink-3`.
 *   ledger     — the same, with the meta set in the mono face at `ink-4`.
 *   broadsheet — a KICKER, and NO inline rule: broadsheet separates blocks with
 *                a double rule ABOVE the header instead, so `rule` defaults to
 *                false there. The meta becomes a Pagella-italic footnote.
 *
 * Write `PaperRule { weight: "double" }` before the header and it degrades to a
 * plain hairline in the two variants that have no double rule — which is
 * exactly what their SPECs draw.
 *
 * Children go into the right-hand slot, after the meta.
 */
Item {
    id: root

    /// The label. Uppercased by PaperText's `micro` role.
    property string label: ""
    /// A short right-hand cut-in: a count, "3 open", "5 unread".
    property string meta: ""
    /// Draw the inline hairline. False in broadsheet, whose SPEC rules the
    /// block above the header rather than through it.
    property bool rule: !PaperTheme.isBroadsheet
    /// Rule weight — see PaperRule.
    property string ruleWeight: "hair"
    /// Extra right-hand content (a caps button, a stamp).
    default property alias trailing: trailingRow.data

    readonly property int gap: PaperTheme.pick(14, 8, 8)

    implicitWidth: 200
    implicitHeight: Math.max(labelText.implicitHeight, metaText.implicitHeight, trailingRow.implicitHeight)

    PaperText {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        role: "micro"
        text: root.label
        visible: root.label !== ""
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: PaperTheme.gap.icon
    }

    PaperText {
        id: metaText
        anchors.right: trailingRow.left
        anchors.rightMargin: trailingRow.width > 0 ? root.gap : 0
        anchors.verticalCenter: parent.verticalCenter
        visible: root.meta !== ""
        text: root.meta
        // Ledger sets its cut-ins in the mono face; broadsheet in italic
        // Pagella; hairline in plain 11 px meta. None of the three uppercases
        // the cut-in — that is the label's job, not the count's.
        role: "meta"
        mono: PaperTheme.isLedger
        footnote: PaperTheme.isBroadsheet
        tone: PaperTheme.isHairline ? "ink3" : "ink4"
    }

    PaperRule {
        visible: root.rule && root.width > 0
        weight: root.ruleWeight
        anchors.left: labelText.visible ? labelText.right : parent.left
        anchors.leftMargin: labelText.visible ? root.gap : 0
        anchors.right: metaText.visible ? metaText.left : trailingRow.left
        anchors.rightMargin: (metaText.visible || trailingRow.width > 0) ? root.gap : 0
        anchors.verticalCenter: parent.verticalCenter
        length: -1
    }
}
