pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * One existing task in the "New worktree" dialog's reopen list. Click it to get that
 * task's kitty window back with the tabs it was created with. Fills on hover like every
 * other pixel button, so the whole row reads as one target.
 *
 * The trailing "+" is the second verb: load the task into the form above to add a repo to
 * it. It stays filled (`loaded`) while that is what the dialog is doing.
 */
PixButton {
    id: root

    property string task: ""
    property var repos: []
    property int tabCount: 0
    // This is the task currently loaded into the form above.
    property bool loaded: false

    signal activated
    signal extendRequested

    implicitHeight: 32
    onClicked: root.activated()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        PixText {
            text: root.task
            font.bold: true
            font.pixelSize: PixTheme.font.pixelSize.small
            color: root.contentColor
            elide: Text.ElideRight
            Layout.maximumWidth: 170
        }
        PixText {
            Layout.fillWidth: true
            text: root.repos.join(", ")
            font.pixelSize: PixTheme.font.pixelSize.smaller
            color: root.contentColor
            elide: Text.ElideRight
        }
        PixText {
            visible: root.tabCount > 0
            text: root.tabCount + " tabs"
            font.pixelSize: PixTheme.font.pixelSize.smaller
            color: root.contentColor
        }
        // A button inside a button: its MouseArea sits above the row's, so a click here
        // adds repos instead of reopening.
        PixButton {
            id: plusBtn
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            filled: root.loaded
            interactive: root.interactive
            onClicked: root.extendRequested()

            PixText {
                anchors.centerIn: parent
                text: "+"
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.small
                color: plusBtn.contentColor
            }
            PixTooltip {
                text: "Add repos to " + root.task
            }
        }
    }
}
