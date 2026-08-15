import QtQuick
import qs.modules.paper.common

/**
 * The one meter in the family. Replaces the pixel theme's 20 discrete cells
 * everywhere: the OSD, media progress and seek, CPU/RAM in the system-monitor
 * popup, the Claude usage rows and the pomodoro phase.
 *
 *   hairline   — a 1 px `rule-2` track, a 1 px `ink` fill, and a 4 px HEAD DOT.
 *                The head is what makes a 1 px line readable at a glance, and
 *                it doubles as the seek handle.
 *   ledger     — a ruler: a 1 px `rule-2` track, a 3 px fill, a 1 px pin at the
 *                exact value, and 21 ticks below with every fifth taller. Ink
 *                when read-only, ink blue when draggable.
 *   broadsheet — a rule gauge: a hairline baseline in `rule-2`, ticks every 5 %
 *                (major, taller and darker, every 25 %), and a 4 px `ink` bar
 *                overprinted from the left. `alert` when the value is a warning
 *                or the subject is muted.
 *
 *   PaperMeter { value: volume; width: 200 }
 *   PaperMeter { value: pos / len; interactive: true; onSeek: v => player.position = v * len }
 *   PaperMeter { value: 0.9; alert: true }            // muted / critical
 *   PaperMeter { value: 0.4; dense: true }            // popup columns: 10 % ticks
 */
Item {
    id: root

    /// 0..1, clamped.
    property real value: 0
    /// Draggable / clickable to seek. Also switches ledger's fill to ink blue.
    property bool interactive: false
    /// A warning value, or a muted subject. Ledger/broadsheet colour the fill;
    /// a muted OSD should instead set `value: 0` and let the track read empty.
    property bool alert: false
    /// Fewer ticks, for narrow popup columns.
    property bool dense: false
    /// Suppress ticks even where the variant would draw them.
    property bool ticks: PaperTheme.ornament.meterTicks

    /// Fired on click or drag with the new 0..1 value.
    signal seek(real position)

    readonly property real clamped: Math.max(0, Math.min(1, root.value))
    readonly property color fillColor: root.alert ? PaperTheme.alert : (root.interactive && !PaperTheme.isHairline) ? PaperTheme.accent : PaperTheme.ink
    readonly property real fillThickness: PaperTheme.pick(PaperTheme.ruleWidth, 3, 4)
    readonly property int tickCount: root.dense ? 11 : 21

    implicitWidth: 160
    implicitHeight: root.ticks && !PaperTheme.isHairline ? 12 : 8

    // The track.
    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        y: PaperTheme.isHairline ? (root.height - height) / 2 : Math.round(root.height / 2) - height
        height: PaperTheme.ruleWidth
        color: PaperTheme.rule2
        antialiasing: false
    }

    // The fill, overprinted from the left.
    Rectangle {
        id: fill
        x: 0
        y: track.y - (root.fillThickness - PaperTheme.ruleWidth) / 2
        width: root.width * root.clamped
        height: root.fillThickness
        color: root.fillColor
        antialiasing: false
        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // Hairline: the 4 px head dot at the value.
    Rectangle {
        visible: PaperTheme.ornament.meterHead
        width: 4
        height: 4
        radius: 2
        antialiasing: true
        color: root.fillColor
        x: Math.max(0, Math.min(root.width - width, root.width * root.clamped - width / 2))
        y: track.y + PaperTheme.ruleWidth / 2 - height / 2
        Behavior on x {
            enabled: !drag.pressed
            NumberAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // Ledger: a 1 px upright pin at the exact value.
    Rectangle {
        visible: PaperTheme.isLedger
        width: PaperTheme.ruleWidth
        height: 7
        color: root.fillColor
        antialiasing: false
        x: Math.max(0, Math.min(root.width - width, root.width * root.clamped))
        y: track.y - 3
    }

    // Ledger / broadsheet: the scale.
    Repeater {
        model: root.ticks && !PaperTheme.isHairline ? root.tickCount : 0
        delegate: Rectangle {
            id: tick
            required property int index
            readonly property bool major: PaperTheme.isBroadsheet ? (tick.index % Math.max(1, Math.round((root.tickCount - 1) / 4)) === 0) : (tick.index % 5 === 0)
            width: PaperTheme.ruleWidth
            height: tick.major ? 5 : 3
            color: tick.major ? PaperTheme.rule2 : PaperTheme.rule
            antialiasing: false
            x: Math.round((root.width - PaperTheme.ruleWidth) * tick.index / (root.tickCount - 1))
            y: track.y + PaperTheme.ruleWidth + 2
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        function emitAt(x: real): void {
            root.seek(Math.max(0, Math.min(1, x / root.width)));
        }
        onPressed: mouseEvent => emitAt(mouseEvent.x)
        onPositionChanged: mouseEvent => {
            if (pressed)
                emitAt(mouseEvent.x);
        }
    }
}
