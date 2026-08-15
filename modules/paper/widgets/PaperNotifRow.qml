pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications
import qs.modules.common.functions
import qs.modules.paper.common

/**
 * One notification GROUP, as it appears in a list (quick settings today; the
 * notification centre next). Replaces PixNotifRow.
 *
 *   PaperNotifRow {
 *       width: list.width
 *       group: Notifications.groupsByAppName[appName]
 *       separator: index > 0
 *       onDismiss: id => Notifications.discardNotification(id)
 *   }
 *
 * `group` is `{ appName, appIcon, notifications: [ … ] }` — the shape
 * `Notifications.groupsByAppName` produces. The widget owns only its expansion
 * state; every mutation leaves through a signal, so the same row can serve a
 * surface that discards, one that snoozes and one that does neither.
 *
 * Collapsed it shows the app plate, a header line (app name · relative time ·
 * an optional count + chevron) and the latest summary over its body, both
 * elided to one line. Clicking expands a group of more than one, or dismisses a
 * single notification. Expanded it lists every notification newest-first with
 * the body wrapped to three lines and a discard button per entry.
 *
 * Per variant:
 *   hairline   — a 16 px app icon, a 12 px gutter, no chip border: the count is
 *                a mono numeral beside a chevron. Entries indent to 29 px and
 *                are separated by hairlines. An urgent group takes the 6 px
 *                `alert` dot — one of the six places hairline permits colour.
 *   ledger     — the group is a hairline CARD (`card: true` by default there);
 *                a 26 px app plate, a real bordered count chip, entries ruled
 *                inside the card.
 *   broadsheet — a 30 px app slot, an editorial ladder: kicker (app) → agate
 *                (age) → lede (summary, set in the display face) → deck (body).
 *
 * The chevron rotates 180° in `motion.base`. Nothing else moves.
 */
