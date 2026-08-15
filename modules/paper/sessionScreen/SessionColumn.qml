pragma ComponentBehavior: Bound

import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick

/**
 * Hairline's session choice — §4.9 of design/paper-a-hairline/SPEC.md.
 *
 * SURFACE-LOCAL: session-specific, not a shared composite. Prefixed `Session…`
 * per the surface-group convention.
 *
 * There is no tile here. The six choices are 120 px COLUMNS separated by
 * full-height 1 px vertical rules (drawn by the parent) — the only vertical
 * rules in the variant besides the bar dividers. Each column carries its number
 * accelerator in mono 10 at the top left, a 28 px glyph, and a micro-cap label
 * 22 px below it.
 *
 * The selection takes `ink` on the glyph and the label plus a 1 px underline
 * that grows from the left in 140 ms, and lifts the accelerator from `ink4` to
 * `ink2`. Nothing inverts, nothing fills, and total travel is 0 px.
 */
Item {
    id: root

    required property string glyph
    required property string label
    required property string accelerator
    property bool selected: false

    signal activated
    signal selectRequested

    /// 22 top pad + 28 glyph + 22 gap + label + 9 underline gap.
    readonly property int columnHeight: 96

    implicitWidth: PaperTheme.size.sessionTile
    implicitHeight: root.columnHeight

    // The accelerator — a line number in the margin.
    PaperText {
        id: accel
        x: 16
        y: 6
        role: "micro"
        mono: true
        font.letterSpacing: 0
        color: root.selected ? PaperTheme.ink2 : PaperTheme.ink4
        text: root.accelerator
    }

    PaperIcon {
        id: glyph
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22
        name: root.glyph
        size: PaperTheme.icon.session
        color: root.selected ? PaperTheme.ink : PaperTheme.ink2
    }

    PaperText {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        y: glyph.y + glyph.height + 22
        role: "micro"
        color: root.selected ? PaperTheme.ink : PaperTheme.ink3
        text: root.label
    }

    // The mark. It grows from the left, and it is the only thing that moves.
    Rectangle {
        id: mark
        x: caption.x
        y: caption.y + caption.implicitHeight + 9
        height: PaperTheme.markWidth
        width: root.selected ? caption.implicitWidth : 0
        color: PaperTheme.ink
        antialiasing: false
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
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.selectRequested()
        onClicked: root.activated()
    }
}
