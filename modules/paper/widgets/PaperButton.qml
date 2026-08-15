import QtQuick
import qs.modules.paper.common

/**
 * A button. Replaces PixButton, whose only idiom was "filled square = on".
 *
 * One API, three visual languages:
 *   hairline   — there is no box and no fill. A button IS its label. Rest
 *                `ink-2`; hover gains a `rule-2` underline; active/primary is
 *                `ink` with an ink underline; disabled drops to `ink-4` and
 *                loses the rule, so "not yet" reads as "not yet underlined".
 *   ledger     — 26 tall, 1 px `rule`, radius 2. rest → hover (`paperSunk`) →
 *                press (`paperEdge`); `checked` = blue frame + blue ink + blue
 *                wash; `primary` = filled blue with `onAccent` (at most ONE per
 *                surface); `destructive` = red ink, red wash on hover only.
 *   broadsheet — 30 tall, `paperSunk` fill, 1 px `rule`, radius 2, and a 1 px
 *                accent underline drawn INSIDE the frame on hover. The frame
 *                weight never changes, only its colour, so nothing shifts by a
 *                pixel under the pointer. `primary` = solid `ink`.
 *
 * Shapes: "caps" (letterspaced micro-caps — dialog actions, section actions),
 * "text" (12 px inline actions), "icon" (a glyph with no bounds, 24–26 px hit
 * area), "stacked" (glyph over a micro-cap: quick-layout, calendar and session
 * mode buttons).
 *
 *   PaperButton { label: "Validate"; onClicked: Monitors.validate() }
 *   PaperButton { shape: "icon"; icon: "refresh"; PaperTooltip { text: "Refresh" } }
 *   PaperButton { label: "Create"; primary: true; enabled: valid }
 *   PaperButton { label: "Remove"; destructive: true }
 *   PaperButton { shape: "stacked"; icon: "nodes"; label: "Extend"; checked: true }
 *
 * Read `contentColor` from any child you add yourself so it tracks the state.
 */
