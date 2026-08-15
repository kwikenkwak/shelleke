import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The pomodoro pane of the calendar area, backed by `TimerService`.
 *
 * The phase as a micro-caps kicker beside the cycle, the remaining MM:SS at the
 * `folio` size — the largest and lightest type anywhere in the shell — a meter
 * of the elapsed fraction of the phase, and Start/Pause + Reset.
 *
 * The meter is new relative to the pixel build, and free: the family already
 * owns one meter and this is exactly the quantity it was built to show.
 *
 * Hairline and ledger centre the phase over the digits; broadsheet spreads the
 * kicker and the footnote across the pane, which is what its SPEC draws.
 */
Item {
    id: root

    readonly property int secondsLeft: Math.max(0, TimerService.pomodoroSecondsLeft ?? 0)
    readonly property int lapDuration: Math.max(1, TimerService.pomodoroLapDuration ?? 1)
    readonly property bool running: TimerService.pomodoroRunning ?? false
    readonly property int cycle: (TimerService.pomodoroCycle ?? 0) + 1
    readonly property int cycleCount: Math.max(1, TimerService.cyclesBeforeLongBreak ?? 4)
    readonly property string phase: (TimerService.pomodoroLongBreak ?? false) ? "Long break" : (TimerService.pomodoroBreak ?? false) ? "Break" : "Focus"
    /// Fraction of the phase already spent.
    readonly property real elapsed: Math.max(0, Math.min(1, 1 - root.secondsLeft / root.lapDuration))
    readonly property real phaseGap: PaperTheme.pick(14, 8, 9)

    function pad(n: real): string {
        return Math.floor(n).toString().padStart(2, "0");
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: PaperTheme.pick(4, 6, 4)

        // ---- phase + cycle -------------------------------------------------
        Item {
            width: parent.width
            height: Math.max(phaseText.implicitHeight, cycleText.implicitHeight)

            PaperText {
                id: phaseText
                y: (parent.height - implicitHeight) / 2
                x: PaperTheme.isBroadsheet ? 0 : Math.round(Math.max(0, (parent.width - (phaseText.implicitWidth + root.phaseGap + cycleText.implicitWidth)) / 2))
                role: "micro"
                // Hairline has no accent for "on": the phase is plain ink.
                tone: PaperTheme.isHairline ? "ink" : "accent"
                text: root.phase
            }
            PaperText {
                id: cycleText
                y: (parent.height - implicitHeight) / 2
                x: PaperTheme.isBroadsheet ? Math.max(0, parent.width - implicitWidth) : phaseText.x + phaseText.implicitWidth + root.phaseGap
                role: "meta"
                tone: "ink3"
                mono: !PaperTheme.isBroadsheet
                footnote: PaperTheme.isBroadsheet
                text: PaperTheme.isHairline ? "#" + root.cycle : "cycle " + root.cycle + " of " + root.cycleCount
            }
        }

        // ---- the digits ------------------------------------------------------
        PaperText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "folio"
            tone: "ink"
            figure: true
            text: root.pad(root.secondsLeft / 60) + ":" + root.pad(root.secondsLeft % 60)
        }

        // ---- the phase meter -------------------------------------------------
        Item {
            width: parent.width
            height: meter.implicitHeight + PaperTheme.pick(20, 12, 12)

            PaperMeter {
                id: meter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: PaperTheme.isHairline ? Math.min(150, parent.width) : parent.width
                value: root.elapsed
            }
        }

        // ---- controls ---------------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: PaperTheme.pick(34, 8, 8)

            PaperButton {
                width: PaperTheme.isHairline ? implicitWidth : PaperTheme.pick(88, 88, 96)
                label: root.running ? "Pause" : "Start"
                checked: root.running
                onClicked: TimerService.togglePomodoro()
            }
            PaperButton {
                width: PaperTheme.isHairline ? implicitWidth : PaperTheme.pick(72, 72, 80)
                label: "Reset"
                onClicked: TimerService.resetPomodoro()
            }
        }
    }
}
