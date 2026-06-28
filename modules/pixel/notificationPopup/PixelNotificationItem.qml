import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import QtQuick.Layouts

/**
 * PixelNotificationItem — a single monochrome toast.
 *
 * A PixPanel (3px border) containing a 34x34 hollow app-icon square (PixAppIcon,
 * grayscale + pixelated), an app-name + relative-time header row, a bold elided
 * summary, a grey 2-line-elided body, and any notification actions as PixButtons.
 *
 * Hovering pauses the service auto-dismiss timer; clicking the body dismisses.
 * Fully null-safe against a missing/cleared `notif`.
 */
PixPanel {
    id: root
    required property var notif

    readonly property string appName: notif?.appName ?? ""
    readonly property string appIcon: notif?.appIcon ?? ""
    readonly property string summaryText: notif?.summary ?? ""
    readonly property string bodyText: notif?.body ?? ""
    readonly property var actions: notif?.actions ?? []
    readonly property double notifTime: notif?.time ?? 0

    signal dismissed()

    borderWidth: PixTheme.popupBorderWidth
    implicitHeight: contentRow.implicitHeight + 22

    function relativeTime() {
        if (root.notifTime <= 0)
            return "";
        const deltaMs = Date.now() - root.notifTime;
        const mins = Math.floor(deltaMs / 60000);
        if (mins < 1)
            return Translation.tr("now");
        if (mins < 60)
            return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + "h";
        return Math.floor(hours / 24) + "d";
    }

    // Re-evaluate relative time periodically while shown.
    property string timeLabel: relativeTime()
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.timeLabel = root.relativeTime()
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onEntered: {
            if (root.notif)
                Notifications.cancelTimeout(root.notif.notificationId);
        }
        onClicked: root.dismissed()
    }

    RowLayout {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 11
        }
        spacing: 11

        // 34x34 hollow square with the (grayscale, pixelated) app icon.
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 34
            implicitHeight: 34
            radius: 0
            antialiasing: false
            color: "transparent"
            border.width: PixTheme.borderWidth
            border.color: PixTheme.colors.line

            PixAppIcon {
                anchors.centerIn: parent
                size: 24
                icon: root.appIcon
            }
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: 4

            // Header: app name (left) + relative time (right).
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PixText {
                    Layout.fillWidth: true
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small
                    elide: Text.ElideRight
                    text: root.appName
                }
                PixText {
                    color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.small
                    text: root.timeLabel
                    visible: text.length > 0
                }
            }

            PixText {
                Layout.fillWidth: true
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.normal
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.summaryText
                visible: text.length > 0
            }

            PixText {
                Layout.fillWidth: true
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.small
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                text: root.bodyText
                visible: text.length > 0
            }

            // Notification action buttons.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                visible: root.actions.length > 0

                Repeater {
                    model: root.actions
                    delegate: PixButton {
                        id: actionButton
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        borderWidth: PixTheme.borderWidth
                        onClicked: {
                            if (root.notif)
                                Notifications.attemptInvokeAction(
                                    root.notif.notificationId, actionButton.modelData.identifier);
                            root.dismissed();
                        }
                        PixText {
                            anchors.centerIn: parent
                            color: actionButton.contentColor
                            font.pixelSize: PixTheme.font.pixelSize.small
                            elide: Text.ElideRight
                            text: actionButton.modelData.text ?? ""
                        }
                    }
                }
            }
        }
    }
}
