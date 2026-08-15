import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * A bar hover popup. Structurally identical to `modules/pixel/bar/PixelBarPopup.qml`
 * (which is where the behaviour contract lives) — only the chrome changes.
 *
 * It is deliberately NOT a `PopupWindow`: it is a `LazyLoader` whose `active` is
 * bound straight to `hoverTarget.containsMouse`, and whose component is an
 * Overlay-layer `PanelWindow` hung `PaperTheme.barPopupOffset` from the top and
 * positioned by mapping the hover target's x into the bar window.
 *
 * The sheet is a floating `PaperPanel` (shadow in ledger/broadsheet, corner
 * ticks in broadsheet) padded by `PaperTheme.pad.sheet` — 20 / 12 / 14 px, which
 * is exactly what the three SPECs ask for.
 *
 *   BarPopup { hoverTarget: clockArea; BarClockPopup {} }
 *   BarPopup { hoverTarget: statsArea; alignLeft: true; BarSystemMonitorPopup {} }
 */
LazyLoader {
    id: root

    /// The hovered item. Must be a MouseArea (or anything with `containsMouse`).
    property Item hoverTarget
    /// Left-align the sheet with the target instead of centring under it.
    property bool alignLeft: false
    default property Item contentItem
    property int contentMargin: PaperTheme.pad.sheet

    active: root.hoverTarget && root.hoverTarget.containsMouse

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        // Follow the bar that owns the hover target, so the margins below are
        // measured against the same output the sheet lands on.
        screen: root.QsWindow?.window?.screen ?? null

        anchors.top: true
        anchors.left: true

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        // Click-through everywhere except over the sheet itself.
        mask: Region {
            item: panel
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        /// Where the sheet would like to sit: centred under the target (or
        /// left-aligned with it), in bar-window coordinates — which are screen
        /// coordinates, since the bar spans the full width of its screen.
        readonly property real wantedLeft: root.QsWindow?.mapFromItem(root.hoverTarget, root.alignLeft ? 0 : ((root.hoverTarget.width - panel.implicitWidth) / 2), 0).x ?? 0
        /// The bar's own content inset, reused as the screen-edge keep-out so a
        /// clamped sheet lines up with the cluster it hangs from.
        readonly property real edgeGap: PaperTheme.pad.bar
        readonly property real screenWidth: root.QsWindow?.window?.width ?? 0

        margins {
            // Clamp: the right-hand clusters (battery, clock) would otherwise
            // hang their centred sheet off the edge of the screen.
            left: popupWindow.screenWidth > 0 ? Math.max(popupWindow.edgeGap, Math.min(popupWindow.wantedLeft, popupWindow.screenWidth - panel.implicitWidth - popupWindow.edgeGap)) : popupWindow.wantedLeft
            top: PaperTheme.barPopupOffset
        }
        WlrLayershell.namespace: "quickshell:paperBarPopup"
        WlrLayershell.layer: WlrLayer.Overlay

        PaperPanel {
            id: panel
            anchors.fill: parent
            kind: "sheet"
            floating: true
            ticks: true
            implicitWidth: (root.contentItem?.implicitWidth ?? 0) + root.contentMargin * 2
            implicitHeight: (root.contentItem?.implicitHeight ?? 0) + root.contentMargin * 2

            children: [
                Item {
                    anchors.fill: parent
                    anchors.margins: root.contentMargin
                    children: root.contentItem ? [root.contentItem] : []
                }
            ]
        }
    }
}