Item {
    id: root

    /// A group object from Notifications.groupsByAppName.
    property var group: null
    /// A 1 px hairline above the row. Set `index > 0` from the delegate.
    property bool separator: false
    /// Wrap the group in a hairline card. Ledger's habit; hairline draws
    /// nothing for a card anyway, broadsheet wants the plain ruled row.
    property bool card: PaperTheme.isLedger

    /// Discard one notification.
    signal dismiss(int notificationId)
    /// The row was clicked and there was nothing to expand or dismiss.
    signal activated

    readonly property var notifications: root.group?.notifications ?? []
    /// Newest first for display. Index access (not spread) mirrors the proven
    /// path in the pixel/ii implementations.
    readonly property var orderedNotifications: root.notifications.slice().reverse()
    readonly property var latest: root.notifications.length ? root.notifications[root.notifications.length - 1] : null
    readonly property string appName: root.group?.appName ?? ""
    readonly property int count: root.notifications.length
    readonly property bool expandable: root.count > 1
    /// `Notifications.qml` stores urgency as `notification.urgency.toString()`,
    /// i.e. the STRINGIFIED enum value — not the word "critical". Compare the
    /// same way the rest of the repo does (see
    /// `modules/common/widgets/NotificationGroup.qml`), or this never fires.
    readonly property bool urgent: (root.latest?.urgency ?? "") === NotificationUrgency.Critical.toString()

    property bool expanded: false
    onExpandableChanged: if (!root.expandable)
        root.expanded = false

    /// True where the variant frames a count chip. Hairline never does — the
    /// count is a numeral and a chevron, with no box around them.
    readonly property bool chipFramed: PaperTheme.ornament.framedControls

    readonly property real appIconSize: PaperTheme.pick(16, 20, 20)
    readonly property real gutter: PaperTheme.pick(13, 10, 10)
    readonly property real padV: PaperTheme.pick(13, 9, 8)
    readonly property real padH: PaperTheme.pick(0, 8, 2)
    /// Broadsheet sets the summary and body of a notification in the DISPLAY
    /// face — the editorial lede/deck. The other two use the body face. This is
    /// the one place this widget names a font, and the reason is structural.
    readonly property string ledeFamily: PaperTheme.isBroadsheet ? PaperTheme.fontSerif : PaperTheme.fontBody

    implicitWidth: 300
    implicitHeight: frame.implicitHeight + (root.separator ? PaperTheme.ruleWidth + PaperTheme.pick(0, 0, 2) : 0)

    PaperRule {
        visible: root.separator
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Item {
        id: frame
        anchors.top: parent.top
        anchors.topMargin: root.separator ? PaperTheme.ruleWidth + PaperTheme.pick(0, 0, 2) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: body.implicitHeight + 2 * root.padV
        height: implicitHeight

        // The card. Ledger rules a group into its own sheet; hairline has no
        // cards at all and broadsheet separates groups with plain hairlines,
        // so both leave this off.
        Rectangle {
            anchors.fill: parent
            visible: root.card
            color: PaperTheme.paperRaise
            radius: PaperTheme.radiusCard
            antialiasing: radius > 0
            border.width: PaperTheme.ruleWidth
            border.color: PaperTheme.rule
        }

        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.padH
            anchors.rightMargin: root.padH
            anchors.topMargin: root.padV
            implicitHeight: Math.max(appIcon.height, column.implicitHeight)
            height: implicitHeight

            PaperAppIcon {
                id: appIcon
                anchors.left: parent.left
                anchors.top: parent.top
                size: root.appIconSize
                plate: PaperTheme.appIcon.plate
                icon: root.group?.appIcon ?? ""
                fallbackIcon: "message"
            }

            Column {
                id: column
                anchors.left: appIcon.right
                anchors.leftMargin: root.gutter
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: PaperTheme.pick(4, 3, 2)

                // ---- header line: dot · app · time · count + chevron -------
                Item {
                    id: header
                    width: parent.width
                    height: Math.max(appText.implicitHeight, countChip.implicitHeight)

                    Rectangle {
                        id: urgentDot
                        visible: root.urgent
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: PaperTheme.size.dot
                        height: PaperTheme.size.dot
                        radius: width / 2
                        antialiasing: true
                        color: PaperTheme.alert
                    }

                    PaperText {
                        id: appText
                        anchors.left: urgentDot.visible ? urgentDot.right : parent.left
                        anchors.leftMargin: urgentDot.visible ? PaperTheme.pick(9, 6, 6) : 0
                        anchors.right: timeText.left
                        anchors.rightMargin: PaperTheme.pick(9, 7, 7)
                        anchors.verticalCenter: parent.verticalCenter
                        // Hairline and broadsheet set the app name as a kicker;
                        // ledger sets it as the card's own bold title.
                        role: PaperTheme.isLedger ? "small" : "micro"
                        tone: PaperTheme.isLedger ? "ink" : "ink3"
                        font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.medium
                        text: root.appName !== "" ? root.appName : "Notification"
                        elide: Text.ElideRight
                    }

                    PaperText {
                        id: timeText
                        anchors.right: countChip.visible ? countChip.left : parent.right
                        anchors.rightMargin: countChip.visible ? PaperTheme.pick(9, 7, 7) : 0
                        anchors.verticalCenter: parent.verticalCenter
                        role: "meta"
                        tone: "ink3"
                        mono: !PaperTheme.isBroadsheet
                        figure: PaperTheme.isBroadsheet
                        text: NotificationUtils.getFriendlyNotifTimeString(root.latest?.time ?? 0)
                    }

                    // The count. A bordered chip where the variant frames its
                    // controls; a bare mono numeral plus a chevron in hairline.
                    Item {
                        id: countChip
                        visible: root.expandable
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: chipRow.implicitWidth + (root.chipFramed ? 2 * 5 : 0)
                        implicitHeight: chipRow.implicitHeight + (root.chipFramed ? 2 * 3 : 0)
                        width: implicitWidth
                        height: implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            visible: root.chipFramed
                            radius: PaperTheme.radiusControl
                            antialiasing: radius > 0
                            color: chipMouse.containsMouse ? PaperTheme.wash : "transparent"
                            border.width: PaperTheme.ruleWidth
                            border.color: chipMouse.containsMouse ? PaperTheme.rule2 : PaperTheme.rule
                        }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: PaperTheme.pick(5, 4, 4)

                            PaperText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "micro"
                                figure: true
                                tone: chipMouse.containsMouse ? "ink" : "ink3"
                                text: root.count
                            }
                            PaperIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevD"
                                size: PaperTheme.icon.tiny - 2
                                color: chipMouse.containsMouse ? PaperTheme.ink : PaperTheme.ink3
                                rotation: root.expanded ? 180 : 0

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: PaperTheme.motion.base
                                        easing.type: PaperTheme.motion.type
                                        easing.bezierCurve: PaperTheme.motion.bezierCurve
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

                // ---- collapsed preview -------------------------------------
                Item {
                    id: preview
                    width: parent.width
                    height: visible ? previewColumn.implicitHeight : 0
                    visible: !root.expanded

                    // Prefer the summary; fall back to the body so a collapsed
                    // row is never blank when there is any content at all.
                    readonly property string primary: {
                        const s = root.latest?.summary ?? "";
                        return s.length > 0 ? s : (root.latest?.body ?? "");
                    }
                    readonly property string secondary: {
                        const s = root.latest?.summary ?? "";
                        const b = root.latest?.body ?? "";
                        return (s.length > 0 && b.length > 0) ? b : "";
                    }

                    // The MouseArea must NOT be anchored inside a Column (it
                    // breaks the positioner and the text stops laying out), so
                    // the text lives in its own Column and the click target
                    // fills this wrapping Item alongside it.
                    Column {
                        id: previewColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: PaperTheme.pick(2, 1, 1)

                        PaperText {
                            width: parent.width
                            visible: text.length > 0
                            text: preview.primary
                            role: PaperTheme.pick("body", "small", "lead")
                            font.family: root.ledeFamily
                            font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.normal
                            elide: Text.ElideRight
                        }
                        PaperText {
                            width: parent.width
                            visible: text.length > 0
                            text: preview.secondary
                            role: PaperTheme.pick("small", "meta", "small")
                            tone: "ink2"
                            font.family: root.ledeFamily
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.expandable)
                                root.expanded = true;
                            else if (root.latest)
                                root.dismiss(root.latest.notificationId);
                            else
                                root.activated();
                        }
                    }
                }

                // ---- expanded entries, newest first ------------------------
                Column {
                    width: parent.width
                    visible: root.expanded
                    spacing: 0

                    Repeater {
                        model: root.expanded ? root.orderedNotifications : []

                        delegate: Item {
                            id: entry
                            required property int index
                            required property var modelData

                            width: parent.width
                            implicitHeight: entryColumn.implicitHeight + 2 * PaperTheme.pick(10, 6, 6) + (entry.index > 0 ? PaperTheme.ruleWidth : 0)
                            height: implicitHeight

                            PaperRule {
                                visible: entry.index > 0
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                            }

                            Column {
                                id: entryColumn
                                anchors.left: parent.left
                                anchors.right: discardButton.left
                                anchors.rightMargin: PaperTheme.pick(12, 8, 8)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: PaperTheme.pick(3, 1, 1)

                                PaperText {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: entry.modelData?.summary ?? ""
                                    role: PaperTheme.pick("body", "small", "small")
                                    font.family: root.ledeFamily
                                    font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.normal
                                    elide: Text.ElideRight
                                }
                                PaperText {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: entry.modelData?.body ?? ""
                                    role: PaperTheme.pick("small", "meta", "small")
                                    tone: "ink2"
                                    font.family: root.ledeFamily
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            PaperButton {
                                id: discardButton
                                anchors.right: parent.right
                                anchors.top: entryColumn.top
                                shape: "icon"
                                icon: "trash"
                                iconSize: PaperTheme.pick(14, 13, 14)
                                implicitWidth: PaperTheme.pick(18, 20, 22)
                                implicitHeight: PaperTheme.pick(18, 20, 22)
                                onClicked: {
                                    if (entry.modelData)
                                        root.dismiss(entry.modelData.notificationId);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
