import QtQuick
import qs.modules.paper.common

/**
 * A key/value row — the ledger variant's signature, and the theme's answer to
 * "put a label next to a number".
 *
 *   ledger     — `[CAPS KEY] ··············· [mono value]`, joined by a 1 px
 *                dotted `ink-4` leader on the baseline. It is why the shell
 *                reads as bookkeeping rather than as a dashboard.
 *   hairline   — no leader. A micro-caps key, then whitespace, then the value
 *                in mono, right-aligned. (Hairline has exactly one line weight
 *                and spends it on structure, not on decoration.)
 *   broadsheet — no leader either: small-caps keys in a fixed 74 px column and
 *                mono values, set as a real table.
 *
 *   PaperKV { key: "Path"; value: "~/pleevi/hairline-theme" }
 *   PaperKV { key: "Uptime"; value: DateTime.uptime; figure: true }
 *
 * Put several in a Column with no spacing for a summary block; the fixed key
 * column in broadsheet makes them line up by itself.
 */
Item {
    id: root

    property string key: ""
    property string value: ""
    /// Set the value in the numeral face (tabular / oldstyle) instead of mono.
    property bool figure: false
    property string valueTone: "ink"
    /// Override the fixed key column width. -1 = the variant's default
    /// (broadsheet 74 px, others: natural width).
    property real keyColumn: -1

    readonly property real resolvedKeyColumn: root.keyColumn >= 0 ? root.keyColumn : (PaperTheme.isBroadsheet ? 74 : -1)

    implicitWidth: 200
    implicitHeight: Math.max(keyText.implicitHeight, valueText.implicitHeight) + PaperTheme.pick(9, 6, 6)

    PaperTitle {
        id: keyText
        text: root.key
        role: "micro"
        tone: "ink3"
        caps: !PaperTheme.titleIsSmallCaps
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.resolvedKeyColumn >= 0 ? root.resolvedKeyColumn : implicitWidth
        elide: Text.ElideRight
    }

    // The dotted leader. Ledger only — it degrades to plain whitespace
    // elsewhere, which is what the other two SPECs ask for.
    Row {
        visible: PaperTheme.ornament.dottedLeaders
        anchors.left: keyText.right
        anchors.right: valueText.left
        anchors.leftMargin: PaperTheme.gap.value
        anchors.rightMargin: PaperTheme.gap.value
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Math.round(keyText.implicitHeight / 2) - 2
        clip: true
        spacing: 2
        Repeater {
            model: PaperTheme.ornament.dottedLeaders ? Math.max(0, Math.floor(parent.width / 4)) : 0
            delegate: Rectangle {
                width: 2
                height: PaperTheme.ruleWidth
                color: PaperTheme.ink4
                antialiasing: false
            }
        }
    }

    PaperText {
        id: valueText
        text: root.value
        role: "small"
        tone: root.valueTone
        mono: !root.figure
        figure: root.figure
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
    }
}
