pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common.functions
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A single notification group row. A 34x34 hollow square holds the app icon
 * (grayscale + pixelated via PixAppIcon), aligned to the top of a text column
 * that fills the remaining width. The text column shows a title row (app name,
 * relative time, count chip) and the latest summary/body. Clicking the row (or
 * the count chip) expands a group of >1 notifications to list every entry, with
 * the chevron flipping to indicate state. Each expanded entry can be dismissed.
 */
Item {
    id: root
    // The group object from Notifications.groupsByAppName[appName].
    property var group: null

    readonly property var notifications: group?.notifications ?? []
    // Newest first for display. Index access (not spread) mirrors ii's proven path.
    readonly property var orderedNotifications: notifications.slice().reverse()
    readonly property var latest: notifications.length ? notifications[notifications.length - 1] : null
    readonly property string appName: group?.appName ?? ""
    readonly property int count: notifications.length
    readonly property bool expandable: count > 1

    property bool expanded: false

    // Collapse if the group shrinks to a single item.
    onExpandableChanged: if (!expandable) expanded = false

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
                fallbackIcon: "message" // notifications without a theme icon
            }
        }

        Column {
            width: parent.width - iconSquare.width - parent.spacing
            spacing: 3

            // Title row: app name | time | count chip. Fixed height so the app
            // name baseline lines up with the top of the icon square.
            Item {
                width: parent.width
                height: 18

                PixText {
                    id: titleText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appName !== "" ? root.appName : "Notification"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small
                    elide: Text.ElideRight
                    width: Math.max(0, parent.width - timeText.width - countChip.width - 16)
                }
                PixText {
                    id: timeText
                    anchors.right: countChip.visible ? countChip.left : parent.right
                    anchors.rightMargin: countChip.visible ? 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotificationUtils.getFriendlyNotifTimeString(root.latest?.time ?? 0)
                    color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.small
                }
                // Count chip: number + chevron. Only when the group expands.
                Rectangle {
                    id: countChip
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.expandable
                    width: chipRow.implicitWidth + 10
                    height: 18
                    radius: 0
                    antialiasing: false
                    color: chipMouse.containsMouse ? PixTheme.colors.line : "transparent"
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
                            color: chipMouse.containsMouse ? PixTheme.colors.bg : PixTheme.colors.fg
                        }
                        PixIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevD"
                            size: 9
                            color: chipMouse.containsMouse ? PixTheme.colors.bg : PixTheme.colors.fg
                            // Flip to point up when expanded.
                            rotation: root.expanded ? 180 : 0
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: PixTheme.animation.duration
                                    easing.type: PixTheme.animation.type
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }
            }

            // Collapsed preview: latest summary + body. The MouseArea must NOT
            // be anchored inside a Column (that breaks the positioner and the
            // text stops laying out / goes blank), so the text lives in its own
            // Column and the click target fills the wrapping Item alongside it.
            Item {
                id: preview
                width: parent.width
                height: previewCol.implicitHeight
                visible: !root.expanded

                // Primary line: prefer the summary, fall back to the body so the
                // collapsed row is never blank when there is any content.
                readonly property string primary: {
                    const s = root.latest?.summary ?? "";
                    return s.length > 0 ? s : (root.latest?.body ?? "");
                }
                // Secondary line: the body, but only when it isn't already shown
                // as the primary line.
                readonly property string secondary: {
                    const s = root.latest?.summary ?? "";
                    const b = root.latest?.body ?? "";
                    return (s.length > 0 && b.length > 0) ? b : "";
                }

                Column {
                    id: previewCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    PixText {
                        width: parent.width
                        text: preview.primary
                        font.bold: true
                        font.pixelSize: PixTheme.font.pixelSize.normal
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                    PixText {
                        width: parent.width
                        text: preview.secondary
                        color: PixTheme.colors.grey
                        font.pixelSize: PixTheme.font.pixelSize.small
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                MouseArea {
                    // Tap the preview to expand (when expandable) or dismiss the
                    // single latest notification otherwise.
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.expandable)
                            root.expanded = true;
                        else if (root.latest)
                            Notifications.discardNotification(root.latest.notificationId);
                    }
                }
            }

            // Expanded list: every notification in the group, newest first.
            Column {
                width: parent.width
                spacing: 6
                visible: root.expanded

                Repeater {
                    model: root.expanded ? root.orderedNotifications : []
                    delegate: Item {
                        id: entry
                        required property var modelData
                        width: parent.width
                        implicitHeight: entryCol.implicitHeight

                        Column {
                            id: entryCol
                            width: parent.width - 26
                            spacing: 1

                            PixText {
                                width: parent.width
                                text: entry.modelData?.summary ?? ""
                                font.bold: true
                                font.pixelSize: PixTheme.font.pixelSize.normal
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                            PixText {
                                width: parent.width
                                text: entry.modelData?.body ?? ""
                                color: PixTheme.colors.grey
                                font.pixelSize: PixTheme.font.pixelSize.small
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                        }

                        // Per-notification dismiss (monochrome trash button).
                        PixButton {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            implicitWidth: 22
                            implicitHeight: 22
                            onClicked: {
                                if (entry.modelData)
                                    Notifications.discardNotification(entry.modelData.notificationId);
                            }
                            PixIcon {
                                anchors.centerIn: parent
                                name: "trash"
                                size: 12
                                color: parent.contentColor
                            }
                        }
                    }
                }
            }
        }
    }
}
