pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A monochrome pixel hover hint. Place it as a CHILD of the control you want a
 * tooltip on; it anchors to its parent and escapes the parent window via a
 * PopupWindow (works for both the bar and the sidebar).
 *
 * Usage:
 *   PixControlButton { ... PixTooltip { text: "Fullscreen" } }
 *   PixButton        { ... PixTooltip { text: "Settings" } }   // PixButton has `hovered`
 *
 * The default visibility follows the parent's `containsMouse` (MouseArea) or
 * `hovered` (PixButton). Override `visibleCondition` for anything else. Set
 * `anchorEdges`/`anchorGravity` to Edges.Left for right-edge (sidebar) controls.
 */
Item {
    id: root
    property string text: ""
    property bool visibleCondition: (parent?.containsMouse ?? parent?.hovered ?? false)
    property var anchorEdges: Edges.Bottom
    property var anchorGravity: Edges.Bottom
    property int showDelay: 350

    anchors.fill: parent

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: tooltipLoader.active = true
    }
    onVisibleConditionChanged: {
        if (root.visibleCondition && root.text.length > 0)
            showTimer.restart();
        else {
            showTimer.stop();
            tooltipLoader.active = false;
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: PopupWindow {
            id: popup
            visible: true
            anchor {
                window: root.QsWindow.window
                item: root.parent
                edges: root.anchorEdges
                gravity: root.anchorGravity
                margins {
                    top: 4
                    bottom: 4
                    left: 6
                    right: 6
                }
            }
            mask: Region { item: null } // click-through
            color: "transparent"
            implicitWidth: label.implicitWidth + 16
            implicitHeight: label.implicitHeight + 8

            PixPanel {
                anchors.fill: parent
                borderWidth: PixTheme.borderWidth
                PixText {
                    id: label
                    anchors.centerIn: parent
                    text: root.text
                    font.pixelSize: PixTheme.font.pixelSize.small
                }
            }
        }
    }
}
