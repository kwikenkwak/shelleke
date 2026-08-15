pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

/**
 * A single paper toast — §4.4 of all three SPECs.
 *
 * SURFACE-LOCAL, and the deliberate cousin of the shared `PaperNotifRow`.
 * Assessed for merging during integration and kept separate: a toast is a
 * floating sheet holding ONE notification with action buttons and a dismiss
 * affordance, while PaperNotifRow is a ruled list row holding a GROUP with an
 * expander. They share a type stack (kicker · time · summary · body), not a
 * shape. If that stack ever drifts between the two, factor the stack out — not
 * the row. See HANDOFF §3 "Promotion candidates".
 *
 * Three signatures, one tree:
 *   hairline   — 372 px, 15/18 padding. A 16 px app glyph in a 12 px gutter, a
 *                micro-caps app name + mono time header, a 13 px summary, a
 *                12 px 2-line body, and one FRAMELESS caps action per labelled
 *                action, 26 px apart. The first action carries the ink
 *                underline as the implied default. Urgency is a single 6 px
 *                `alert` dot at the head of the header — the only colour on
 *                the surface.
 *   ledger     — 344 px, 11 px padding, a 28 px plate. Urgency is a 2 px
 *                stamp-red change bar down the left edge plus a `warn` glyph on
 *                the plate: a margin mark, the way an accountant flags a line.
 *                Actions are equal-width framed buttons, 8 px apart.
 *   broadsheet — 356 px floating sheet with corner ticks, 12/13 padding. The
 *                four levels of an editorial item: kicker, agate, a Pagella
 *                headline, a Pagella deck. Full-width equal buttons.
 *
 * Hovering cancels the service's auto-dismiss timer (and applies hairline's 4 %
 * wash); clicking the toast fires the notification's default action and
 * dismisses it; clicking an action fires that action and dismisses. The
 * unlabelled "default" action is never drawn as a button, in any variant.
 */
