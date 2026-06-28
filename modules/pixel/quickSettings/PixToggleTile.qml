import QtQuick
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A wide connectivity/status tile: a small 30x30 icon square (filled when
 * active, hollow when inactive) + a bold title and a grey status sublabel.
 * Clicking the whole tile invokes onActivated().
 */
PixPanel {
    id: root
    property string iconName: ""
    property string title: ""
    property string status: ""
    property bool active: false

    signal activated()

    borderWidth: PixTheme.borderWidth
    implicitHeight: 46

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 9

        // Icon square: filled (fg fill, bg icon) when active, hollow otherwise.
        Rectangle {
            id: iconSquare
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 0
            antialiasing: false
            color: root.active ? PixTheme.colors.fg : "transparent"
            border.width: PixTheme.borderWidth
            border.color: PixTheme.colors.line

            PixIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: 16
                color: root.active ? PixTheme.colors.bg : PixTheme.colors.fg
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - iconSquare.width - parent.spacing
            spacing: 1

            PixText {
                width: parent.width
                text: root.title
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.normal
                elide: Text.ElideRight
            }
            PixText {
                width: parent.width
                text: root.status
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
