import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The headphone chip: the glyph of whatever audio peripheral is connected plus
 * its rounded percentage — the phone convention, sat next to the laptop's own
 * battery chip.
 *
 * Hidden whenever nothing audio reports a battery, which is most of the time;
 * it appears the moment a headset connects. Bound to `PeripheralBattery`.
 *
 * Thresholds and colouring deliberately mirror `BarBatteryChip` /
 * `PaperBattery` — 15 % (10 % in ledger) turns the glyph and the figure
 * `alert` — so the two chips never disagree about what "low" looks like.
 *
 * The signal is `activated`, NOT `clicked`: see the note in BarBatteryChip.
 */
MouseArea {
    id: root
    signal activated

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    onClicked: root.activated()

    readonly property real percent: PeripheralBattery.percentage * 100
    readonly property real criticalAt: PaperTheme.pick(15, 10, 15)
    readonly property bool critical: root.percent <= root.criticalAt && !PeripheralBattery.charging
    readonly property color statusColor: root.critical ? PaperTheme.alert : PaperTheme.ink

    /// The paper glyph for the connected peripheral's kind.
    readonly property string glyph: PeripheralBattery.kind === "earbuds" ? "earbuds" : PeripheralBattery.kind === "speaker" ? "speaker" : "headphones"

    visible: PeripheralBattery.available
    implicitWidth: root.visible ? row.implicitWidth : 0
    implicitHeight: PaperTheme.barHeight - PaperTheme.pick(8, 6, 10)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: PaperTheme.pick(8, 6, 7)

        PaperIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: PaperTheme.pick(16, 15, 17)
            color: root.statusColor
        }

        PaperText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(root.percent)}${PaperTheme.isHairline ? " %" : "%"}`
            figure: true
            color: root.statusColor
            font.pixelSize: PaperTheme.pick(12, 12, 15)
        }

        // Broadsheet prints the charging case as a stamp, as it does for the
        // laptop battery.
        PaperStamp {
            visible: PaperTheme.isBroadsheet && PeripheralBattery.charging
            anchors.verticalCenter: parent.verticalCenter
            text: "Chg"
            icon: "bolt"
        }
    }

    BarPopup {
        hoverTarget: root
        BarPeripheralPopup {}
    }
}
