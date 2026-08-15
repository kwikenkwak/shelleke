import QtQuick
import qs.modules.paper.common

/**
 * An empty / busy state: "No notifications", "Scanning…", "No tasks",
 * "Wi-Fi off", "Bluetooth off".
 *
 *   PaperEmpty { width: parent.width; text: "No notifications" }
 *   PaperEmpty { width: parent.width; text: "Scanning…"; rules: false }
 *
 * Per variant:
 *   hairline   — `ink-4` at 11 px BETWEEN TWO RULES, left aligned. The rules
 *                are what stop an empty region from reading as a broken panel.
 *   ledger     — the same 11 px `ink-4`, centred, no rules.
 *   broadsheet — a Pagella *italic* footnote (`PaperText { footnote: true }`),
 *                left aligned, no rules.
 *
 * Nothing here is a colour: an empty list is not a failure.
 */
Item {
    id: root

    property string text: ""
    /// Bracket the message with a hairline above and below. Hairline's habit.
    property bool rules: PaperTheme.isHairline
    /// left | center
    property string align: PaperTheme.pick("left", "center", "left")

    readonly property real padV: PaperTheme.pick(18, 6, 6)

    implicitWidth: 200
    implicitHeight: message.implicitHeight + 2 * root.padV + (root.rules ? 2 * PaperTheme.ruleWidth : 0)

    PaperRule {
        visible: root.rules
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    PaperText {
        id: message
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        role: "meta"
        tone: "ink4"
        // Broadsheet sets every placeholder, hint and empty state in italic.
        footnote: true
        text: root.text
        horizontalAlignment: root.align === "center" ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
    }

    PaperRule {
        visible: root.rules
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }
}
