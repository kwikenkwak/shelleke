pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Monochrome Pomodoro timer backed by the TimerService singleton. Shows the big
 * remaining MM:SS, the current phase (Focus / Break / Long break) and cycle,
 * plus Start/Pause and Reset buttons. Null-safe against missing service fields.
 */
Item {
    id: root

    readonly property int secondsLeft: Math.max(0, TimerService.pomodoroSecondsLeft ?? 0)
    readonly property bool running: TimerService.pomodoroRunning ?? false
    readonly property string phase: (TimerService.pomodoroLongBreak ?? false) ? "LONG BREAK"
        : (TimerService.pomodoroBreak ?? false) ? "BREAK"
        : "FOCUS"

    function pad(n) {
        return Math.floor(n).toString().padStart(2, "0");
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 10

        // Phase + cycle.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            PixTitle {
                anchors.verticalCenter: parent.verticalCenter
                text: root.phase
                font.pixelSize: PixTheme.font.pixelSize.normal
                color: PixTheme.colors.grey
            }
            PixText {
                anchors.verticalCenter: parent.verticalCenter
                text: "#" + ((TimerService.pomodoroCycle ?? 0) + 1)
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.small
                color: PixTheme.colors.grey
            }
        }

        // Big remaining time.
        PixTitle {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.pad(root.secondsLeft / 60) + ":" + root.pad(root.secondsLeft % 60)
            font.pixelSize: PixTheme.font.pixelSize.huge * 2
        }

        // Controls.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            PixButton {
                id: startBtn
                implicitWidth: 96
                implicitHeight: 34
                filled: root.running
                onClicked: TimerService.togglePomodoro()
                PixText {
                    anchors.centerIn: parent
                    text: root.running ? "PAUSE" : "START"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small
                    color: startBtn.contentColor
                }
            }
            PixButton {
                id: resetBtn
                implicitWidth: 96
                implicitHeight: 34
                onClicked: TimerService.resetPomodoro()
                PixText {
                    anchors.centerIn: parent
                    text: "RESET"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small
                    color: resetBtn.contentColor
                }
            }
        }
    }
}
