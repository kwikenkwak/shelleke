pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The clock hover popup: the full date, the uptime, and the To Do list.
 * Same data as `PixClockPopup` (§4.2 of the pixel SPEC), retypeset.
 *
 *   hairline   — `calendar` glyph + the date in `lead`; `clock` + "System
 *                uptime" + the value in mono; a hairline; a `To do · N pending`
 *                section header; up to five items as a mono `ink-4` numeral and
 *                the text at 12 px.
 *   ledger     — the same date in Charter 15, then `UPTIME` and `WEEK` as
 *                dotted leaders, a hairline, the `TO DO` head with the count
 *                cut in after the rule, then the items.
 *   broadsheet — the date as a Pagella masthead over an OXFORD rule, the uptime
 *                as a kicker with the value right-aligned in oldstyle figures,
 *                a DOUBLE rule, then `To do` / `N pending` and the items with
 *                oxblood oldstyle numerals.
 *
 * Null-safe against DateTime and Todo.
 */
Column {
    id: root

    readonly property int sheetWidth: PaperTheme.pick(360, 296, 310)
    readonly property var now: DateTime.clock?.date ?? new Date()
    readonly property string formattedDate: Qt.locale().toString(root.now, PaperTheme.pick("dddd, MMMM dd, yyyy", "dddd, d MMMM yyyy", "dddd, d MMMM yyyy"))

    readonly property var pending: (Todo?.list ?? []).filter(item => !item.done)
    readonly property var shown: root.pending.slice(0, 5)
    readonly property int overflow: Math.max(0, root.pending.length - 5)

    /// ISO week number and day of the year — ledger's second leader.
    readonly property string weekText: {
        const d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
        const target = new Date(d.valueOf());
        target.setDate(target.getDate() + 3 - ((d.getDay() + 6) % 7));
        const firstThursday = new Date(target.getFullYear(), 0, 4);
        firstThursday.setDate(firstThursday.getDate() + 3 - ((firstThursday.getDay() + 6) % 7));
        const week = 1 + Math.round((target - firstThursday) / 604800000);
        const dayOfYear = 1 + Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000);
        return `${week} · day ${dayOfYear}`;
    }

    width: root.sheetWidth
    spacing: PaperTheme.pick(10, 5, 7)

    // ---- the date ---------------------------------------------------------
    Row {
        spacing: PaperTheme.pick(12, 9, 9)
        PaperIcon {
            // Broadsheet's masthead carries no glyph — the rule under it is the
            // structure.
            visible: !PaperTheme.isBroadsheet
            anchors.verticalCenter: parent.verticalCenter
            name: "calendar"
            size: PaperTheme.icon.control
            color: PaperTheme.ink2
        }
        PaperTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formattedDate
            role: PaperTheme.isHairline ? "lead" : "title"
            caps: false
        }
    }

    // Broadsheet's Oxford rule under the masthead (a plain hairline elsewhere,
    // which is why it is gated rather than written unconditionally).
    Item {
        visible: PaperTheme.ornament.oxfordRules
        width: parent.width
        implicitHeight: oxford.thickness + PaperTheme.spacing.tiny
        PaperRule {
            id: oxford
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            weight: "oxford"
        }
    }

    BarValueRow {
        width: parent.width
        icon: "clock"
        // Ledger's SPEC names this leader UPTIME; the other two spell it out.
        label: PaperTheme.isLedger ? "Uptime" : "System uptime"
        value: DateTime.uptime
        kicker: true
    }

    BarValueRow {
        visible: PaperTheme.isLedger
        width: parent.width
        label: "Week"
        value: root.weekText
    }

    // ---- the To Do block --------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: blockRule.thickness + PaperTheme.pick(18, 11, 12)
        PaperRule {
            id: blockRule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            weight: "double"
        }
    }

    // The shared heading device. Its `rule` already defaults to false in
    // broadsheet, whose preview sets this head as a kicker + cut-in with the
    // block ruled off above instead — which is the double rule just written.
    PaperSectionHeader {
        width: parent.width
        label: "To do"
        meta: root.pending.length > 0 ? `${root.pending.length} pending` : ""
    }

    Repeater {
        model: root.shown
        delegate: Row {
            id: taskRow
            required property int index
            required property var modelData
            width: root.width
            spacing: PaperTheme.pick(12, 9, 9)

            PaperText {
                anchors.baseline: taskText.baseline
                width: PaperTheme.pick(12, 12, 14)
                horizontalAlignment: PaperTheme.isBroadsheet ? Text.AlignRight : Text.AlignLeft
                text: PaperTheme.isHairline ? `${taskRow.index + 1}` : `${taskRow.index + 1}.`
                figure: true
                tone: PaperTheme.isBroadsheet ? "accent" : "ink4"
                font.pixelSize: PaperTheme.pick(11, 10, 12)
            }
            PaperText {
                id: taskText
                width: taskRow.width - PaperTheme.pick(12, 12, 14) - taskRow.spacing
                text: taskRow.modelData?.content ?? ""
                role: "small"
                tone: "ink2"
                font.family: PaperTheme.isBroadsheet ? PaperTheme.fontSerif : PaperTheme.fontBody
                font.pixelSize: PaperTheme.isBroadsheet ? 12.5 : PaperTheme.font.size.small
                elide: Text.ElideRight
            }
        }
    }

    PaperText {
        visible: root.overflow > 0
        leftPadding: PaperTheme.pick(24, 21, 23)
        text: `… and ${root.overflow} more`
        role: "meta"
        tone: "ink4"
        footnote: true
    }

    PaperText {
        visible: root.pending.length === 0
        text: "No pending tasks"
        role: "small"
        tone: "ink4"
        footnote: true
    }
}
