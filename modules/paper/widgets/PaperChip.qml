pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.paper.common

/**
 * A chip — one member of a set you pick from: a connected output, a vitulina
 * server, a zoom step, a "+ NAME" shortcut. Unlike PaperButton (a verb), a chip
 * is a NOUN, and a row of them is a choice.
 *
 *   hairline   — no bounds at all: micro-caps type, `ink-3` at rest, `ink` with
 *                a 1 px ink underline when picked, `ink-4` with no rule when
 *                impossible. A chip row in hairline is a line of words.
 *   ledger     — 20 tall, 1 px `rule`, radius 2, 10 px caps. Picked takes the
 *                blue treatment (blue frame, blue wash, blue ink) plus an
 *                optional blue tick.
 *   broadsheet — 24 tall, `paperSunk` fill, 1 px `rule`, letterspaced caps.
 *                Picked is oxblood ink over `accentWash`; an impossible chip is
 *                DOTTED-framed rather than dimmed.
 *
 *   PaperChip { label: "DP-1"; checked: target === "DP-1"
 *               onClicked: Monitors.setQuick("single", "DP-1") }
 *   PaperChip { label: "1.5×"; checked: scale === "1.5"; enabled: fits }
 *   PaperChip { label: "+ eDP-1"; onClicked: addRequired() }
 *
 * `tick: true` adds the ledger check inside a picked chip (server chips). Use
 * the inherited `enabled` for an impossible option — the widget draws the
 * variant's own "not available" mark rather than an opacity drop.
 */
Item {
    id: root

    property string label: ""
    /// Picked / on.
    property bool checked: false
    /// Draw a check glyph inside a picked chip (ledger's tick).
    property bool tick: false
    /// Set the label in the mono face (connector names, zoom steps).
    property bool mono: false
    /// "connected to something out there" — uses the `link` ink.
    property bool connected: false
    /// A chip you cannot pick: a resting field hint (the launcher's `⏎`), a
    /// status marker. It keeps the variant's chip BODY — which is the point,
    /// the hint has to look like the thing you would press — but takes no
    /// hover, no cursor and no click. Distinct from `enabled: false`, which
    /// says "this option exists and is impossible" and draws the variant's
    /// own not-available mark.
    property bool interactive: true

    signal clicked

    readonly property bool hovered: mouse.containsMouse && root.enabled && root.interactive
    readonly property bool pressed: mouse.containsPress && root.enabled
    readonly property bool framed: PaperTheme.ornament.framedControls
    readonly property color onInk: root.connected ? PaperTheme.link : PaperTheme.accent

    /// Bind any child you add to this.
    readonly property color contentColor: !root.enabled ? PaperTheme.ink4 : root.checked ? (PaperTheme.isHairline ? PaperTheme.ink : root.onInk) : root.hovered ? PaperTheme.ink : (PaperTheme.isHairline ? PaperTheme.ink3 : PaperTheme.ink2)

    readonly property int padH: root.framed ? PaperTheme.pick(0, 9, 10) : 0

    implicitWidth: content.implicitWidth + 2 * root.padH
    implicitHeight: root.framed ? PaperTheme.size.chip : Math.max(18, content.implicitHeight)

    // The chip body — absent in hairline.
    Rectangle {
        anchors.fill: parent
        visible: root.framed && root.enabled
        color: root.checked ? (root.connected ? PaperTheme.linkWash : PaperTheme.accentWash) : root.pressed ? PaperTheme.paperEdge : root.hovered ? PaperTheme.wash : (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise)
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        border.width: PaperTheme.ruleWidth
        border.color: root.checked ? root.onInk : root.hovered ? PaperTheme.rule2 : PaperTheme.rule
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

    // An impossible chip: dotted frame in broadsheet, a plain hairline frame at
    // 35 % in ledger, nothing at all in hairline (the label alone carries it).
    Rectangle {
        anchors.fill: parent
        visible: root.framed && !root.enabled && !PaperTheme.ornament.dottedDisabled
        color: "transparent"
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        opacity: 0.35
        border.width: PaperTheme.ruleWidth
        border.color: PaperTheme.rule
    }
    Repeater {
        model: (root.framed && !root.enabled && PaperTheme.ornament.dottedDisabled) ? 4 : 0
        delegate: PaperRule {
            required property int index
            readonly property bool sideways: index >= 2

            dotted: true
            tone: "ink4"
            vertical: sideways
            length: sideways ? root.height : root.width
            x: index === 3 ? root.width - PaperTheme.ruleWidth : 0
            y: index === 1 ? root.height - PaperTheme.ruleWidth : 0
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: PaperTheme.gap.icon

        PaperIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.tick && root.checked && !PaperTheme.isHairline
            name: "check"
            size: PaperTheme.icon.tiny
            color: root.contentColor
        }
        PaperText {
            id: text
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            role: "micro"
            mono: root.mono
            color: root.contentColor
        }
    }

    // Hairline's whole state vocabulary: a 1 px rule under the word.
    Rectangle {
        id: underline
        visible: PaperTheme.isHairline && root.enabled && (root.checked || root.hovered)
        height: root.checked ? PaperTheme.markWidth : PaperTheme.ruleWidth
        color: root.checked ? PaperTheme.ink : PaperTheme.rule2
        antialiasing: false
        x: Math.round((root.width - content.implicitWidth) / 2)
        y: Math.round((root.height + content.implicitHeight) / 2) + 4
        width: content.implicitWidth * (underline.visible ? 1 : 0)
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
        enabled: root.enabled && root.interactive
        hoverEnabled: true
        cursorShape: (root.enabled && root.interactive) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