Item {
    id: root

    /// caps | text | icon | stacked
    property string shape: "caps"
    property string label: ""
    property string icon: ""
    property real iconSize: root.shape === "stacked" ? PaperTheme.icon.control : PaperTheme.icon.control
    /// Selected / on.
    property bool checked: false
    /// The single committing action on this surface (Save, Create). Filled.
    property bool primary: false
    /// A destructive verb (Remove, Clear all).
    property bool destructive: false
    /// The state means "connected to something outside the machine" — uses the
    /// `link` ink, which only differs from `accent` in broadsheet.
    property bool connected: false
    /// Disabled state uses the inherited Item.enabled — set `enabled: false`.
    /// A frameless button even in ledger/broadsheet (a "ghost" header button).
    property bool ghost: root.shape === "icon" || root.shape === "text"

    signal clicked
    signal rightClicked

    readonly property bool hovered: mouse.containsMouse && root.enabled
    readonly property bool pressed: mouse.containsPress && root.enabled
    readonly property bool active: root.checked || root.primary
    readonly property bool framed: PaperTheme.ornament.framedControls && !root.ghost

    readonly property color accentInk: root.connected ? PaperTheme.link : PaperTheme.accent

    /// Bind children's colour to this.
    readonly property color contentColor: !root.enabled ? PaperTheme.ink4 : root.primary ? PaperTheme.onAccent : root.destructive ? PaperTheme.alert : root.checked ? root.accentInk : root.hovered ? PaperTheme.ink : PaperTheme.ink2

    readonly property color fillColor: {
        if (!root.framed)
            return "transparent";
        if (!root.enabled)
            return "transparent";
        if (root.primary)
            return PaperTheme.isBroadsheet && !root.destructive ? PaperTheme.ink : root.accentInk;
        if (root.destructive)
            return root.hovered ? PaperTheme.alertWash : (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise);
        if (root.checked)
            return root.connected ? PaperTheme.linkWash : PaperTheme.accentWash;
        if (root.pressed)
            return PaperTheme.paperEdge;
        if (root.hovered)
            return PaperTheme.wash;
        return PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise;
    }

    readonly property color frameColor: {
        if (!root.enabled)
            return PaperTheme.rule;
        if (root.primary)
            return PaperTheme.isBroadsheet && !root.destructive ? PaperTheme.ink : root.accentInk;
        if (root.destructive)
            return root.hovered ? PaperTheme.alertSoft : PaperTheme.rule;
        if (root.checked)
            return root.accentInk;
        if (root.pressed)
            return PaperTheme.ink3;
        if (root.hovered)
            return PaperTheme.rule2;
        return PaperTheme.rule;
    }

    /// The underline: hairline's ONLY state device, broadsheet's hover mark.
    readonly property bool showUnderline: root.enabled && (PaperTheme.isHairline ? (root.active || root.hovered) : (PaperTheme.isBroadsheet && (root.hovered || root.active) && !root.primary))
    readonly property color underlineColor: root.destructive ? PaperTheme.alert : root.active ? (PaperTheme.isHairline ? PaperTheme.ink : root.accentInk) : PaperTheme.rule2

    implicitWidth: root.shape === "icon" ? PaperTheme.size.iconButton : root.shape === "stacked" ? Math.max(56, content.implicitWidth + 2 * padH) : content.implicitWidth + 2 * padH
    implicitHeight: root.shape === "icon" ? PaperTheme.size.iconButton : root.shape === "stacked" ? PaperTheme.pick(50, 50, 52) : (root.framed ? PaperTheme.size.button : Math.max(24, content.implicitHeight))

    readonly property int padH: root.framed ? PaperTheme.pick(0, 10, 10) : 0

    // Frame + fill. Absent entirely in hairline and for ghost buttons.
    Rectangle {
        anchors.fill: parent
        visible: root.framed
        color: root.fillColor
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        border.width: PaperTheme.ruleWidth
        border.color: root.frameColor
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // Content.
    Item {
        id: content
        anchors.centerIn: parent
        implicitWidth: root.shape === "stacked" ? Math.max(glyph.implicitWidth, text.implicitWidth) : (glyph.visible ? glyph.implicitWidth : 0) + (text.visible ? text.implicitWidth : 0) + ((glyph.visible && text.visible) ? PaperTheme.gap.icon : 0)
        implicitHeight: root.shape === "stacked" ? glyph.implicitHeight + 6 + text.implicitHeight : Math.max(glyph.visible ? glyph.implicitHeight : 0, text.implicitHeight)

        PaperIcon {
            id: glyph
            visible: root.icon !== ""
            name: root.icon
            size: root.iconSize
            color: root.contentColor
            x: root.shape === "stacked" ? (content.implicitWidth - width) / 2 : 0
            y: root.shape === "stacked" ? 0 : (content.implicitHeight - height) / 2
        }
        PaperText {
            id: text
            visible: root.label !== ""
            text: root.label
            role: root.shape === "text" ? "small" : "micro"
            color: root.contentColor
            x: root.shape === "stacked" ? (content.implicitWidth - implicitWidth) / 2 : (glyph.visible ? glyph.implicitWidth + PaperTheme.gap.icon : 0)
            y: root.shape === "stacked" ? glyph.implicitHeight + 6 : (content.implicitHeight - implicitHeight) / 2
        }
    }

    // The underline. It grows from its LEFT edge in 140 ms — the only animated
    // shape in hairline, and the reason "selected" never needs a fill.
    //
    // Unframed (hairline, and every ghost button) it tracks the CONTENT, not the
    // item: `content` is centred, so a button stretched wider than its label —
    // a full-width row action — must still underline the label rather than a
    // strip of empty paper starting at x = 0.
    Rectangle {
        id: underline
        visible: root.showUnderline
        height: root.active ? PaperTheme.markWidth : PaperTheme.ruleWidth
        color: root.underlineColor
        antialiasing: false
        x: root.framed ? PaperTheme.ruleWidth : content.x
        width: (root.framed ? root.width - 2 * PaperTheme.ruleWidth : content.implicitWidth) * (root.showUnderline ? 1 : 0)
        y: root.framed ? root.height - height - PaperTheme.ruleWidth : content.y + content.implicitHeight + PaperTheme.pick(5, 4, 4)
        transformOrigin: Item.Left
        Behavior on width {
            NumberAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
