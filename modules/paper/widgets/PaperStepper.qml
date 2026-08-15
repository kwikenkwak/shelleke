pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.paper.common

/**
 * A labelled integer stepper: a label (and an optional help footnote) on the
 * left, `[−] value [+]` on the right.
 *
 *   hairline   — the two signs are bare icon buttons with no bounds and the
 *                value is a mono numeral between them; nothing is boxed.
 *   ledger     — the three parts SHARE their hairlines so the control reads as
 *                one ruled object, exactly like a ledger's tally box.
 *   broadsheet — the same shared frame, with the value in Pagella oldstyle
 *                figures.
 *
 *   PaperStepper {
 *       width: parent.width
 *       label: "Name match"; help: "exact connector name (eDP-1)"
 *       value: scName; onChanged: v => scName = v
 *   }
 *   PaperStepper { label: "Timeout (ms)"; value: t; from: 0; to: 60000; step: 1000 }
 *
 * The caller owns the value — `changed(v)` carries the clamped new value and the
 * widget does not mutate `value` itself, because most of these round-trip
 * through a service before they are true.
 */
Item {
    id: root

    property string label: ""
    /// A footnote under the label explaining what the weight does.
    property string help: ""
    property int value: 0
    property int from: 0
    property int to: 999999
    property int step: 1

    /// The clamped new value.
    signal changed(int v)

    readonly property real boxSize: PaperTheme.pick(24, 26, 28)
    readonly property real valueWidth: PaperTheme.pick(44, 46, 50)
    readonly property bool framed: PaperTheme.ornament.framedControls

    implicitWidth: 260
    implicitHeight: Math.max(labels.implicitHeight, root.boxSize)

    /// One of the two signs. Shares the tally box's hairlines rather than
    /// drawing its own frame, which is what makes the stepper read as a single
    /// ruled object in ledger and broadsheet.
    component Sign: Item {
        id: sign
        property string glyph: "minus"
        property bool atRight: false
        signal activated

        width: root.boxSize
        height: root.boxSize

        Rectangle {
            anchors.fill: parent
            visible: root.framed && signMouse.containsMouse && sign.enabled
            color: PaperTheme.wash
        }
        PaperRule {
            visible: root.framed
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: sign.atRight ? parent.left : undefined
            anchors.right: sign.atRight ? undefined : parent.right
            vertical: true
        }
        PaperIcon {
            anchors.centerIn: parent
            name: sign.glyph
            size: PaperTheme.icon.row
            color: !sign.enabled ? PaperTheme.ink4 : signMouse.containsMouse ? PaperTheme.ink : PaperTheme.ink2
        }
        MouseArea {
            id: signMouse
            anchors.fill: parent
            enabled: sign.enabled
            hoverEnabled: true
            cursorShape: sign.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: sign.activated()
        }
    }

    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: box.left
        anchors.rightMargin: PaperTheme.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        PaperText {
            width: parent.width
            text: root.label
            role: "small"
            tone: "ink"
            elide: Text.ElideRight
        }
        PaperText {
            width: parent.width
            visible: root.help !== ""
            text: root.help
            role: "meta"
            tone: "ink4"
            footnote: true
            wrapMode: Text.WordWrap
        }
    }

    // The tally box: one frame around all three parts, divided by hairlines.
    Item {
        id: box
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 2 * root.boxSize + root.valueWidth
        height: root.boxSize

        Rectangle {
            anchors.fill: parent
            visible: root.framed
            color: "transparent"
            radius: PaperTheme.radiusControl
            antialiasing: radius > 0
            border.width: PaperTheme.ruleWidth
            border.color: PaperTheme.rule
        }

        Sign {
            id: minus
            x: 0
            glyph: "minus"
            enabled: root.enabled && root.value > root.from
            onActivated: root.changed(Math.max(root.from, root.value - root.step))
        }

        PaperText {
            x: root.boxSize
            width: root.valueWidth
            height: parent.height
            text: String(root.value)
            role: "small"
            figure: true
            tone: "ink"
            horizontalAlignment: Text.AlignHCenter
        }

        Sign {
            x: root.boxSize + root.valueWidth
            glyph: "plus"
            atRight: true
            enabled: root.enabled && root.value < root.to
            onActivated: root.changed(Math.min(root.to, root.value + root.step))
        }
    }
}
