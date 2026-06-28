pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * A single live window thumbnail inside the overview workspace grid.
 *
 * The capture/positioning mechanism is copied verbatim from
 * `modules/ii/overview/OverviewWindow.qml`: a live `ScreencopyView` of the
 * toplevel, sized + offset against the widget monitor's geometry, with all the
 * same width/height ratio math. Only the chrome was restyled to the pixel
 * idiom: hard-edged (radius 0) borders, monochrome hover/press overlay, and the
 * overlaid app icon is a `PixAppIcon` (grayscale + pixelated) instead of a
 * colored `Image`.
 */
Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var scale
    property bool restrictToWorkspace: true
    property real widthRatio: {
        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale);
    }
    property real heightRatio: {
        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale);
    }
    property real initX: {
        return Math.max((windowData?.at[0] - (monitorData?.x ?? 0) - monitorData?.reserved[0]) * widthRatio * root.scale, 0) + xOffset;
    }
    property real initY: {
        return Math.max((windowData?.at[1] - (monitorData?.y ?? 0) - monitorData?.reserved[1]) * heightRatio * root.scale, 0) + yOffset;
    }
    property real xOffset: 0
    property real yOffset: 0
    property var widgetMonitor
    property int widgetMonitorId: widgetMonitor.id

    property var targetWindowWidth: windowData?.size[0] * scale * widthRatio
    property var targetWindowHeight: windowData?.size[1] * scale * heightRatio
    property bool hovered: false
    property bool pressed: false

    property real iconToWindowRatio: 0.4
    property real iconToWindowRatioCompact: 0.7
    property string iconName: AppSearch.guessIcon(windowData?.class)
    property bool compactMode: PixTheme.font.pixelSize.smaller * 4 > targetWindowHeight
        || PixTheme.font.pixelSize.smaller * 4 > targetWindowWidth

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: windowData?.monitor == widgetMonitorId ? 1 : 0.4

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: GlobalStates.overviewOpen ? root.toplevel : null
        live: true

        // Hard-edged monochrome border + interaction overlay (no rounding).
        Rectangle {
            anchors.fill: parent
            radius: 0
            antialiasing: false
            color: root.pressed ? Qt.rgba(PixTheme.colors.line.r, PixTheme.colors.line.g, PixTheme.colors.line.b, 0.30)
                : root.hovered ? Qt.rgba(PixTheme.colors.line.r, PixTheme.colors.line.g, PixTheme.colors.line.b, 0.12)
                : "transparent"
            border.width: root.hovered || root.pressed ? PixTheme.borderWidth : 1
            border.color: PixTheme.colors.line
        }

        PixAppIcon {
            id: windowIcon
            property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
            anchors.centerIn: parent
            size: Math.max(8, baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio))
            icon: root.iconName
            pixelResolution: 16
        }
    }
}
