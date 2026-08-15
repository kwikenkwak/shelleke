import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The battery hover popup. Same four facts as `PixBatteryPopup` — charge,
 * time to full/empty, charge state + draw, health — in each variant's idiom.
 *
 *   hairline   — the percent in `title` beside a `Battery` micro-cap and the
 *                glyph, a hairline, then glyph + label + mono value rows.
 *   ledger     — the glyph, `Battery` in Charter 15, the percent in mono 14 on
 *                the right, a ruler meter, a hairline, then STATE / DRAW /
 *                TO EMPTY / HEALTH as dotted leaders.
 *   broadsheet — a 38 px seal holding the `bolt` glyph, the `Battery` kicker
 *                over the percentage in Pagella 21, the charging stamp tilted at
 *                the right; an Oxford rule; then kicker/value rows, a hairline
 *                and a footnote carrying the charge state.
 *
 * The header genuinely differs in structure between the three, so it is a
 * `Loader` with a per-variant component rather than a forest of `visible:`
 * bindings. Null-safe against the Battery service.
 */
Column {
    id: root

    readonly property int sheetWidth: PaperTheme.pick(300, 252, 268)
    readonly property bool charging: Battery.isCharging
    readonly property real percent: (Battery.percentage ?? 0) * 100
    readonly property string percentText: `${Math.round(root.percent)}${PaperTheme.isHairline ? " %" : "%"}`

    readonly property bool timeMeaningful: {
        if (!Battery.available)
            return false;
        const t = root.charging ? Battery.timeToFull : Battery.timeToEmpty;
        return !(Battery.chargeState === 4 || t <= 0 || (Battery.energyRate ?? 0) <= 0.01);
    }
    readonly property string timeLabel: root.charging ? (PaperTheme.isLedger ? "To full" : "Time to full") : (PaperTheme.isLedger ? "To empty" : "Time to empty")
    readonly property string stateText: Battery.chargeState === 4 ? "Fully charged" : root.charging ? "Charging" : "Discharging"
    readonly property string wattsText: `${(Battery.energyRate ?? 0).toFixed(1)} W`
    readonly property bool healthKnown: Battery.available && (Battery.health ?? 0) > 0

    function formatTime(seconds: real): string {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} m` : `${m} m`;
    }

    width: root.sheetWidth
    spacing: PaperTheme.pick(11, 5, 6)

    // ---- header ------------------------------------------------------------
    Loader {
        width: parent.width
        sourceComponent: PaperTheme.isBroadsheet ? broadsheetHead : PaperTheme.isLedger ? ledgerHead : hairlineHead
    }

    Component {
        id: hairlineHead
        Item {
            implicitHeight: Math.max(pct.implicitHeight, 18)
            PaperText {
                id: pct
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.available ? root.percentText : "—"
                role: "title"
                figure: true
                color: batteryGlyphTone.statusColor
            }
            PaperText {
                anchors.left: pct.right
                anchors.leftMargin: PaperTheme.spacing.medium
                anchors.baseline: pct.baseline
                text: "Battery"
                role: "micro"
            }
            PaperIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "battery"
                size: PaperTheme.icon.control
                color: PaperTheme.ink2
            }
        }
    }

    Component {
        id: ledgerHead
        Column {
            spacing: PaperTheme.spacing.sm
            Item {
                width: parent.width
                implicitHeight: 20
                PaperBattery {
                    id: ledgerGlyph
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    percent: root.percent
                    charging: root.charging
                }
                PaperTitle {
                    anchors.left: ledgerGlyph.right
                    anchors.leftMargin: PaperTheme.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Battery"
                }
                PaperText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.percentText
                    figure: true
                    color: ledgerGlyph.statusColor
                    font.pixelSize: 14
                }
            }
            PaperMeter {
                width: parent.width
                value: root.percent / 100
                alert: ledgerGlyph.critical
            }
        }
    }

    Component {
        id: broadsheetHead
        Item {
            implicitHeight: 40
            // The seal: a 38 px medallion, sepia on its wash, holding the bolt.
            Rectangle {
                id: seal
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: PaperTheme.radiusPill
                antialiasing: true
                color: PaperTheme.sealWash
                border.width: PaperTheme.ruleWidth
                border.color: PaperTheme.seal
                PaperIcon {
                    anchors.centerIn: parent
                    name: "bolt"
                    size: 18
                    color: PaperTheme.seal
                }
            }
            Column {
                anchors.left: seal.right
                anchors.leftMargin: PaperTheme.spacing.medium
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                PaperText {
                    text: "Battery"
                    role: "micro"
                }
                PaperText {
                    text: root.percentText
                    figure: true
                    color: batteryGlyphTone.statusColor
                    font.pixelSize: PaperTheme.font.size.headline
                }
            }
            PaperStamp {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.stateText
                icon: root.charging ? "bolt" : ""
            }
        }
    }

    /// Off-screen instance used only for its `statusColor` / `critical` logic,
    /// so the popup's figures agree with the bar chip without duplicating the
    /// thresholds. (PaperBattery is cheap; this draws nothing.)
    PaperBattery {
        id: batteryGlyphTone
        visible: false
        percent: root.percent
        charging: root.charging
    }

    // ---- rule under the header ---------------------------------------------
    Item {
        width: parent.width
        implicitHeight: headRule.thickness + PaperTheme.pick(16, 11, 12)
        PaperRule {
            id: headRule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            weight: "oxford"
        }
    }

    // ---- the rows -----------------------------------------------------------
    // Only one variant's set is visible at a time, and a Column skips invisible
    // children, so the two orderings coexist: hairline/broadsheet get
    // time → rate → health, ledger gets state → draw → time → health.
    BarValueRow {
        visible: !PaperTheme.isLedger && root.timeMeaningful
        width: parent.width
        icon: "timer"
        label: root.timeLabel
        value: root.formatTime(root.charging ? Battery.timeToFull : Battery.timeToEmpty)
        kicker: true
    }
    BarValueRow {
        visible: PaperTheme.isLedger && Battery.available
        width: parent.width
        label: "State"
        value: root.stateText
    }
    BarValueRow {
        visible: PaperTheme.isLedger && Battery.available
        width: parent.width
        label: "Draw"
        value: root.wattsText
    }
    BarValueRow {
        visible: PaperTheme.isLedger && root.timeMeaningful
        width: parent.width
        label: root.timeLabel
        value: root.formatTime(root.charging ? Battery.timeToFull : Battery.timeToEmpty)
    }
    BarValueRow {
        visible: !PaperTheme.isLedger && Battery.available
        width: parent.width
        icon: "bolt"
        // Hairline names the state and puts the watts in the value column;
        // broadsheet keeps the state in the stamp and labels the row "Rate".
        label: PaperTheme.isBroadsheet ? "Rate" : root.stateText
        value: root.wattsText
        kicker: true
    }
    BarValueRow {
        visible: root.healthKnown
        width: parent.width
        icon: "heart"
        label: "Health"
        value: `${(Battery.health ?? 0).toFixed(1)}%`
        kicker: true
    }

    // ---- broadsheet's closing footnote --------------------------------------
    Item {
        visible: PaperTheme.isBroadsheet
        width: parent.width
        implicitHeight: footRule.thickness + PaperTheme.spacing.medium
        PaperRule {
            id: footRule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    PaperText {
        visible: PaperTheme.isBroadsheet
        width: parent.width
        text: Battery.available ? root.stateText : "No battery"
        role: "meta"
        tone: "ink4"
        footnote: true
    }

    PaperText {
        visible: !Battery.available && !PaperTheme.isBroadsheet
        text: "No battery"
        role: "small"
        tone: "ink4"
        footnote: true
    }
}
