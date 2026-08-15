import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The system-monitor hover popup: three columns — memory, processor, Claude.
 *
 *   hairline   — columns 40 px apart, each headed by a micro-caps label with a
 *                hairline running to the column edge. Memory keeps the pixel
 *                theme's filled-vs-hollow swatch, shrunk to the 6 px state dot,
 *                and closes with a meter of the used fraction.
 *   ledger     — columns divided by vertical hairlines, each headed by a line
 *                icon and a caps label over a `rule-2` hairline; values are
 *                dotted leaders, and Total is ruled off above exactly the way a
 *                column of sums is closed in a ledger.
 *   broadsheet — columns headed by glyph + kicker over a DOUBLE rule, agate
 *                rows, and the rule gauge under any value that is a proportion;
 *                then a hairline and a footnote carrying the update age and the
 *                reset times.
 *
 * Null-safe against ResourceUsage and ClaudeUsage; the Claude column only
 * exists while `ClaudeUsage.available`.
 *
 * DATA NOTE: the SPECs also sketch a process count (A, B), a load average and a
 * die temperature (C). No service in this shell exposes any of them, so the
 * processor column reports what `ResourceUsage` and `DateTime` actually have —
 * load, swap and uptime — rather than inventing numbers.
 */
Column {
    id: root

    spacing: PaperTheme.spacing.medium

    readonly property real wideColumn: PaperTheme.pick(190, 168, 128)
    readonly property real narrowColumn: PaperTheme.pick(170, 168, 128)
    readonly property real columnSpacing: PaperTheme.pick(11, 5, 5)

    function formatKB(kb: real): string {
        return (Number(kb) / (1024 * 1024)).toFixed(1) + " GB";
    }
    function pct(v: real): string {
        const n = Math.round((v ?? 0) * 100);
        return PaperTheme.isHairline ? `${n} %` : `${n}%`;
    }

    Row {
        id: columns
        spacing: PaperTheme.pick(40, 18, 26)

        // --------------------------------------------------------- memory ---
        Column {
            width: root.wideColumn
            spacing: root.columnSpacing

            BarColumnHead {
                width: parent.width
                label: PaperTheme.isHairline ? "RAM" : "Memory"
                icon: PaperTheme.isHairline ? "" : "ram"
            }
            BarValueRow {
                width: parent.width
                dot: "filled"
                label: "Used"
                value: root.formatKB(ResourceUsage.memoryUsed)
                // Ledger and broadsheet print the proportion right under Used;
                // hairline saves its single meter for the foot of the column.
                meter: PaperTheme.isHairline ? -1 : (ResourceUsage.memoryUsedPercentage ?? 0)
            }
            BarValueRow {
                width: parent.width
                dot: "hollow"
                label: "Free"
                value: root.formatKB(ResourceUsage.memoryFree)
            }
            // The sum rule: a column of figures is closed before its total.
            Item {
                visible: PaperTheme.isLedger
                width: parent.width
                implicitHeight: totalRule.thickness + PaperTheme.spacing.tiny
                PaperRule {
                    id: totalRule
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                }
            }
            BarValueRow {
                width: parent.width
                icon: "ram"
                label: "Total"
                value: root.formatKB(ResourceUsage.memoryTotal)
            }
            PaperMeter {
                visible: PaperTheme.isHairline
                width: parent.width
                value: ResourceUsage.memoryUsedPercentage ?? 0
                dense: true
            }
        }

        PaperRule {
            visible: PaperTheme.isLedger
            vertical: true
            length: columns.implicitHeight
        }

        // ------------------------------------------------------ processor ---
        Column {
            width: root.narrowColumn
            spacing: root.columnSpacing

            BarColumnHead {
                width: parent.width
                label: PaperTheme.isHairline ? "CPU" : "Processor"
                icon: PaperTheme.isHairline ? "" : "cpu"
            }
            BarValueRow {
                width: parent.width
                icon: "bolt"
                label: "Load"
                value: root.pct(ResourceUsage.cpuUsage)
                meter: ResourceUsage.cpuUsage ?? 0
            }
            BarValueRow {
                width: parent.width
                icon: "layers"
                label: "Swap"
                value: root.pct(ResourceUsage.swapUsedPercentage)
                meter: PaperTheme.isBroadsheet ? (ResourceUsage.swapUsedPercentage ?? 0) : -1
            }
            BarValueRow {
                width: parent.width
                icon: "timer"
                label: "Uptime"
                value: DateTime.uptime
            }
        }

        PaperRule {
            visible: PaperTheme.isLedger && ClaudeUsage.available
            vertical: true
            length: columns.implicitHeight
        }

        // --------------------------------------------------------- claude ---
        Column {
            visible: ClaudeUsage.available
            width: root.wideColumn
            spacing: root.columnSpacing

            BarColumnHead {
                width: parent.width
                label: "Claude"
                icon: PaperTheme.isHairline ? "" : "robot"
            }
            BarValueRow {
                width: parent.width
                icon: "clock"
                label: "Session"
                // Broadsheet draws the proportion as a gauge, so the reset time
                // moves down into the closing footnote.
                value: PaperTheme.isBroadsheet ? root.pct((ClaudeUsage.sessionPercent ?? 0) / 100) : `${root.pct((ClaudeUsage.sessionPercent ?? 0) / 100)} · ${ClaudeUsage.formatReset(ClaudeUsage.sessionResetsAt)}`
                meter: PaperTheme.isBroadsheet ? (ClaudeUsage.sessionPercent ?? 0) / 100 : -1
                alert: ClaudeUsage.warning
            }
            BarValueRow {
                width: parent.width
                icon: "calendar"
                label: "Week"
                value: PaperTheme.isBroadsheet ? root.pct((ClaudeUsage.weekPercent ?? 0) / 100) : `${root.pct((ClaudeUsage.weekPercent ?? 0) / 100)} · ${ClaudeUsage.formatReset(ClaudeUsage.weekResetsAt)}`
                meter: PaperTheme.isBroadsheet ? (ClaudeUsage.weekPercent ?? 0) / 100 : -1
            }
            BarValueRow {
                visible: (ClaudeUsage.opusPercent ?? -1) >= 0
                width: parent.width
                icon: "sparkle"
                label: "Opus"
                value: root.pct((ClaudeUsage.opusPercent ?? 0) / 100)
                meter: PaperTheme.isBroadsheet ? (ClaudeUsage.opusPercent ?? 0) / 100 : -1
            }
            BarValueRow {
                visible: !PaperTheme.isBroadsheet && ClaudeUsage.lastUpdatedAgo !== ""
                width: parent.width
                icon: "refresh"
                label: "Updated"
                // A lastError while data is still on screen means the newest
                // poll failed — the figures are stale.
                value: ClaudeUsage.lastUpdatedAgo + (ClaudeUsage.lastError !== "" ? " (stale)" : "")
                alert: ClaudeUsage.lastError !== ""
            }
        }
    }

    // ---- broadsheet's closing footnote --------------------------------------
    PaperRule {
        visible: PaperTheme.isBroadsheet && ClaudeUsage.available
        width: columns.implicitWidth
    }
    Item {
        visible: PaperTheme.isBroadsheet && ClaudeUsage.available
        width: columns.implicitWidth
        implicitHeight: Math.max(updatedFoot.implicitHeight, resetFoot.implicitHeight)
        PaperText {
            id: updatedFoot
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: ClaudeUsage.lastUpdatedAgo !== "" ? `Updated ${ClaudeUsage.lastUpdatedAgo}${ClaudeUsage.lastError !== "" ? " (stale)" : ""}` : ""
            role: "meta"
            tone: "ink4"
            footnote: true
        }
        PaperText {
            id: resetFoot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `reset ${ClaudeUsage.formatReset(ClaudeUsage.sessionResetsAt)} · week ${ClaudeUsage.formatReset(ClaudeUsage.weekResetsAt)}`
            role: "meta"
            tone: "ink4"
            footnote: true
        }
    }
}
