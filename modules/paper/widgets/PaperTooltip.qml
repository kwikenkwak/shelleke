pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.paper.common

/**
 * A hover hint. Same behaviour as PixTooltip — one third of the chrome.
 *
 * Place it as a CHILD of the control you want a tooltip on; it anchors to its
 * parent and escapes the parent window through a PopupWindow, so it works from
 * the bar and from a sidebar alike.
 *
 *   PaperButton { shape: "icon"; icon: "gear"; PaperTooltip { text: "Settings" } }
 *   MouseArea   { hoverEnabled: true;          PaperTooltip { text: "Media controls" } }
 *
 * Visibility follows the parent's `containsMouse` (MouseArea) or `hovered`
 * (PaperButton / PaperSwitch); override `visibleCondition` for anything else.
 * Set `anchorEdges`/`anchorGravity` to Edges.Left for right-edge controls.
 *
 * Timings are identical to PixTooltip and to all three SPECs: 350 ms show
 * delay, 120 ms hide debounce. The popup uses an EMPTY input region, so it can
 * never steal hover from the control underneath — without that the tooltip
 * flickers on and off as it maps.
 *
 * The popup's anchor is CAPTURED once at creation and is never a live binding.
 * See the note on `anchorWindow` — that detail is the difference between a
 * tooltip and a shell that segfaults under the cursor.
 */
Item {
    id: root

    property string text: ""
    /// A second line, set in mono (a window class, a priority hint).
    property string subtext: ""
    property bool visibleCondition: (parent?.containsMouse ?? parent?.hovered ?? false)
    property var anchorEdges: Edges.Bottom
    property var anchorGravity: Edges.Bottom
    property int showDelay: PaperTheme.tooltip.showDelay

    anchors.fill: parent

    readonly property int gap: PaperTheme.tooltip.gap

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: tooltipLoader.active = true
    }
    // Hysteresis: once shown, a brief un-hover does NOT immediately hide.
    Timer {
        id: hideTimer
        interval: PaperTheme.tooltip.hideDebounce
        onTriggered: tooltipLoader.active = false
    }
    onVisibleConditionChanged: {
        if (root.visibleCondition && root.text.length > 0) {
            hideTimer.stop();
            if (!tooltipLoader.active)
                showTimer.restart();
        } else {
            showTimer.stop();
            if (tooltipLoader.active)
                hideTimer.restart();
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: PopupWindow {
            id: popup

            /// The anchor, SNAPSHOT at creation. Never bind these to
            /// `QsWindow.window` or to `parent` directly.
            ///
            /// `QsWindow.window` re-resolves on every `windowChanged` in the
            /// item tree it is attached to — including the ones Qt emits while
            /// it is TEARING THAT TREE DOWN: a config reload, or a ListView
            /// releasing the delegate this tooltip is parented to. Evaluating
            /// it then dereferences an item Qt has already begun destroying and
            /// segfaults inside QQuickItem::window(), taking the whole shell
            /// with it. It reproduced on the Bluetooth device list, whose rows
            /// re-sort the instant a device pairs, connects or is forgotten —
            /// exactly when a tooltip is open over the row being moved.
            ///
            /// A tooltip lives for a few seconds and never migrates between
            /// windows, so a snapshot is not a compromise; it is the correct
            /// lifetime. `var` rather than a typed `Item` on purpose: a typed
            /// reference would be nulled-and-notified mid-teardown, which is
            /// the binding churn this is here to avoid.
            property var anchorWindow: null
            property var anchorItem: null
            Component.onCompleted: {
                popup.anchorWindow = root.QsWindow.window;
                popup.anchorItem = root.parent;
            }

            visible: popup.anchorWindow !== null && popup.anchorItem !== null
            anchor {
                window: popup.anchorWindow
                item: popup.anchorItem
                edges: root.anchorEdges
                gravity: root.anchorGravity
                margins {
                    top: root.gap
                    bottom: root.gap
                    left: root.gap
                    right: root.gap
                }
            }
            // Empty input region → fully click/hover-through.
            mask: Region {
                item: null
            }
            color: "transparent"
            implicitWidth: column.implicitWidth + 2 * PaperTheme.pick(9, 8, 9)
            implicitHeight: column.implicitHeight + 2 * PaperTheme.pick(5, 4, 4)

            PaperPanel {
                anchors.fill: parent
                kind: "sheet"
                floating: true
                grain: false

                Column {
                    id: column
                    anchors.centerIn: parent
                    spacing: 2
                    PaperText {
                        text: root.text
                        role: "meta"
                        tone: "ink2"
                        footnote: PaperTheme.isBroadsheet
                    }
                    PaperText {
                        visible: root.subtext !== ""
                        text: root.subtext
                        role: "micro"
                        tone: "ink3"
                        mono: true
                        font.capitalization: Font.MixedCase
                        font.letterSpacing: 0
                    }
                }
            }
        }
    }
}
