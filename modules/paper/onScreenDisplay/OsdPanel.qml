pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import QtQuick.Layouts

/**
 * The OSD sheet itself — §4.5 of all three SPECs.
 *
 * SURFACE-LOCAL, and shared with nothing: this is a one-surface composition and
 * it lives here on purpose. It is split out of PaperOnScreenDisplay only so the
 * window plumbing and the drawing stay legible side by side.
 *
 *   hairline   — 300 × 62, 16/20 padding, 16 px row gap. A 20 px glyph, then a
 *                column (gap 10) of a 13 px label + the percent in mono 13,
 *                over the 1 px meter with its head dot. Muted drops glyph,
 *                label and value to `ink3` and empties the track.
 *   ledger     — 268 wide, 12/14 padding, 12 px gap, column gap 7. Label 12/600
 *                and the figure in mono 12 over the ruler meter. Muted drops
 *                everything to `ink4` and the ruler reads empty rather than
 *                zeroed.
 *   broadsheet — a floating sheet with corner ticks, 12/16 padding, 14 px gap.
 *                A 34 px MEDALLION (the variant's `radiusPill`) holding the
 *                glyph, then a column of the kicker plus the value in Pagella
 *                oldstyle 15, over the rule gauge. Muted turns the medallion
 *                and the gauge oxblood and sets the value as the *word* muted.
 *
 * A muted meter is driven to `value: 0` rather than coloured, exactly as
 * HANDOFF.md §PaperMeter asks — the track should read empty, not zeroed.
 */
PaperPanel {
    id: root

    /// "volume" | "brightness"
    property string indicator: "volume"
    /// 0..1
    property real value: 0
    property bool muted: false
    property string label: ""

    /// Hovering the panel dismisses the OSD at once.
    signal dismissRequested

    readonly property int padV: PaperTheme.pick(16, 12, 12)
    readonly property int padH: PaperTheme.pick(20, 14, 16)
    readonly property int gap: PaperTheme.pick(16, 12, 14)
    readonly property int medallion: 34

    /// Hairline and ledger say "muted" by receding down the ink ramp — glyph,
    /// label and figure all drop together. Broadsheet says it with oxblood, but
    /// only on the medallion and the gauge: its label stays a kicker and its
    /// value stays ink, because there the *word* carries the message.
    readonly property color mutedInk: PaperTheme.pick(PaperTheme.ink3, PaperTheme.ink4, PaperTheme.accent)
    readonly property color glyphInk: root.muted ? root.mutedInk : PaperTheme.pick(PaperTheme.ink, PaperTheme.ink, PaperTheme.ink2)
    readonly property color labelInk: PaperTheme.isBroadsheet ? PaperTheme.ink3 : (root.muted ? root.mutedInk : PaperTheme.ink)
    readonly property color valueInk: PaperTheme.isBroadsheet ? PaperTheme.ink : (root.muted ? root.mutedInk : PaperTheme.ink)

    readonly property string glyphName: {
        if (root.indicator === "brightness")
            return "sun";
        return root.muted ? "speakerOff" : "speaker";
    }

    /// Broadsheet writes the word; the others write a percentage.
    readonly property string valueText: {
        if (root.muted)
            return PaperTheme.isBroadsheet ? Translation.tr("muted") : Translation.tr("Muted");
        const pct = Math.round(Math.max(0, Math.min(1, root.value)) * 100);
        return PaperTheme.isHairline ? (pct + " %") : (pct + "%");
    }

    kind: "sheet"
    floating: true
    ticks: true

    implicitWidth: PaperTheme.size.osdWidth
    implicitHeight: Math.max(PaperTheme.size.osdHeight, osdRow.implicitHeight + 2 * root.padV)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.dismissRequested()
    }

    RowLayout {
        id: osdRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: root.padH
            rightMargin: root.padH
        }
        spacing: root.gap

        // The glyph. Broadsheet sets it in a medallion — the one place the
        // family draws a circle — the others let it sit bare on the sheet.
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: PaperTheme.isBroadsheet ? root.medallion : PaperTheme.icon.large
            implicitHeight: PaperTheme.isBroadsheet ? root.medallion : PaperTheme.icon.large

            Rectangle {
                anchors.fill: parent
                visible: PaperTheme.isBroadsheet
                radius: PaperTheme.radiusPill
                antialiasing: true
                color: root.muted ? PaperTheme.accentWash : PaperTheme.paper
                border.width: PaperTheme.ruleWidth
                border.color: root.muted ? PaperTheme.accent : PaperTheme.rule2
                Behavior on border.color {
                    ColorAnimation {
                        duration: PaperTheme.motion.fast
                        easing.type: PaperTheme.motion.type
                        easing.bezierCurve: PaperTheme.motion.bezierCurve
                    }
                }
            }

            PaperIcon {
                anchors.centerIn: parent
                name: root.glyphName
                size: PaperTheme.icon.large
                color: root.glyphInk
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: PaperTheme.pick(10, 7, 7)

            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.pick(12, 8, 8)

                PaperText {
                    Layout.fillWidth: true
                    // Broadsheet treats the subject as a kicker; ledger as a
                    // 12/600 label; hairline as plain body copy.
                    role: PaperTheme.pick("body", "small", "micro")
                    color: root.labelInk
                    font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.normal
                    elide: Text.ElideRight
                    text: root.label
                }

                PaperText {
                    role: PaperTheme.pick("body", "small", "lead")
                    color: root.valueInk
                    // Broadsheet sets its figures in Pagella oldstyle; the
                    // other two in the mono face.
                    mono: !PaperTheme.isBroadsheet
                    figure: PaperTheme.isBroadsheet
                    font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.medium : PaperTheme.font.weight.normal
                    horizontalAlignment: Text.AlignRight
                    text: root.valueText
                }
            }

            PaperMeter {
                Layout.fillWidth: true
                // A muted subject empties the track rather than zeroing a fill.
                value: root.muted ? 0 : root.value
                alert: root.muted && PaperTheme.isBroadsheet
            }
        }
    }
}
