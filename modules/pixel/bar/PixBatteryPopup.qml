import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Battery hover popup content: glyph + status + time + health.
 * Mirrors PixelPopups.html. Null-safe against the Battery service.
 */
Column {
    id: root
    spacing: 10

    readonly property bool charging: Battery.isCharging
    readonly property real percent: (Battery.percentage ?? 0) * 100

    function formatTime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    // Header: glyph + "Battery"
    Row {
        spacing: 8
        PixBatteryGlyph {
            anchors.verticalCenter: parent.verticalCenter
            percent: root.percent
            charging: root.charging
            u: 1
        }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.available ? `Battery · ${Math.round(root.percent)}%` : "No battery"
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }

    // Time to full / empty (hidden when not meaningful)
    Row {
        spacing: 8
        visible: {
            if (!Battery.available) return false;
            const t = root.charging ? Battery.timeToFull : Battery.timeToEmpty;
            return !(Battery.chargeState === 4 || t <= 0 || (Battery.energyRate ?? 0) <= 0.01);
        }
        PixIcon { anchors.verticalCenter: parent.verticalCenter; name: "timer"; size: 15 }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.charging ? "Time to full: " : "Time to empty: "
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.charging ? Battery.timeToFull : Battery.timeToEmpty)
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }

    // Charge state
    Row {
        spacing: 8
        visible: Battery.available
        PixIcon { anchors.verticalCenter: parent.verticalCenter; name: "bolt"; size: 15 }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.chargeState === 4 ? "Fully charged"
                : root.charging ? `Charging · ${(Battery.energyRate ?? 0).toFixed(1)}W`
                : `Discharging · ${(Battery.energyRate ?? 0).toFixed(1)}W`
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }

    // Health
    Row {
        spacing: 8
        visible: Battery.available && (Battery.health ?? 0) > 0
        PixIcon { anchors.verticalCenter: parent.verticalCenter; name: "heart"; size: 15 }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Health: "
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
        PixText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${(Battery.health ?? 0).toFixed(1)}%`
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.larger
        }
    }
}
