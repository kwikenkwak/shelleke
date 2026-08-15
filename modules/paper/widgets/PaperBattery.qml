import QtQuick
import qs.modules.paper.common

/**
 * The battery glyph. Replaces `PixBatteryGlyph`.
 *
 * A drawn glyph rather than a `PaperIcon`, because the level fill has to be
 * proportional to the charge — it is the one solid ink mark in the family that
 * is allowed to exceed 6 px, since it encodes a QUANTITY and not a state.
 *
 * Per variant (all three SPECs, §3 widget catalog):
 *   hairline   — a 16 × 9 hairline body in `ink` with a 2 × 4 nub, fill inset
 *                1.5 px. Charging replaces the fill with a 10 px `bolt`.
 *                ≤ 15 % turns body, fill and (via `statusColor`) the percent
 *                `alert`.
 *   ledger     — a smaller rounded body in `ink-2` with a solid inner bar drawn
 *                to the charge. Charging swaps the bar for a bolt. Below 10 %
 *                the glyph and its percentage turn stamp red.
 *   broadsheet — a 24 × 11 body, 1 px `rule-2`, radius 2, plus a 2 × 5 cap. The
 *                fill turns `accent` below 15 % OR while charging, and the
 *                caller prints a `Chg` PaperStamp beside the percentage (this
 *                widget never draws the stamp — the chip owns that decision).
 *
 *   PaperBattery { percent: Battery.percentage * 100; charging: Battery.isCharging }
 *   PaperText { figure: true; text: "78 %"; color: batt.statusColor }
 *
 * The geometry is fixed per variant — that is what the SPECs specify — so there
 * is no `size`. Bind `statusColor` for any text that must agree with the glyph.
 */
Item {
    id: root

    /// Charge, 0..100.
    property real percent: 0
    property bool charging: false
    /// At or below this percentage the glyph reads as a failure. Hairline and
    /// broadsheet say 15 %, ledger says 10 %.
    property real criticalAt: PaperTheme.pick(15, 10, 15)

    readonly property real fraction: Math.max(0, Math.min(1, root.percent / 100))
    readonly property bool critical: root.percent <= root.criticalAt && !root.charging

    /// The colour anything printed next to the glyph should take (the percent).
    readonly property color statusColor: root.critical ? PaperTheme.alert : PaperTheme.ink

    /// The body outline / nub.
    property color bodyColor: root.critical ? PaperTheme.alert : PaperTheme.pick(PaperTheme.ink, PaperTheme.ink2, PaperTheme.rule2)
    /// The level fill (or the charging bolt).
    property color fillColor: root.critical ? PaperTheme.alert : (PaperTheme.isBroadsheet && root.charging) ? PaperTheme.accent : PaperTheme.ink

    // ---- per-variant metrics, straight out of the three SPECs --------------
    readonly property real bodyWidth: PaperTheme.pick(16, 12, 24)
    readonly property real bodyHeight: PaperTheme.pick(9, 7, 11)
    readonly property real capWidth: PaperTheme.pick(2, 1.5, 2)
    readonly property real capHeight: PaperTheme.pick(4, 3, 5)
    readonly property real capGap: PaperTheme.pick(1, 1, 1)
    readonly property real fillInset: 1.5
    readonly property real frameRadius: PaperTheme.pick(0, 1, 2)

    /// Hairline and ledger replace the level bar with a bolt while charging;
    /// broadsheet keeps the bar and recolours it.
    readonly property bool showBolt: root.charging && !PaperTheme.isBroadsheet

    implicitWidth: root.bodyWidth + root.capGap + root.capWidth
    implicitHeight: Math.max(root.bodyHeight, root.capHeight)

    Rectangle {
        id: body
        x: 0
        y: (root.height - root.bodyHeight) / 2
        width: root.bodyWidth
        height: root.bodyHeight
        color: "transparent"
        radius: root.frameRadius
        antialiasing: root.frameRadius > 0
        border.width: PaperTheme.ruleWidth
        border.color: root.bodyColor

        Behavior on border.color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }

        // The level — the one solid ink mark allowed to exceed 6 px.
        Rectangle {
            visible: !root.showBolt
            x: root.fillInset
            y: root.fillInset
            width: Math.max(0, (root.bodyWidth - 2 * root.fillInset) * root.fraction)
            height: root.bodyHeight - 2 * root.fillInset
            radius: PaperTheme.pick(0, 1, 1)
            antialiasing: radius > 0
            color: root.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: PaperTheme.motion.base
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: PaperTheme.motion.fast
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }
        }

        // Charging: the bolt takes the level's place.
        PaperIcon {
            visible: root.showBolt
            anchors.centerIn: parent
            name: "bolt"
            size: PaperTheme.pick(10, 7, 9)
            color: root.fillColor
        }
    }

    // The nub / cap.
    Rectangle {
        x: root.bodyWidth + root.capGap
        y: (root.height - root.capHeight) / 2
        width: root.capWidth
        height: root.capHeight
        radius: PaperTheme.pick(0, 0, 1)
        antialiasing: radius > 0
        color: root.bodyColor
    }
}
