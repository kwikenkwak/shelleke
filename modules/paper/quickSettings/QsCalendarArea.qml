pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The bottom block of quick settings: a Calendar / To do / Timer switcher and
 * the pane it drives.
 *
 * The switcher is the one place the three variants disagree structurally, so it
 * is the one place this file branches:
 *   hairline   — three micro-cap TABS sitting on the hairline that already
 *                separated the section; the active tab owns the 1 px above it.
 *   ledger     — a left stack of three 58 × 46 mode buttons.
 *   broadsheet — the same stack at 58 × 50, the active one oxblood.
 * Both shapes are PaperTabs; only `orientation` differs, so a live variant
 * switch re-lays the block out without reloading anything.
 *
 * Calendar: a Monday-first 7-column grid. Today is NEVER a filled block — it is
 * the family's ordinary selection mark: an 18 px underline in hairline, a blue
 * wash with a 2 px blue underline in ledger, and a 1 px oxblood frame over
 * `accentWash` in broadsheet (a circled date in a diary). Out-of-month days sit
 * at `ink-4`; ledger additionally tints the weekend columns `paperSunk`.
 */
Item {
    id: root

    /// calendar | todo | timer
    property string view: "calendar"

    // Re-evaluated whenever DateTime ticks, so "today" stays correct across
    // midnight without a timer of our own.
    readonly property var now: {
        DateTime.clock.date; // dependency
        return new Date();
    }

    property int displayYear: root.now.getFullYear()
    property int displayMonth: root.now.getMonth() // 0-based

    readonly property var weekDays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    readonly property real cellHeight: PaperTheme.pick(28, 23, 23)
    readonly property real weekdayHeight: PaperTheme.pick(22, 18, 18)
    readonly property real titleRowHeight: PaperTheme.pick(26, 22, 24)
    /// One height for all three panes so switching mode never moves the panel.
    readonly property real paneHeight: root.titleRowHeight + PaperTheme.pick(16, 8, 8) + root.weekdayHeight + PaperTheme.ruleWidth + 6 * root.cellHeight

    /// 42 Monday-first grid cells (6 weeks), so the pane never changes height.
    readonly property var grid: {
        const cells = [];
        const first = new Date(root.displayYear, root.displayMonth, 1);
        // JS getDay(): 0 = Sun … 6 = Sat. Convert to a Monday-first offset.
        const lead = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(root.displayYear, root.displayMonth + 1, 0).getDate();
        const prevDays = new Date(root.displayYear, root.displayMonth, 0).getDate();

        for (let i = 0; i < lead; i++)
            cells.push({
                day: prevDays - lead + 1 + i,
                inMonth: false,
                weekday: i
            });
        for (let d = 1; d <= daysInMonth; d++)
            cells.push({
                day: d,
                inMonth: true,
                weekday: (lead + d - 1) % 7
            });
        let next = 1;
        while (cells.length < 42)
            cells.push({
                day: next++,
                inMonth: false,
                weekday: cells.length % 7
            });
        return cells;
    }

    function isToday(cell): bool {
        return cell.inMonth && root.displayYear === root.now.getFullYear() && root.displayMonth === root.now.getMonth() && cell.day === root.now.getDate();
    }

    function shiftMonth(delta: int): void {
        let m = root.displayMonth + delta;
        let y = root.displayYear;
        while (m < 0) {
            m += 12;
            y -= 1;
        }
        while (m > 11) {
            m -= 12;
            y += 1;
        }
        root.displayMonth = m;
        root.displayYear = y;
    }

    readonly property var tabModel: [
        {
            key: "calendar",
            label: PaperTheme.isHairline ? "Calendar" : "Cal",
            icon: "calendar",
            tip: "Calendar"
        },
        {
            key: "todo",
            label: PaperTheme.isHairline ? "To do" : "Todo",
            icon: "todo",
            tip: "To do"
        },
        {
            key: "timer",
            label: PaperTheme.isHairline ? "Timer" : "Time",
            icon: "timer",
            tip: "Timer"
        }
    ]

    implicitHeight: (horizontalTabs.visible ? horizontalTabs.height + PaperTheme.pick(16, 10, 10) : 0) + Math.max(root.paneHeight, verticalTabs.visible ? verticalTabs.implicitHeight : 0)

    // ---- the switcher, horizontal shape (hairline) --------------------------
    PaperTabs {
        id: horizontalTabs
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: PaperTheme.isHairline
        orientation: "horizontal"
        model: root.tabModel
        current: root.view
        onSelected: key => root.view = key
    }

    // ---- the switcher, vertical shape (ledger / broadsheet) -----------------
    PaperTabs {
        id: verticalTabs
        anchors.left: parent.left
        anchors.top: horizontalTabs.visible ? horizontalTabs.bottom : parent.top
        anchors.topMargin: horizontalTabs.visible ? PaperTheme.pick(16, 10, 10) : 0
        visible: !PaperTheme.isHairline
        orientation: "vertical"
        model: root.tabModel
        current: root.view
        onSelected: key => root.view = key
    }

    // ---- the pane ------------------------------------------------------------
    Item {
        id: pane
        anchors.left: verticalTabs.visible ? verticalTabs.right : parent.left
        anchors.leftMargin: verticalTabs.visible ? PaperTheme.pick(10, 10, 10) : 0
        anchors.right: parent.right
        anchors.top: horizontalTabs.visible ? horizontalTabs.bottom : parent.top
        anchors.topMargin: horizontalTabs.visible ? PaperTheme.pick(16, 10, 10) : 0
        height: root.paneHeight

        // ======================= CALENDAR =================================
        Item {
            anchors.fill: parent
            visible: root.view === "calendar"

            Item {
                id: titleRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.titleRowHeight

                // "August 2026" — hairline sets the year back in ink-3; the
                // other two set the whole thing in the title face with the
                // variant's figure treatment.
                Row {
                    visible: PaperTheme.isHairline
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: PaperTheme.gap.value

                    PaperText {
                        role: "lead"
                        text: Qt.formatDate(new Date(root.displayYear, root.displayMonth, 1), "MMMM")
                    }
                    PaperText {
                        role: "lead"
                        tone: "ink3"
                        figure: true
                        text: root.displayYear
                    }
                }
                PaperTitle {
                    visible: !PaperTheme.isHairline
                    anchors.left: parent.left
                    anchors.right: prevButton.left
                    anchors.rightMargin: PaperTheme.gap.icon
                    anchors.verticalCenter: parent.verticalCenter
                    caps: false
                    text: Qt.formatDate(new Date(root.displayYear, root.displayMonth, 1), "MMMM yyyy")
                    elide: Text.ElideRight
                }

                PaperButton {
                    id: prevButton
                    anchors.right: nextButton.left
                    anchors.rightMargin: PaperTheme.gap.icon
                    anchors.verticalCenter: parent.verticalCenter
                    shape: "icon"
                    icon: "chevL"
                    implicitWidth: PaperTheme.pick(24, 22, 26)
                    implicitHeight: PaperTheme.pick(24, 22, 24)
                    onClicked: root.shiftMonth(-1)
                }
                PaperButton {
                    id: nextButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    shape: "icon"
                    icon: "chevR"
                    implicitWidth: PaperTheme.pick(24, 22, 26)
                    implicitHeight: PaperTheme.pick(24, 22, 24)
                    onClicked: root.shiftMonth(1)
                }
            }

            // Weekday header.
            Grid {
                id: weekdayRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: titleRow.bottom
                anchors.topMargin: PaperTheme.pick(16, 8, 8)
                columns: 7
                readonly property real cellWidth: width / 7

                Repeater {
                    model: root.weekDays

                    delegate: Item {
                        id: weekdayCell
                        required property var modelData
                        width: weekdayRow.cellWidth
                        height: root.weekdayHeight

                        PaperText {
                            anchors.centerIn: parent
                            role: "micro"
                            font.pixelSize: 9
                            tone: "ink3"
                            text: weekdayCell.modelData
                        }
                    }
                }
            }

            PaperRule {
                id: gridRule
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: weekdayRow.bottom
                weight: "fine"
            }

            // The days.
            Grid {
                id: dayGrid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: gridRule.bottom
                columns: 7
                readonly property real cellWidth: width / 7

                Repeater {
                    model: root.grid

                    delegate: Item {
                        id: dayCell
                        required property var modelData

                        readonly property bool today: root.isToday(dayCell.modelData)
                        readonly property bool weekend: dayCell.modelData.weekday >= 5

                        width: dayGrid.cellWidth
                        height: root.cellHeight

                        // Ledger tints the weekend columns.
                        Rectangle {
                            anchors.fill: parent
                            visible: PaperTheme.isLedger && dayCell.weekend && !dayCell.today
                            color: PaperTheme.paperSunk
                            antialiasing: false
                        }

                        // Today. Never a filled block: a wash plus the family's
                        // ordinary selection mark, or a circled date in
                        // broadsheet.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: PaperTheme.isBroadsheet ? 1 : 0
                            visible: dayCell.today && !PaperTheme.isHairline
                            color: PaperTheme.accentWash
                            radius: PaperTheme.radiusControl
                            antialiasing: radius > 0
                            border.width: PaperTheme.isBroadsheet ? PaperTheme.ruleWidth : 0
                            border.color: PaperTheme.accent
                        }
                        Rectangle {
                            visible: dayCell.today && !PaperTheme.isBroadsheet
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: PaperTheme.pick(2, 0, 0)
                            width: PaperTheme.isHairline ? 18 : parent.width
                            height: PaperTheme.markWidth
                            color: PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent
                            antialiasing: false
                        }

                        PaperText {
                            anchors.centerIn: parent
                            role: "small"
                            figure: true
                            text: dayCell.modelData.day
                            color: dayCell.today ? PaperTheme.accent : dayCell.modelData.inMonth ? (PaperTheme.isHairline ? PaperTheme.ink2 : PaperTheme.ink) : PaperTheme.ink4
                            font.weight: dayCell.today ? PaperTheme.font.weight.medium : PaperTheme.font.weight.normal
                        }
                    }
                }
            }
        }

        // ======================= TO DO ====================================
        QsTodoView {
            anchors.fill: parent
            visible: root.view === "todo"
        }

        // ======================= TIMER ====================================
        QsTimerView {
            anchors.fill: parent
            visible: root.view === "timer"
        }
    }
}
