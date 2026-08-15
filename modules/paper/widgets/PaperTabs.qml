pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.paper.common

/**
 * A mode switcher. Two shapes, because the three SPECs genuinely disagree about
 * what a mode switcher IS:
 *
 *   orientation: "horizontal"  — micro-caps labels over ONE continuous
 *       hairline; the active tab owns the 1 px above it, drawn in `accent`
 *       (which is plain ink in hairline) and grown from the left in 140 ms.
 *       This is hairline's calendar switcher and the family's generic tab bar.
 *
 *   orientation: "vertical"    — a left stack of glyph-over-micro-cap mode
 *       buttons, 58 px wide. This is ledger's and broadsheet's calendar
 *       switcher. Each button is a PaperButton `stacked`, so the active one
 *       takes whatever "on" means in the variant (blue frame + wash in ledger,
 *       oxblood in broadsheet, an underline in hairline).
 *
 *   PaperTabs {
 *       width: parent.width
 *       orientation: PaperTheme.isHairline ? "horizontal" : "vertical"
 *       model: [
 *           { key: "calendar", label: "Calendar", icon: "calendar" },
 *           { key: "todo",     label: "To do",    icon: "todo" },
 *           { key: "timer",    label: "Timer",    icon: "timer" }
 *       ]
 *       current: view
 *       onSelected: key => view = key
 *   }
 *
 * `label` is required; `icon` is used by the vertical shape only; `tip` becomes
 * a left-anchored tooltip. Selection is the CALLER's state — the widget never
 * changes `current` itself.
 */
Item {
    id: root

    /// [{ key, label, icon?, tip? }, …]
    property var model: []
    /// The active `key`.
    property string current: ""
    /// horizontal | vertical
    property string orientation: "horizontal"
    /// Horizontal only: draw the continuous hairline the active mark sits on.
    property bool underline: true
    /// Vertical only.
    property real tabWidth: 58
    property real tabHeight: PaperTheme.pick(50, 46, 50)

    signal selected(string key)

    readonly property bool isVertical: root.orientation === "vertical"

    implicitWidth: root.isVertical ? root.tabWidth : strip.implicitWidth
    implicitHeight: root.isVertical ? stack.implicitHeight : strip.implicitHeight + PaperTheme.pick(7, 6, 6) + Math.max(PaperTheme.ruleWidth, PaperTheme.markWidth)

    // ---------------------------------------------------------- horizontal
    Row {
        id: strip
        visible: !root.isVertical
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: PaperTheme.pick(22, 18, 18)

        Repeater {
            model: root.isVertical ? [] : root.model

            delegate: Item {
                id: tab
                required property var modelData
                readonly property bool active: root.current === tab.modelData.key

                width: label.implicitWidth
                height: label.implicitHeight + PaperTheme.pick(7, 6, 6) + Math.max(PaperTheme.ruleWidth, PaperTheme.markWidth)

                PaperText {
                    id: label
                    anchors.left: parent.left
                    anchors.top: parent.top
                    role: "micro"
                    text: tab.modelData.label ?? ""
                    tone: tab.active ? "ink" : (tabMouse.containsMouse ? "ink2" : "ink3")
                }

                // The mark. It sits ON the continuous rule below, so the active
                // tab genuinely owns that px rather than drawing a second line.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    height: PaperTheme.markWidth
                    width: tab.active ? tab.width : 0
                    color: PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent
                    antialiasing: false
                    z: 1

                    Behavior on width {
                        NumberAnimation {
                            duration: PaperTheme.motion.base
                            easing.type: PaperTheme.motion.type
                            easing.bezierCurve: PaperTheme.motion.bezierCurve
                        }
                    }
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(tab.modelData.key)

                    PaperTooltip {
                        text: tab.modelData.tip ?? ""
                    }
                }
            }
        }
    }

    PaperRule {
        visible: !root.isVertical && root.underline
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(0, PaperTheme.markWidth - PaperTheme.ruleWidth)
    }

    // ------------------------------------------------------------ vertical
    Column {
        id: stack
        visible: root.isVertical
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: PaperTheme.gap.tile

        Repeater {
            model: root.isVertical ? root.model : []

            delegate: PaperButton {
                id: modeButton
                required property var modelData

                width: root.tabWidth
                implicitWidth: root.tabWidth
                implicitHeight: root.tabHeight
                shape: "stacked"
                icon: modeButton.modelData.icon ?? ""
                label: modeButton.modelData.label ?? ""
                checked: root.current === modeButton.modelData.key
                onClicked: root.selected(modeButton.modelData.key)

                PaperTooltip {
                    text: modeButton.modelData.tip ?? ""
                    anchorEdges: Edges.Left
                    anchorGravity: Edges.Left
                }
            }
        }
    }
}
