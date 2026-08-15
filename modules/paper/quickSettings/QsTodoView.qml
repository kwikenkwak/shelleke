pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The to-do pane of the calendar area, backed by the `Todo` singleton.
 *
 * Rows of a PaperCheck, the task, and a trash icon button, one hairline apart.
 * A completed task drops to `ink-4` and takes a 1 px strike — the strike is a
 * rule, so the checkbox stays the only new mark on screen. At the bottom, the
 * adder: a borderless field with a leading `plus` in hairline, a boxed field
 * with a trailing `plus` button in the other two.
 *
 * Ledger heads the pane with a `TASKS` section header carrying the open count;
 * hairline and broadsheet let the tab row do that job.
 */
Item {
    id: root

    readonly property var items: Todo.list ?? []
    readonly property int openCount: root.items.filter(t => !(t?.done ?? false)).length

    function commit(): void {
        const t = adder.text.trim();
        if (t.length > 0) {
            Todo.addTask(t);
            adder.clear();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: PaperTheme.pick(8, 6, 5)

        PaperSectionHeader {
            Layout.fillWidth: true
            visible: PaperTheme.isLedger
            label: "Tasks"
            meta: root.openCount + " open"
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: root.items
                }

                delegate: Item {
                    id: todoRow
                    required property int index
                    required property var modelData

                    readonly property bool done: todoRow.modelData?.done ?? false

                    width: list.width
                    implicitHeight: Math.max(check.implicitHeight, taskText.implicitHeight, deleteButton.implicitHeight) + 2 * PaperTheme.pick(11, 5, 4) + (todoRow.index > 0 ? PaperTheme.ruleWidth : 0)
                    height: implicitHeight

                    PaperRule {
                        visible: todoRow.index > 0
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                    }

                    PaperCheck {
                        id: check
                        anchors.left: parent.left
                        anchors.verticalCenter: taskText.verticalCenter
                        checked: todoRow.done
                        onToggled: {
                            if (todoRow.done)
                                Todo.markUnfinished(todoRow.index);
                            else
                                Todo.markDone(todoRow.index);
                        }
                    }

                    PaperText {
                        id: taskText
                        anchors.left: check.right
                        anchors.leftMargin: PaperTheme.pick(14, 8, 8)
                        anchors.right: deleteButton.left
                        anchors.rightMargin: PaperTheme.pick(14, 8, 8)
                        anchors.verticalCenter: parent.verticalCenter
                        role: PaperTheme.pick("body", "small", "small")
                        tone: todoRow.done ? "ink4" : "ink"
                        struck: todoRow.done
                        text: todoRow.modelData?.content ?? ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    PaperButton {
                        id: deleteButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        shape: "icon"
                        icon: "trash"
                        iconSize: PaperTheme.pick(14, 13, 14)
                        implicitWidth: PaperTheme.pick(18, 20, 20)
                        implicitHeight: PaperTheme.pick(18, 20, 20)
                        onClicked: Todo.deleteItem(todoRow.index)

                        PaperTooltip {
                            text: "Delete"
                            anchorEdges: Edges.Left
                            anchorGravity: Edges.Left
                        }
                    }
                }
            }

            PaperEmpty {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: list.count === 0
                text: "No tasks"
            }
        }

        // ---- the adder --------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.pick(12, 6, 6)

            PaperField {
                id: adder
                Layout.fillWidth: true
                // Hairline's adder is the borderless field variant with a
                // leading glyph; the other two box it.
                borderless: PaperTheme.isHairline
                icon: PaperTheme.isHairline ? "plus" : ""
                placeholder: "Add task…"
                onAccepted: root.commit()
            }

            PaperButton {
                Layout.alignment: Qt.AlignVCenter
                shape: "icon"
                icon: PaperTheme.isHairline ? "arrowR" : "plus"
                iconSize: PaperTheme.pick(14, 14, 15)
                implicitWidth: PaperTheme.pick(18, 24, 26)
                implicitHeight: PaperTheme.pick(18, 24, 26)
                onClicked: root.commit()

                PaperTooltip {
                    text: "Add task"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }
        }
    }
}
