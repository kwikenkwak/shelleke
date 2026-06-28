import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * System-monitor hover popup content: RAM / Swap / CPU / Claude columns.
 * Mirrors PixelPopups.html. Null-safe against ResourceUsage / ClaudeUsage.
 */
Row {
    id: root
    spacing: 30

    function formatKB(kb) {
        return (Number(kb) / (1024 * 1024)).toFixed(1) + " GB";
    }

    // ---- RAM ----
    Column {
        spacing: 9
        PixSysHeader { icon: "ram"; label: "RAM" }
        PixSysSwatchRow { filled: true; label: "Used:"; value: root.formatKB(ResourceUsage.memoryUsed) }
        PixSysSwatchRow { filled: false; label: "Free:"; value: root.formatKB(ResourceUsage.memoryFree) }
        PixSysIconRow { icon: "ram"; label: "Total:"; value: root.formatKB(ResourceUsage.memoryTotal) }
    }

    // ---- Swap ----
    Column {
        spacing: 9
        visible: ResourceUsage.swapTotal > 0
        PixSysHeader { icon: "swap"; label: "Swap" }
        PixSysSwatchRow { filled: true; label: "Used:"; value: root.formatKB(ResourceUsage.swapUsed) }
        PixSysSwatchRow { filled: false; label: "Free:"; value: root.formatKB(ResourceUsage.swapFree) }
        PixSysIconRow { icon: "swap"; label: "Total:"; value: root.formatKB(ResourceUsage.swapTotal) }
    }

    // ---- CPU ----
    Column {
        spacing: 9
        PixSysHeader { icon: "cpu"; label: "CPU" }
        PixSysIconRow {
            icon: "bolt"
            label: "Load:"
            value: `${Math.round((ResourceUsage.cpuUsage ?? 0) * 100)}%`
        }
    }

    // ---- Claude ----
    Column {
        spacing: 9
        visible: ClaudeUsage.available
        PixSysHeader { icon: "sparkle"; label: "Claude" }
        PixSysIconRow {
            icon: "clock"
            label: "Session:"
            value: `${Math.round(ClaudeUsage.sessionPercent)}% · ${ClaudeUsage.formatReset(ClaudeUsage.sessionResetsAt)}`
        }
        PixSysIconRow {
            icon: "calendar"
            label: "Week:"
            value: `${Math.round(ClaudeUsage.weekPercent)}% · ${ClaudeUsage.formatReset(ClaudeUsage.weekResetsAt)}`
        }
        PixSysIconRow {
            visible: ClaudeUsage.opusPercent >= 0
            icon: "sparkle"
            label: "Opus:"
            value: `${Math.round(ClaudeUsage.opusPercent)}%`
        }
    }
}
