pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * One candidate repo in the "New worktree" dialog: a filled/hollow square toggle for
 * "make a worktree of this repo", and — once selected — a chip per vitulina server for
 * "open a `vitulina up` tab for it".
 */
Rectangle {
    id: root

    property string repo: ""
    property var servers: []
    property bool selected: false
    property var pickedServers: []

    signal toggled
    signal serverToggled(string server)

    implicitHeight: content.implicitHeight + 2 * pad
    readonly property int pad: 8

    radius: 0
    antialiasing: false
    color: "transparent"
    border.width: PixTheme.borderWidth
    border.color: root.selected ? PixTheme.colors.fg : PixTheme.colors.line

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PixButton {
                id: check
                implicitWidth: 22
                implicitHeight: 22
                filled: root.selected
                onClicked: root.toggled()
            }
            PixText {
                Layout.fillWidth: true
                text: root.repo
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.normal
                elide: Text.ElideRight
            }
            PixText {
                text: root.servers.length + " srv"
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
        }

        // A fixed 3-column grid rather than a Flow: the widest repo has six servers, and
        // a wrapping positioner inside a Layout re-triggers the layout pass.
        GridLayout {
            Layout.fillWidth: true
            visible: root.selected && root.servers.length > 0
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root.servers
                delegate: PixButton {
                    id: chip
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    implicitWidth: chipLabel.implicitWidth + 16
                    filled: root.pickedServers.indexOf(chip.modelData) >= 0
                    onClicked: root.serverToggled(chip.modelData)
                    PixText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData
                        font.pixelSize: PixTheme.font.pixelSize.smaller
                        color: chip.contentColor
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, chip.width - 8)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        PixText {
            Layout.fillWidth: true
            visible: root.selected && root.servers.length === 0
            text: "no vitulina servers — gets a shell tab"
            color: PixTheme.colors.grey2
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
    }

    // Clicking anywhere on the row (outside the chips) toggles the repo.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.toggled()
    }
}
