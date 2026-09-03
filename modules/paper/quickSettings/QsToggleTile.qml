import QtQuick
import Quickshell
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The connectivity TILE that ledger and broadsheet use where hairline uses a
 * PaperToggleRow: an icon slot, a title over a status line, in a hairline card.
 *
 * SURFACE-LOCAL for now. Integration checked the one candidate second user —
 * the displays overlay's quick-layout tiles — and they turned out to be
 * `PaperArrange` diagrams and stacked `PaperButton`s, not title-over-status
 * cards. One user, so it stays here; promote it to `PaperToggleTile` the moment
 * a second surface wants the shape. See HANDOFF §3 "Promotion candidates".
 *
 *   QsToggleTile {
 *       icon: "wifi"; title: "Internet"; status: Network.networkName
 *       on: connected; connected: true
 *       tooltip: "Wi-Fi"
 *       onActivated: overlay = "wifi"
 *   }
 *
 *   ledger     — 42 px card, a 24 px icon plate; on = blue frame, blue wash,
 *                blue plate, blue title.
 *   broadsheet — 48 px card, a 28 px slot; on is carried by THREE quiet signals
 *                at once (slot wash, frame colour, title colour) and never by a
 *                fill that swallows the tile.
 *   hairline   — never instantiated (PaperPanel's card draws nothing there
 *                anyway); the hairline branch uses PaperToggleRow.
 *
 * The status line always carries the real value — the SSID, the sink name and
 * volume — never the word "On". Colour already says on.
 */
PaperPanel {
    id: root

    property string icon: ""
    property string title: ""
    property string status: ""
    /// The subject is active.
    property bool on: false
    /// "Connected to something out there" — swaps `accent` for `link`.
    property bool connected: false
    property string tooltip: ""

    signal activated
    /// The secondary action. Used by the audio tile, whose primary click opens
    /// the output-device screen — mute has to stay one gesture away.
    signal rightActivated

    readonly property bool hovered: mouse.containsMouse
    readonly property color accentInk: root.connected ? PaperTheme.link : PaperTheme.accent
    readonly property real slotSize: PaperTheme.pick(24, 24, 28)

    kind: "card"
    floating: false
    implicitHeight: PaperTheme.pick(56, 42, 48)
    frameTone: root.on ? (root.connected ? "link" : "accent") : ""

    color: {
        if (root.on && PaperTheme.isLedger)
            return root.connected ? PaperTheme.linkWash : PaperTheme.accentWash;
        if (root.hovered)
            return PaperTheme.wash;
        return PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise;
    }

    // The icon slot / plate.
    Rectangle {
        id: slot
        anchors.left: parent.left
        anchors.leftMargin: PaperTheme.pick(8, 8, 9)
        anchors.verticalCenter: parent.verticalCenter
        width: root.slotSize
        height: root.slotSize
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        color: root.on ? (root.connected ? PaperTheme.linkWash : PaperTheme.accentWash) : "transparent"
        border.width: PaperTheme.ruleWidth
        border.color: root.on ? root.accentInk : PaperTheme.rule

        PaperIcon {
            anchors.centerIn: parent
            name: root.icon
            size: PaperTheme.icon.control
            color: root.on ? root.accentInk : PaperTheme.ink2
        }

        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    Column {
        anchors.left: slot.right
        anchors.leftMargin: PaperTheme.pick(9, 9, 9)
        anchors.right: parent.right
        anchors.rightMargin: PaperTheme.pick(8, 8, 9)
        anchors.verticalCenter: parent.verticalCenter
        spacing: PaperTheme.pick(2, 2, 1)

        PaperText {
            width: parent.width
            role: "small"
            text: root.title
            color: root.on ? root.accentInk : PaperTheme.ink
            font.weight: PaperTheme.font.weight.medium
            elide: Text.ElideRight
        }
        PaperText {
            width: parent.width
            visible: root.status !== ""
            role: "meta"
            text: root.status
            color: root.on ? (root.connected ? PaperTheme.link : PaperTheme.accentSoft) : PaperTheme.ink3
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                root.rightActivated();
            else
                root.activated();
        }

        PaperTooltip {
            text: root.tooltip
            anchorEdges: Edges.Left
            anchorGravity: Edges.Left
        }
    }
}
