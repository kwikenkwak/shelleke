import QtQuick
import qs.modules.paper.common

/**
 * A labelled figure — a glyph, a kicker and a number, read as one unit.
 *
 * This is the bar's stat cluster (`RAM 38 %`), and the "label + value" line in
 * any popup that is reporting a measurement rather than a key/value pair (use
 * `PaperKV` when the two really are a key and its value and the variant wants
 * a dotted leader).
 *
 * The three variants disagree about which of the three parts survives, and
 * that disagreement is the whole point of the widget:
 *   hairline   — GLYPH + figure. No label; the picture is the label.
 *   ledger     — LABEL + figure, **no glyph at all**: "the label is the icon",
 *                which is what makes the bar strip read as a column of accounts.
 *   broadsheet — GLYPH + kicker + figure, the value in Pagella oldstyle.
 *
 * So write all three parts and let the widget drop what its variant does not
 * use; override `showIcon` / `showLabel` only when a surface genuinely needs
 * something else.
 *
 *   PaperStat { icon: "ram"; label: "Ram"; value: "38 %" }
 *   PaperStat { icon: "cpu"; label: "Load"; value: "17 %"; spread: true; width: 180 }
 *   PaperStat { icon: "robot"; label: "Claude"; value: "61 %"; alert: true }
 *
 * `spread: true` turns the triple into a row that fills its given width, with
 * the label taking the slack and the figure right-aligned — the popup form.
 * The inline form (`spread: false`, the default) is content-sized.
 */
Item {
    id: root

    /// Glyph name (PaperIcon). Ignored in ledger.
    property string icon: ""
    /// Short label. Uppercased and tracked by the variant's kicker treatment.
    property string label: ""
    /// The figure itself. Already formatted — this widget does not round.
    property string value: ""

    /// A warning / failure reading: glyph and figure both take `alert`.
    property bool alert: false
    /// Fill `width`, label grows, figure right-aligned.
    property bool spread: false

    property bool showIcon: !PaperTheme.isLedger
    property bool showLabel: !PaperTheme.isHairline

    /// Both SPECs that print a bar kicker specify 9 px rather than the 10 px
    /// micro size, because it sits beside a figure and must not out-shout it.
    property real labelSize: 9
    /// Figure size. hairline/ledger set numerals in the mono face at 12 px;
    /// broadsheet in Pagella oldstyle at 15 px.
    property real valueSize: PaperTheme.pick(12, 12, 15)
    property string valueTone: "ink"

    readonly property bool drawsIcon: root.showIcon && root.icon !== ""
    readonly property bool drawsLabel: root.showLabel && root.label !== ""

    readonly property real gap: PaperTheme.pick(7, 5, 6)

    implicitWidth: (root.drawsIcon ? glyph.implicitWidth + root.gap : 0) + (root.drawsLabel ? labelText.implicitWidth + root.gap : 0) + valueText.implicitWidth
    implicitHeight: Math.max(root.drawsIcon ? glyph.implicitHeight : 0, valueText.implicitHeight)

    PaperIcon {
        id: glyph
        visible: root.drawsIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: PaperTheme.icon.row
        color: root.alert ? PaperTheme.alert : PaperTheme.ink2
    }

    PaperText {
        id: labelText
        visible: root.drawsLabel
        anchors.left: root.drawsIcon ? glyph.right : parent.left
        anchors.leftMargin: root.drawsIcon ? root.gap : 0
        anchors.right: root.spread ? valueText.left : undefined
        anchors.rightMargin: root.spread ? root.gap : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        role: "micro"
        tone: PaperTheme.pick("ink3", "ink3", "ink4")
        font.pixelSize: root.labelSize
        elide: Text.ElideRight
    }

    PaperText {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.value
        figure: true
        tone: root.alert ? "alert" : root.valueTone
        font.pixelSize: root.valueSize
    }
}
