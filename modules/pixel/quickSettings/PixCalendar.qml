pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Monochrome calendar / utility area. A left column of three mini-buttons
 * (Calendar / To Do / Timer) switches the right-hand area between the month
 * Calendar, a PixTodoView and a PixTimerView. The active mini-button is filled.
 * In Calendar mode: title "MMMM yyyy" with chevL/chevR month nav and a
 * Monday-first 7-column day grid; today is a filled square; out-of-month days
 * are rendered in grey2.
 */
Column {
    id: root
    spacing: 9

    // Which view the right area shows: "calendar" | "todo" | "timer".
    property string view: "calendar"

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

    // ---- Title + month nav (Calendar view only) ----
    Row {
        width: parent.width
        spacing: 10
        visible: root.view === "calendar"

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

    // ---- Title (To Do / Timer views) ----
    PixTitle {
        width: parent.width
        visible: root.view !== "calendar"
        text: root.view === "todo" ? "TO DO" : "TIMER"
        font.pixelSize: PixTheme.font.pixelSize.title
    }

    // ---- Left mini-buttons + active view ----
    Row {
        width: parent.width
        spacing: 10

        Column {
            width: 64
            spacing: 8

            Repeater {
                model: [
                    { icon: "calendar", label: "CAL", view: "calendar", tip: "Calendar" },
                    { icon: "todo", label: "TODO", view: "todo", tip: "To Do" },
                    { icon: "timer", label: "TIME", view: "timer", tip: "Timer" }
                ]
                delegate: PixButton {
                    id: miniBtn
                    required property var modelData
                    width: 64
                    implicitHeight: 54
                    filled: root.view === miniBtn.modelData.view
                    onClicked: root.view = miniBtn.modelData.view
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        PixIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: miniBtn.modelData.icon
                            size: 16
                            color: miniBtn.contentColor
                        }
                        PixText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: miniBtn.modelData.label
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                            color: miniBtn.contentColor
                        }
                    }
                    PixTooltip {
                        text: miniBtn.modelData.tip
                        anchorEdges: Edges.Left
                        anchorGravity: Edges.Left
                    }
                }
            }
        }

        // Active view: month grid / todo / timer.
        Item {
            width: parent.width - 64 - parent.spacing
            // Match the natural height of the day grid (header 22 + 6*26).
            height: 178

            // Day grid
            Grid {
                id: dayGrid
                anchors.fill: parent
                visible: root.view === "calendar"
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

            PixTodoView {
                anchors.fill: parent
                visible: root.view === "todo"
            }

            PixTimerView {
                anchors.fill: parent
                visible: root.view === "timer"
            }
        }
    }
}