PaperPanel {
    id: root

    required property var notif

    readonly property string appName: root.notif?.appName ?? ""
    readonly property string appIconName: root.notif?.appIcon ?? ""
    readonly property string summaryText: root.notif?.summary ?? ""
    readonly property string bodyText: root.notif?.body ?? ""
    readonly property double notifTime: root.notif?.time ?? 0

    /// The service stores urgency as the stringified enum (see Notifications.qml).
    readonly property bool urgent: (root.notif?.urgency ?? "") === NotificationUrgency.Critical.toString()

    /// Only real, labelled actions become buttons. The unlabelled "default"
    /// action is the click-to-activate action, not a visible control.
    readonly property var actionList: (root.notif?.actions ?? []).filter(a => (a.text ?? "").trim().length > 0 && a.identifier !== "default")
    readonly property var defaultAction: (root.notif?.actions ?? []).find(a => a.identifier === "default")

    /// Hairline marks urgency with a dot; the other two with a change bar in
    /// the left margin and a `warn` glyph in place of the app icon.
    readonly property bool marginMark: root.urgent && !PaperTheme.isHairline

    signal dismissed

    // -- metrics ------------------------------------------------------------
    readonly property int padV: PaperTheme.pick(15, 11, 12)
    readonly property int padH: PaperTheme.pick(18, 11, 13)
    readonly property int gutter: PaperTheme.pick(12, 10, 11)
    /// 16 in hairline (bare glyph), a 28 px plate in ledger, a 32 px slot in C.
    readonly property int iconBox: PaperTheme.pick(16, 28, 32)

    kind: "sheet"
    floating: true
    ticks: true

    implicitHeight: content.implicitHeight + 2 * root.padV

    // Hairline's 4 % hover wash — the only background change any control makes
    // in that variant. Ledger and broadsheet hold the sheet still and mark the
    // hovered action instead.
    color: (hoverArea.containsMouse && PaperTheme.isHairline) ? PaperTheme.wash : PaperTheme.paperRaise

    // Enter: a fade plus a 4 px slide, the family's hard travel ceiling. There
    // is no exit animation — the service removes the model entry outright.
    property real enterSlide: PaperTheme.motion.maxTravel
    opacity: 0
    transform: Translate {
        x: root.enterSlide
    }
    Component.onCompleted: {
        root.opacity = 1;
        root.enterSlide = 0;
    }
    Behavior on opacity {
        NumberAnimation {
            duration: PaperTheme.motion.slow
            easing.type: PaperTheme.motion.type
            easing.bezierCurve: PaperTheme.motion.bezierCurve
        }
    }
    Behavior on enterSlide {
        NumberAnimation {
            duration: PaperTheme.motion.slow
            easing.type: PaperTheme.motion.type
            easing.bezierCurve: PaperTheme.motion.bezierCurve
        }
    }

    // -- relative time ------------------------------------------------------

    function relativeTime(): string {
        if (root.notifTime <= 0)
            return "";
        const mins = Math.floor((Date.now() - root.notifTime) / 60000);
        if (mins < 1)
            return Translation.tr("now");
        if (mins < 60)
            return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + "h";
        return Math.floor(hours / 24) + "d";
    }

    property string timeLabel: root.relativeTime()
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.timeLabel = root.relativeTime()
    }

    // -- the urgent change bar (ledger / broadsheet) ------------------------

    Rectangle {
        visible: root.marginMark
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: PaperTheme.changeBarWidth
        color: PaperTheme.alert
        antialiasing: false
        z: 3
    }

    // -- interaction --------------------------------------------------------

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onEntered: {
            if (root.notif)
                Notifications.cancelTimeout(root.notif.notificationId);
        }
        onClicked: {
            if (root.notif && root.defaultAction)
                Notifications.attemptInvokeAction(root.notif.notificationId, root.defaultAction.identifier);
            root.dismissed();
        }
    }

    // -- content ------------------------------------------------------------

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: root.padV
            leftMargin: root.padH + (root.marginMark ? PaperTheme.changeBarWidth : 0)
            rightMargin: root.padH
        }
        spacing: root.gutter

        // The app icon. Urgent notifications in ledger/broadsheet swap it for
        // the `warn` glyph, per those SPECs.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.iconBox
            implicitHeight: root.iconBox

            PaperAppIcon {
                id: appGlyph
                anchors.fill: parent
                visible: !root.marginMark
                // The plate is the widget's, but the toast owns its size: the
                // implicit size drives the plate rectangle, which fills it.
                size: PaperTheme.pick(16, 16, 20)
                plate: PaperTheme.appIcon.plate
                icon: root.appIconName
                fallbackIcon: "message"
            }

            Rectangle {
                anchors.fill: parent
                visible: root.marginMark
                color: "transparent"
                radius: PaperTheme.radiusControl
                antialiasing: radius > 0
                border.width: PaperTheme.ruleWidth
                border.color: PaperTheme.alert
                PaperIcon {
                    anchors.centerIn: parent
                    name: "warn"
                    size: PaperTheme.pick(16, 16, 20)
                    color: PaperTheme.alert
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.pick(5, 2, 2)

            // Header: urgency dot (hairline) + app name + relative time.
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.pick(9, 8, 8)

                Rectangle {
                    visible: root.urgent && PaperTheme.isHairline
                    implicitWidth: PaperTheme.size.dot
                    implicitHeight: PaperTheme.size.dot
                    radius: PaperTheme.size.dot / 2
                    antialiasing: true
                    color: PaperTheme.alert
                }

                PaperText {
                    Layout.fillWidth: true
                    // Ledger names the app in mixed-case 12/600; the other two
                    // treat it as a kicker (micro-caps).
                    role: PaperTheme.isLedger ? "small" : "micro"
                    tone: PaperTheme.isLedger ? "ink" : "ink3"
                    font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.medium
                    elide: Text.ElideRight
                    text: root.appName
                }

                PaperText {
                    role: "meta"
                    tone: "ink3"
                    // Broadsheet sets its agate in Pagella oldstyle figures;
                    // hairline and ledger use the mono face.
                    mono: !PaperTheme.isBroadsheet
                    figure: PaperTheme.isBroadsheet
                    text: root.timeLabel
                    visible: text.length > 0
                }
            }

            // Summary — the headline.
            PaperText {
                Layout.fillWidth: true
                Layout.topMargin: PaperTheme.pick(0, 1, 1)
                role: PaperTheme.isBroadsheet ? "lead" : "body"
                tone: "ink"
                font.family: PaperTheme.isBroadsheet ? PaperTheme.fontTitle : PaperTheme.fontBody
                font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.normal
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.summaryText
                visible: text.length > 0
            }

            // Body — the deck. Wrapped, clamped to two lines, in all variants.
            PaperText {
                Layout.fillWidth: true
                role: "small"
                tone: "ink2"
                font.family: PaperTheme.isBroadsheet ? PaperTheme.fontTitle : PaperTheme.fontBody
                lineHeight: PaperTheme.pick(1.5, 1.45, 1.42)
                lineHeightMode: Text.ProportionalHeight
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                text: root.bodyText
                visible: text.length > 0
            }

            // Actions.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: PaperTheme.pick(11, 9, 8)
                spacing: PaperTheme.pick(26, 8, 8)
                visible: root.actionList.length > 0

                Repeater {
                    model: root.actionList

                    delegate: PaperButton {
                        id: actionButton
                        required property int index
                        required property var modelData

                        // Hairline lays its actions out as free-standing caps
                        // labels; the other two stretch equal-width buttons.
                        Layout.fillWidth: !PaperTheme.isHairline
                        Layout.preferredHeight: PaperTheme.pick(actionButton.implicitHeight, 26, 27)
                        shape: "caps"
                        label: actionButton.modelData?.text ?? ""
                        // The first action is the implied default in hairline,
                        // which draws it with the ink underline.
                        checked: PaperTheme.isHairline && actionButton.index === 0
                        onClicked: {
                            if (root.notif)
                                Notifications.attemptInvokeAction(root.notif.notificationId, actionButton.modelData.identifier);
                            root.dismissed();
                        }
                    }
                }

                // Hairline's caps actions sit left-aligned, not stretched.
                Item {
                    Layout.fillWidth: PaperTheme.isHairline
                    visible: PaperTheme.isHairline
                }
            }
        }
    }
}
