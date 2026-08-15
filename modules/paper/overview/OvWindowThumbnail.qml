pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * A single live window thumbnail inside the workspace exposé.
 *
 * The capture and geometry mechanism is copied VERBATIM from
 * modules/pixel/overview/PixelOverviewWindow.qml (itself the ii original):
 * the same widthRatio / heightRatio transform maths, the same initX / initY
 * against the widget monitor's reserved area, and — critically — the same
 * `captureSource: GlobalStates.overviewOpen ? toplevel : null` gate. Binding it
 * unconditionally captures every window on the system forever.
 *
 * Only the chrome changes. Every variant frames the capture in a 1 px `rule-2`
 * hairline over an opaque paper ground and overprints the app icon (through
 * PaperAppIcon, so no app contributes colour) plus — in A and B — the window
 * title in micro-caps beneath it, so a workspace whose captures have not
 * arrived yet still reads as a list of what is open.
 */
Item {
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

    /// C halftones the icon a little smaller (36 % of the shorter side); A and
    /// B keep the pixel family's 40 %.
    property real iconToWindowRatio: PaperTheme.pick(0.40, 0.40, 0.36)
    property real iconToWindowRatioCompact: 0.7
    property string iconName: AppSearch.guessIcon(windowData?.class)
    /// Too small to carry both an icon and a caption.
    property bool compactMode: PaperTheme.font.size.micro * 4 > targetWindowHeight || PaperTheme.font.size.micro * 4 > targetWindowWidth

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    // Windows living on another monitor step back rather than disappear.
    opacity: windowData?.monitor == widgetMonitorId ? 1 : PaperTheme.pick(0.4, 0.42, 0.45)

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: GlobalStates.overviewOpen ? root.toplevel : null
        live: true

        // An opaque paper ground BEHIND the capture, so an unrendered thumbnail
        // is a blank sheet with a caption rather than a hole in the page.
        Rectangle {
            anchors.fill: parent
            z: -1
            color: PaperTheme.paper
            antialiasing: false
        }

        // The frame + hover wash. The frame weight never changes, only its
        // colour, so nothing shifts by a pixel under the pointer.
        Rectangle {
            anchors.fill: parent
            color: (root.hovered || root.pressed) ? (PaperTheme.isLedger ? PaperTheme.paperSunk : PaperTheme.wash) : "transparent"
            opacity: (root.hovered || root.pressed) ? (root.pressed ? 0.55 : 0.35) : 0
            radius: PaperTheme.radiusCard
            antialiasing: radius > 0
            border.width: PaperTheme.ruleWidth
            border.color: (root.hovered || root.pressed) ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : PaperTheme.rule2
            Behavior on border.color {
                ColorAnimation {
                    duration: PaperTheme.motion.base
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: PaperTheme.motion.fast
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }
        }

        // Overprinted identity: the app icon, and (A/B) the window title.
        Column {
            anchors.centerIn: parent
            spacing: PaperTheme.pick(7, 5, 0)

            PaperAppIcon {
                id: windowIcon
                anchors.horizontalCenter: parent.horizontalCenter
                property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
                size: Math.max(8, windowIcon.baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio))
                icon: root.iconName
                // The thumbnail already is the plate; no second frame.
                plate: false
                fallbackIcon: "square"
            }

            PaperText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !PaperTheme.isBroadsheet && !root.compactMode
                width: Math.max(0, root.width - PaperTheme.spacing.medium)
                horizontalAlignment: Text.AlignHCenter
                text: root.windowData?.title ?? ""
                role: "micro"
                elide: Text.ElideRight
                // Deliberately off-scale: a caption on a 60 px tall thumbnail.
                font.pixelSize: PaperTheme.pick(8.5, 9, 9)
                font.letterSpacing: PaperTheme.tracking(0.10, PaperTheme.pick(8.5, 9, 9))
                font.capitalization: PaperTheme.isLedger ? Font.MixedCase : Font.AllUppercase
            }
        }
    }
}
