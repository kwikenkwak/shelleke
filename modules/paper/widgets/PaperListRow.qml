import QtQuick
import Quickshell
import qs.modules.paper.common

/**
 * A row in a list: an optional state dot, an optional glyph, a title over a
 * status line, and whatever you put in the trailing slot.
 *
 *   PaperListRow {
 *       width: parent.width
 *       icon: "wifi"; title: net.ssid; subtitle: "Connected"
 *       on: net.active; connected: true
 *       separator: index > 0
 *       onActivated: Network.connectToWifiNetwork(net)
 *       PaperIcon { name: "lock"; size: 12; color: PaperTheme.ink4 }
 *   }
 *
 * Per variant, and this is the whole point of the widget:
 *   hairline   — no frame and no fill. Rows are separated by a hairline
 *                BETWEEN them, never boxed. Hover takes the 4 % `wash`;
 *                `selected` takes an 11 px left gutter with a 1 px ink rule.
 *                An "on" row is `ink`; the rest are `ink-2`.
 *   ledger     — the same skeleton with radius 2; `selected` takes the blue
 *                selection ground, a 2 px blue change bar and blue ink, so
 *                "connected" looks identical to "selected" anywhere else.
 *   broadsheet — hover adds a 2 px `rule-2` change bar as well as the wash;
 *                selection is the oxblood bar over the `selection` ground.
 *
 * `on` means "this row's subject is active" (a connected network, an enabled
 * toggle); `selected` means "this row is the current one". They render almost
 * identically on purpose — the family has one selection mark.
 *
 * Children land in the trailing slot. Use `tooltip` rather than parenting a
 * PaperTooltip yourself, or it will be anchored to the trailing row.
 */
Item {
    id: root

    /// Leading glyph. Empty draws nothing and reclaims the space.
    property string icon: ""
    property real iconSize: PaperTheme.icon.control
    property string title: ""
    property string subtitle: ""
    /// The row's subject is active / connected / enabled.
    property bool on: false
    /// The row is the current selection — draws the change bar.
    property bool selected: false
    /// "Connected to something out there" — swaps `accent` for `link`.
    property bool connected: false
    /// Reserve a 6 px leading dot column (hairline's connectivity marker).
    property bool dotColumn: false
    /// Fill that dot.
    property bool dotFilled: root.on
    /// A 1 px hairline ABOVE this row. Set `index > 0` from a delegate.
    property bool separator: false
    /// A non-clickable row (a header line inside a list).
    property bool interactive: true
    /// Minimum row height. Content taller than this wins.
    property real minHeight: PaperTheme.size.listRow
    /// Title type role — override for denser lists.
    property string titleRole: PaperTheme.pick("body", "small", "body")
    property string subtitleRole: "meta"
    /// Hover hint. Left-anchored by default: these rows live in a right sidebar.
    property string tooltip: ""

    signal activated
    signal rightActivated

    default property alias trailing: trailingRow.data

    readonly property bool hovered: mouse.containsMouse && root.interactive && root.enabled
    readonly property color accentInk: root.connected ? PaperTheme.link : PaperTheme.accent

    readonly property color titleColor: !root.enabled ? PaperTheme.ink4 : (root.on || root.selected) ? root.accentInk : (PaperTheme.isHairline ? PaperTheme.ink2 : PaperTheme.ink)
    readonly property color subtitleColor: !root.enabled ? PaperTheme.ink4 : ((root.on || root.selected) && !PaperTheme.isHairline) ? (root.connected ? PaperTheme.link : PaperTheme.accentSoft) : PaperTheme.ink3
    readonly property color glyphColor: !root.enabled ? PaperTheme.ink4 : (root.on || root.selected) ? root.accentInk : PaperTheme.ink3

    readonly property real padV: PaperTheme.pick(10, 8, 7)
    readonly property real padH: PaperTheme.pick(0, 8, 8)
    /// How far the change bar pushes the content. Animated rather than the
    /// anchor margin itself — Behaviors cannot be attached to grouped anchor
    /// properties.
    property real indent: root.selected ? PaperTheme.changeBarIndent : 0
    Behavior on indent {
        NumberAnimation {
            duration: PaperTheme.motion.base
            easing.type: PaperTheme.motion.type
            easing.bezierCurve: PaperTheme.motion.bezierCurve
        }
    }

    implicitWidth: 200
    implicitHeight: Math.max(root.minHeight, textColumn.implicitHeight + 2 * root.padV) + (root.separator ? PaperTheme.ruleWidth : 0)

    // The separator lives ABOVE the row — rules go between rows, never around
    // them. Hairline in particular never boxes a list.
    PaperRule {
        visible: root.separator
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Rectangle {
        id: ground
        anchors.fill: parent
        anchors.topMargin: root.separator ? PaperTheme.ruleWidth : 0
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        color: root.selected && !PaperTheme.isHairline ? PaperTheme.selection : root.hovered ? PaperTheme.wash : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // The change bar: the one selection mark the family owns. It grows from 0
    // in 140 ms and never travels further than its own width.
    Rectangle {
        id: changeBar
        anchors.left: ground.left
        anchors.top: ground.top
        anchors.bottom: ground.bottom
        anchors.topMargin: PaperTheme.isHairline ? root.padV - 2 : 0
        anchors.bottomMargin: anchors.topMargin
        width: root.selected ? PaperTheme.changeBarWidth : 0
        color: PaperTheme.isHairline ? PaperTheme.ink : root.accentInk
        antialiasing: false

        Behavior on width {
            NumberAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // Content.
    Item {
        id: content
        anchors.fill: ground
        anchors.leftMargin: root.padH + root.indent
        anchors.rightMargin: root.padH

        // 6 px state dot. Reserved on every row so the column does not jump
        // when the connected entry changes.
        Rectangle {
            id: stateDot
            visible: root.dotColumn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: PaperTheme.size.dot
            height: PaperTheme.size.dot
            radius: width / 2
            antialiasing: true
            color: root.dotFilled ? root.accentInk : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: PaperTheme.motion.base
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }
        }

        PaperIcon {
            id: glyph
            visible: root.icon !== ""
            anchors.left: root.dotColumn ? stateDot.right : parent.left
            anchors.leftMargin: root.dotColumn ? PaperTheme.pick(8, 6, 6) : 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: root.iconSize
            color: root.glyphColor
        }

        Column {
            id: textColumn
            anchors.left: glyph.visible ? glyph.right : (root.dotColumn ? stateDot.right : parent.left)
            anchors.leftMargin: (glyph.visible || root.dotColumn) ? PaperTheme.pick(13, 9, 10) : 0
            anchors.right: trailingRow.left
            anchors.rightMargin: trailingRow.width > 0 ? PaperTheme.pick(12, 8, 8) : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: PaperTheme.pick(2, 2, 1)

            PaperText {
                width: parent.width
                visible: root.title !== ""
                text: root.title
                role: root.titleRole
                color: root.titleColor
                font.weight: PaperTheme.isHairline ? PaperTheme.font.weight.normal : PaperTheme.font.weight.medium
                elide: Text.ElideRight
            }
            PaperText {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                role: root.subtitleRole
                color: root.subtitleColor
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailingRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: PaperTheme.gap.icon
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: ground
        enabled: root.interactive && root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
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
