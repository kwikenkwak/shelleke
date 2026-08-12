pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * One existing task in the "New worktree" dialog's reopen list. Click it to get that
 * task's kitty window back with the tabs it was created with. Fills on hover like every
 * other pixel button, so the whole row reads as one target.
 */
PixButton {
    id: root

    property string task: ""
    property var repos: []
    property int tabCount: 0

    signal activated

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
    }
}
