pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Monochrome month calendar. Title "MMMM yyyy" with chevL/chevR month nav, a
 * left column of three 60px mini-buttons (Calendar/To Do/Timer) and a
 * Monday-first 7-column day grid. Today is a filled square; out-of-month days
 * are rendered in grey2.
 */
Column {
    id: root
    spacing: 9

    // Year/month currently displayed. Initialised to the real "now".
    property int displayYear: now.getFullYear()
    property int displayMonth: now.getMonth() // 0-based

    // Re-evaluated whenever DateTime ticks so "today" stays correct.
    readonly property var now: {
        DateTime.clock.date; // dependency
        return new Date();
    }

    readonly property var weekDays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    // Build a flat list of 42 grid cells (6 weeks), Monday-first.
    readonly property var grid: {
        const cells = [];
        const first = new Date(root.displayYear, root.displayMonth, 1);
        // JS getDay(): 0=Sun..6=Sat. Convert to Monday-first offset.
        let lead = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(root.displayYear, root.displayMonth + 1, 0).getDate();
        const prevDays = new Date(root.displayYear, root.displayMonth, 0).getDate();

        for (let i = 0; i < lead; i++)
            cells.push({ day: prevDays - lead + 1 + i, inMonth: false });
        for (let d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, inMonth: true });
        let next = 1;
        while (cells.length < 42)
            cells.push({ day: next++, inMonth: false });
        return cells;
    }

    function isToday(cell) {
        return cell.inMonth
            && root.displayYear === root.now.getFullYear()
            && root.displayMonth === root.now.getMonth()
            && cell.day === root.now.getDate();
    }

    function shiftMonth(delta) {
        let m = root.displayMonth + delta;
        let y = root.displayYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        root.displayMonth = m;
        root.displayYear = y;
    }

    // ---- Title + month nav ----
    Row {
        width: parent.width
        spacing: 10

        PixIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "chevD"
            size: 14
        }
        PixTitle {
            id: monthTitle
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 14 - 30 - 30 - parent.spacing * 3
            text: Qt.formatDate(new Date(root.displayYear, root.displayMonth, 1), "MMMM yyyy")
            font.pixelSize: PixTheme.font.pixelSize.title
            elide: Text.ElideRight
        }
        PixButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 30
            implicitHeight: 28
            onClicked: root.shiftMonth(-1)
            PixIcon {
                anchors.centerIn: parent
                name: "chevL"
                size: 13
                color: parent.contentColor
            }
        }
        PixButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 30
            implicitHeight: 28
            onClicked: root.shiftMonth(1)
            PixIcon {
                anchors.centerIn: parent
                name: "chevR"
                size: 13
                color: parent.contentColor
            }
        }
    }

    // ---- Left mini-buttons + day grid ----
    Row {
        width: parent.width
        spacing: 10

        Column {
            width: 60
            spacing: 8

            Repeater {
                model: [
                    { icon: "calendar", label: "Calendar" },
                    { icon: "todo", label: "To Do" },
                    { icon: "timer", label: "Timer" }
                ]
                delegate: PixButton {
                    id: miniBtn
                    required property var modelData
                    width: 60
                    implicitHeight: 52
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        PixIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: miniBtn.modelData.icon
                            size: 16
                            color: miniBtn.contentColor
                        }
                        PixTitle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: miniBtn.modelData.label
                            font.pixelSize: PixTheme.font.pixelSize.smallest
                            letterSpacing: 0
                            color: miniBtn.contentColor
                        }
                    }
                }
            }
        }

        // Day grid
        Grid {
            id: dayGrid
            width: parent.width - 60 - parent.spacing
            columns: 7
            readonly property real cellW: width / 7

            // Weekday header
            Repeater {
                model: root.weekDays
                delegate: Item {
                    id: weekdayCell
                    required property var modelData
                    width: dayGrid.cellW
                    height: 22
                    PixText {
                        anchors.centerIn: parent
                        text: weekdayCell.modelData
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.smaller
                    }
                }
            }

            // Days
            Repeater {
                model: root.grid
                delegate: Item {
                    id: dayCell
                    required property var modelData
                    width: dayGrid.cellW
                    height: 26

                    readonly property bool today: root.isToday(modelData)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 22
                        radius: 0
                        antialiasing: false
                        visible: dayCell.today
                        color: PixTheme.colors.fg
                    }
                    PixText {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        font.bold: dayCell.today
                        font.pixelSize: PixTheme.font.pixelSize.small
                        color: dayCell.today ? PixTheme.colors.bg
                            : dayCell.modelData.inMonth ? PixTheme.colors.fg
                            : PixTheme.colors.grey2
                    }
                }
            }
        }
    }
}
