pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.paper.common

/**
 * A segmented selector — pick exactly one of a small, fixed set. Replaces
 * PixSegment's row of filled squares.
 *
 *   hairline   — no frame and no cells: the options are plain micro-caps type
 *                spread across the width, and the current one is `ink` with a
 *                1 px ink underline that grows from the left in 140 ms.
 *                An impossible option drops to `ink-4` and loses its rule.
 *   ledger     — ONE 1 px `rule` frame (radius 2) divided by hairlines into
 *                equal cells; the current cell takes blue ink, a blue wash and
 *                a 2 px blue underline inside the frame. Invalid cells drop to
 *                35 % and stop responding.
 *   broadsheet — the same single frame with hairline dividers; the current cell
 *                is washed and lettered in oxblood, with the accent underline.
 *                Impossible cells take a DOTTED rule rather than an opacity
 *                drop (`ornament.dottedDisabled`).
 *
 * Nothing slides: the mark is redrawn under the new cell, never animated across
 * (the family's 4 px travel ceiling).
 *
 *   PaperSegment {
 *       width: parent.width
 *       options: [{ label: "Template", value: "template" },
 *                 { label: "Static",   value: "static"   }]
 *       value: configType
 *       onPicked: v => configType = v
 *   }
 *
 * `options` is a list of `{ label, value }`; add `enabled: false` to an entry to
 * mark it impossible (a zoom step that would not divide the resolution into
 * whole logical pixels). `equal: false` sizes each cell to its own label instead
 * of dividing the width evenly.
 */
Item {
    id: root

    /// [{ label: string, value: var, enabled: bool? }]
    property var options: []
    /// The currently selected `value`. Compared with ===.
    property var value
    /// Equal-width cells (the default) vs. cells sized to their labels.
    property bool equal: true
    /// Cell height. Defaults to the variant's control height.
    property real cellHeight: PaperTheme.pick(24, PaperTheme.size.button, PaperTheme.size.button)
    /// Set the labels in the mono face (regex flags, zoom steps).
    property bool mono: false

    /// Emitted with the picked option's `value`.
    signal picked(var value)

    readonly property bool framed: PaperTheme.ornament.framedControls
    readonly property int count: root.options.length

    implicitWidth: row.implicitWidth + (root.framed ? 2 * PaperTheme.ruleWidth : 0)
    implicitHeight: root.cellHeight

    // The single frame that holds every cell — ledger and broadsheet only.
    Rectangle {
        anchors.fill: parent
        visible: root.framed
        color: "transparent"
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        border.width: PaperTheme.ruleWidth
        border.color: PaperTheme.rule
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: root.framed ? PaperTheme.ruleWidth : 0
        spacing: 0

        Repeater {
            model: root.options

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool selected: root.value === cell.modelData.value
                readonly property bool usable: cell.modelData.enabled === undefined || cell.modelData.enabled
                readonly property bool hovered: cellMouse.containsMouse && cell.usable

                width: root.equal ? Math.floor(row.width / Math.max(1, root.count)) + (cell.index === root.count - 1 ? row.width - Math.floor(row.width / Math.max(1, root.count)) * root.count : 0) : label.implicitWidth + 2 * PaperTheme.pick(10, 9, 10)
                height: row.height

                // Ledger/broadsheet drop an impossible cell to 35 %; broadsheet
                // says so with a dotted rule instead (see below), so it keeps
                // its ink.
                opacity: cell.usable ? 1 : (PaperTheme.ornament.dottedDisabled ? 1 : PaperTheme.pick(1, 0.35, 1))

                // Cell ground: the wash under the current cell, the hover wash
                // under the pointer. Hairline has neither.
                Rectangle {
                    anchors.fill: parent
                    visible: root.framed
                    color: !cell.usable ? "transparent" : cell.selected ? PaperTheme.accentWash : cell.hovered ? PaperTheme.wash : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: PaperTheme.motion.fast
                            easing.type: PaperTheme.motion.type
                            easing.bezierCurve: PaperTheme.motion.bezierCurve
                        }
                    }
                }

                // The divider between cells — part of the single frame, so it is
                // drawn on every cell but the first.
                PaperRule {
                    visible: root.framed && cell.index > 0
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    vertical: true
                }

                PaperText {
                    id: label
                    anchors.centerIn: parent
                    text: cell.modelData.label ?? ""
                    role: "micro"
                    mono: root.mono
                    color: !cell.usable ? PaperTheme.ink4 : cell.selected ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : cell.hovered ? PaperTheme.ink : PaperTheme.ink2
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, cell.width - 4)
                    horizontalAlignment: Text.AlignHCenter
                }

                // The selection mark. Inside the frame where there is one; under
                // the label where there is not.
                Rectangle {
                    id: mark
                    visible: cell.usable && (cell.selected || (PaperTheme.isHairline && cell.hovered))
                    height: cell.selected ? PaperTheme.markWidth : PaperTheme.ruleWidth
                    color: cell.selected ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : PaperTheme.rule2
                    antialiasing: false
                    x: root.framed ? 0 : Math.round((cell.width - label.implicitWidth) / 2)
                    y: root.framed ? cell.height - height : Math.round((cell.height + label.implicitHeight) / 2) + PaperTheme.pick(5, 4, 4)
                    width: (root.framed ? cell.width : label.implicitWidth) * (mark.visible ? 1 : 0)
                    transformOrigin: Item.Left
                    Behavior on width {
                        NumberAnimation {
                            duration: PaperTheme.motion.base
                            easing.type: PaperTheme.motion.type
                            easing.bezierCurve: PaperTheme.motion.bezierCurve
                        }
                    }
                }

                // Broadsheet's disabled treatment: a dotted rule where the mark
                // would be, never an opacity drop.
                PaperRule {
                    visible: !cell.usable && PaperTheme.ornament.dottedDisabled
                    dotted: true
                    tone: "ink4"
                    length: cell.width - 8
                    x: 4
                    y: cell.height - PaperTheme.ruleWidth - 1
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    enabled: cell.usable && root.enabled
                    hoverEnabled: true
                    cursorShape: cell.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.picked(cell.modelData.value)
                }
            }
        }
    }
}
