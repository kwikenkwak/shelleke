import QtQuick
import qs.modules.common.functions
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A single notification group row: a 34x34 hollow square holding the app icon
 * (grayscale + pixelated via PixAppIcon), then a title row (app name, relative
 * time, count chip) followed by the latest summary (bold) and body (grey).
 */
Item {
    id: root
    // The group object from Notifications.groupsByAppName[appName].
    property var group: null

    readonly property var notifications: group?.notifications ?? []
    readonly property var latest: notifications.length > 0 ? notifications[notifications.length - 1] : null
    readonly property string appName: group?.appName ?? ""
    readonly property int count: notifications.length

    implicitHeight: layout.implicitHeight

    Row {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        // App icon square (hollow). PixAppIcon enforces grayscale+pixelated.
        Rectangle {
            id: iconSquare
            width: 34
            height: 34
            radius: 0
            antialiasing: false
            color: "transparent"
            border.width: PixTheme.borderWidth
            border.color: PixTheme.colors.line

            PixAppIcon {
                anchors.centerIn: parent
                size: 22
                pixelResolution: 16
                icon: root.group?.appIcon ?? ""
            }
        }

        Column {
            width: parent.width - iconSquare.width - parent.spacing
            spacing: 1

            // Title row: app name | time | count chip
            Item {
                width: parent.width
                height: titleText.implicitHeight

                PixText {
                    id: titleText
                    anchors.left: parent.left
                    text: root.appName
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small
                    elide: Text.ElideRight
                    width: Math.max(0, parent.width - timeText.width - countChip.width - 16)
                }
                PixText {
                    id: timeText
                    anchors.right: countChip.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotificationUtils.getFriendlyNotifTimeString(root.latest?.time ?? 0)
                    color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.small
                }
                Row {
                    id: countChip
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: chipRow.implicitWidth + 10
                        height: chipRow.implicitHeight + 2
                        radius: 0
                        antialiasing: false
                        color: "transparent"
                        border.width: PixTheme.borderWidth
                        border.color: PixTheme.colors.line
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 3
                            PixText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.count
                                font.pixelSize: PixTheme.font.pixelSize.smaller
                            }
                            PixIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevD"
                                size: 9
                            }
                        }
                    }
                }
            }

            PixText {
                width: parent.width
                text: root.latest?.summary ?? ""
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.normal
                elide: Text.ElideRight
                visible: text.length > 0
            }
            PixText {
                width: parent.width
                text: root.latest?.body ?? ""
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.small
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
}
