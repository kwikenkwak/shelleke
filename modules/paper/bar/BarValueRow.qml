import QtQuick
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * One reported line inside a bar popup: a label on the left, a figure on the
 * right, and optionally a meter under it.
 *
 * The three SPECs each want a different idiom for the same line, so this picks:
 *   hairline   — a 14 px glyph (or the 6 px used/free state dot, inherited from
 *                the pixel theme's filled-vs-hollow swatch) + the label in
 *                `small`/`ink-2` + the value in mono 12 `ink`.
 *   ledger     — a `PaperKV`: caps key ··· dotted leader ··· mono value. No
 *                glyph — ledger popups carry no icons in their rows.
 *   broadsheet — agate label (or a kicker, with `kicker: true`) + the value in
 *                Pagella oldstyle 13.
 *
 *   BarValueRow { width: 190; icon: "timer"; label: "Time to empty"; value: "4 h 12 m" }
 *   BarValueRow { width: 190; dot: "filled"; label: "Used"; value: "18.4 GB"; meter: 0.58 }
 *
 * Give it an explicit `width`.
 */
Item {
    id: root

    property string icon: ""
    /// "" | "filled" | "hollow" — the 6 px state dot, hairline only.
    property string dot: ""
    property string label: ""
    property string value: ""
    /// Broadsheet only: set the label as a kicker rather than agate.
    property bool kicker: false
    /// 0..1 to print a meter under the row; < 0 for none.
    property real meter: -1
    property bool alert: false

    readonly property bool leading: PaperTheme.isHairline && (root.icon !== "" || root.dot !== "")
    readonly property real leadWidth: PaperTheme.icon.row
    readonly property real gap: PaperTheme.pick(11, 8, 8)

    implicitWidth: 190
    implicitHeight: line.implicitHeight + (root.meter >= 0 ? meterItem.implicitHeight + PaperTheme.spacing.tiny : 0)

    Item {
        id: line
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: PaperTheme.isLedger ? kv.implicitHeight : Math.max(valueText.implicitHeight, root.leading ? root.leadWidth : 0)

        // ---- ledger: the dotted leader ------------------------------------
        PaperKV {
            id: kv
            visible: PaperTheme.isLedger
            anchors.left: parent.left
            anchors.right: parent.right
            key: root.label
            value: root.value
            valueTone: root.alert ? "alert" : "ink"
        }

        // ---- hairline / broadsheet: label left, figure right ---------------
        PaperIcon {
            id: glyph
            visible: root.leading && root.icon !== "" && root.dot === ""
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: PaperTheme.icon.row
            color: root.alert ? PaperTheme.alert : PaperTheme.ink3
        }

        // The pixel theme's 9 × 9 filled/hollow swatch, shrunk to the 6 px dot.
        Rectangle {
            id: stateDot
            visible: root.leading && root.dot !== ""
            width: PaperTheme.size.dot
            height: PaperTheme.size.dot
            radius: width / 2
            antialiasing: true
            x: (root.leadWidth - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.dot === "filled" ? PaperTheme.ink : "transparent"
            border.width: root.dot === "filled" ? 0 : PaperTheme.ruleWidth
            border.color: PaperTheme.ink
        }

        PaperText {
            id: labelText
            visible: !PaperTheme.isLedger
            anchors.left: parent.left
            anchors.leftMargin: root.leading ? root.leadWidth + root.gap : 0
            anchors.right: valueText.left
            anchors.rightMargin: root.gap
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            role: (PaperTheme.isBroadsheet && root.kicker) ? "micro" : (PaperTheme.isBroadsheet ? "meta" : "small")
            tone: (PaperTheme.isBroadsheet && root.kicker) ? "ink3" : "ink2"
            elide: Text.ElideRight
        }

        PaperText {
            id: valueText
            visible: !PaperTheme.isLedger
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            mono: !PaperTheme.isBroadsheet
            figure: PaperTheme.isBroadsheet
            tone: root.alert ? "alert" : "ink"
            font.pixelSize: PaperTheme.pick(12, 12, 13)
        }
    }

    PaperMeter {
        id: meterItem
        visible: root.meter >= 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: line.bottom
        anchors.topMargin: PaperTheme.spacing.tiny
        value: Math.max(0, root.meter)
        dense: true
        alert: root.alert
    }
}
