import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The battery chip: the glyph plus the rounded percentage, and — in broadsheet
 * only — a `Chg` stamp while charging (hairline has no stamps and ledger says
 * the bolt inside the glyph is enough).
 *
 * Hovering opens the battery popup, clicking opens quick settings. Hidden when
 * there is no battery. Bound to `Battery`.
 *
 * The signal is `activated`, NOT `clicked`: naming a custom signal `clicked` on
 * a MouseArea subclass shadows `MouseArea.clicked(MouseEvent)` and silently
 * unwires `onClicked`.
 */
MouseArea {
    id: root
    signal activated

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    onClicked: root.activated()

    readonly property real percent: (Battery.percentage ?? 0) * 100
    readonly property bool charging: Battery.isCharging

    visible: Battery.available
    implicitWidth: root.visible ? row.implicitWidth : 0
    implicitHeight: PaperTheme.barHeight - PaperTheme.pick(8, 6, 10)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: PaperTheme.pick(8, 6, 7)

        PaperBattery {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            percent: root.percent
            charging: root.charging
        }

        PaperText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(root.percent)}${PaperTheme.isHairline ? " %" : "%"}`
            figure: true
            color: glyph.statusColor
            font.pixelSize: PaperTheme.pick(12, 12, 15)
        }

        // Broadsheet prints the charging state as a stamp beside the figure.
        PaperStamp {
            visible: PaperTheme.isBroadsheet && root.charging
            anchors.verticalCenter: parent.verticalCenter
            text: "Chg"
            icon: "bolt"
        }
    }

    BarPopup {
        hoverTarget: root
        BarBatteryPopup {}
    }
}
