import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Hover popup for the pixel bar, modeled on the ii `StyledPopup` but drawn as a
 * monochrome `PixPanel` (3px hard border, no shadow). Shown while `hoverTarget`
 * is hovered. The popup hangs from the bottom edge of the bar, horizontally
 * centered under the hover target.
 *
 * Put the popup content as the default child; its implicit size drives the
 * panel size (plus `contentMargin` padding on every side).
 */
LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property int contentMargin: 14

    active: hoverTarget && hoverTarget.containsMouse

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        anchors.top: true
        anchors.left: true

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        mask: Region {
            item: panel
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: root.QsWindow?.mapFromItem(
                root.hoverTarget,
                (root.hoverTarget.width - panel.implicitWidth) / 2, 0
            ).x ?? 0
            top: PixTheme.barHeight
        }
        WlrLayershell.namespace: "quickshell:pixelBarPopup"
        WlrLayershell.layer: WlrLayer.Overlay

        PixPanel {
            id: panel
            anchors.fill: parent
            borderWidth: PixTheme.popupBorderWidth
            implicitWidth: (root.contentItem?.implicitWidth ?? 0) + root.contentMargin * 2
            implicitHeight: (root.contentItem?.implicitHeight ?? 0) + root.contentMargin * 2

            // Inset the slotted content from the border on every side so it
            // never sits flush against the 3px edge.
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
