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

    // Gap between the anchor edge and the tooltip. Large enough that the popup
    // never maps directly under the cursor (which would otherwise steal hover
    // from the parent and make the tooltip flicker on/off).
    readonly property int gap: 14

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: tooltipLoader.active = true
    }
    // Hysteresis: once shown, a brief un-hover does NOT immediately hide. This
    // debounces the transient hover loss that can happen as the popup maps.
    Timer {
        id: hideTimer
        interval: 120
        onTriggered: tooltipLoader.active = false
    }
    onVisibleConditionChanged: {
        if (root.visibleCondition && root.text.length > 0) {
            hideTimer.stop();
            if (!tooltipLoader.active)
                showTimer.restart();
        } else {
            showTimer.stop();
            // Debounce the hide so a momentary hover blip keeps it shown.
            if (tooltipLoader.active)
                hideTimer.restart();
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
                    top: root.gap
                    bottom: root.gap
                    left: root.gap
                    right: root.gap
                }
            }
            // Empty input region → fully click/hover-through, so the popup can
            // never steal hover from the parent control underneath.
            mask: Region { item: null }
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
