import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The clock: the time in the variant's figure face, then the short date.
 *
 *   hairline   — mono 15 px `ink` (the largest type on the bar) + `ddd dd MMM`
 *                at 11 px `ink-3`, 10 px apart.
 *   ledger     — mono 13 px tabular + `Tue 12 Aug` at 11 px, 7 px apart.
 *   broadsheet — Pagella `onum tnum` 17 px, a 1 × 14 hairline, then the date in
 *                agate 11 px, 9 px apart.
 *
 * `figure: true` is what keeps the strip from reflowing every minute — without
 * tabular figures the whole right cluster jitters. Hovering opens the clock
 * popup. Bound to `DateTime`.
 */
MouseArea {
    id: root
    hoverEnabled: true
    implicitWidth: row.implicitWidth
    implicitHeight: PaperTheme.barHeight - PaperTheme.pick(8, 6, 10)

    readonly property var now: DateTime.clock?.date ?? new Date()
    readonly property string timeText: Qt.locale().toString(root.now, "HH:mm")
    readonly property string dateText: Qt.locale().toString(root.now, PaperTheme.pick("ddd dd MMM", "ddd d MMM", "ddd, d MMM"))

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: PaperTheme.pick(10, 7, 9)

        PaperText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            figure: true
            tone: "ink"
            font.pixelSize: PaperTheme.pick(15, 13, 17)
        }

        // Broadsheet sets the time off from the date with a hairline.
        BarDivider {
            visible: PaperTheme.isBroadsheet
            anchors.verticalCenter: parent.verticalCenter
            length: 14
        }

        PaperText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateText
            role: "meta"
            tone: "ink3"
        }
    }

    BarPopup {
        hoverTarget: root
        BarClockPopup {}
    }
}
