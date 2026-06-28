pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Monochrome to-do list backed by the Todo singleton. Each row has a pixel
 * checkbox (filled square = done, hollow = open), the task content, and a
 * delete button. A bottom input row adds new tasks. Everything hard-edged,
 * null-safe.
 */
Item {
    id: root

    readonly property var items: Todo.list ?? []

    Column {
        anchors.fill: parent
        spacing: 6

        // Scrollable list.
        ListView {
            id: list
            width: parent.width
            height: parent.height - inputRow.height - parent.spacing
            clip: true
            spacing: 5
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: root.items
            }
            delegate: Item {
                id: todoRow
                required property int index
                required property var modelData
                width: list.width
                height: Math.max(26, rowContent.implicitHeight + 6)

                readonly property bool done: todoRow.modelData?.done ?? false

                Row {
                    id: rowContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Pixel checkbox: filled when done, hollow otherwise.
                    PixButton {
                        id: check
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 22
                        implicitHeight: 22
                        filled: todoRow.done
                        onClicked: {
                            if (todoRow.done)
                                Todo.markUnfinished(todoRow.index);
                            else
                                Todo.markDone(todoRow.index);
                        }
                        PixIcon {
                            anchors.centerIn: parent
                            visible: todoRow.done
                            name: "todo"
                            size: 12
                            color: check.contentColor
                        }
                    }

                    PixText {
                        width: parent.width - check.width - delBtn.width - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: todoRow.modelData?.content ?? ""
                        color: todoRow.done ? PixTheme.colors.grey : PixTheme.colors.fg
                        font.pixelSize: PixTheme.font.pixelSize.small
                        wrapMode: Text.Wrap
                    }

                    PixButton {
                        id: delBtn
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 22
                        implicitHeight: 22
                        onClicked: Todo.deleteItem(todoRow.index)
                        PixIcon {
                            anchors.centerIn: parent
                            name: "trash"
                            size: 12
                            color: delBtn.contentColor
                        }
                        PixTooltip {
                            text: "Delete"
                            anchorEdges: Edges.Left
                            anchorGravity: Edges.Left
                        }
                    }
                }
            }

            PixText {
                anchors.centerIn: parent
                visible: root.items.length === 0
                text: "No tasks"
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.small
            }
        }

        // ---- Add-task input row ----
        Row {
            id: inputRow
            width: parent.width
            height: 26
            spacing: 8

            function commit() {
                const t = input.text.trim();
                if (t.length > 0) {
                    Todo.addTask(t);
                    input.text = "";
                }
            }

            Rectangle {
                id: inputBox
                width: parent.width - addBtn.width - parent.spacing
                height: 26
                radius: 0
                antialiasing: false
                color: "transparent"
                border.width: PixTheme.borderWidth
                border.color: PixTheme.colors.line

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: PixTheme.colors.fg
                    selectionColor: PixTheme.colors.fg
                    selectedTextColor: PixTheme.colors.bg
                    font.family: PixTheme.fontMain
                    font.pixelSize: PixTheme.font.pixelSize.small
                    onAccepted: inputRow.commit()

                    PixText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text.length === 0 && !input.activeFocus
                        text: "Add task..."
                        color: PixTheme.colors.grey2
                        font.pixelSize: PixTheme.font.pixelSize.small
                    }
                }
            }

            PixButton {
                id: addBtn
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 26
                implicitHeight: 26
                onClicked: inputRow.commit()
                PixIcon {
                    anchors.centerIn: parent
                    name: "pencil"
                    size: 13
                    color: addBtn.contentColor
                }
                PixTooltip {
                    text: "Add"
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }
        }
    }
}
