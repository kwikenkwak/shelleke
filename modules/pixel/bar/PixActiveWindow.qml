import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Active window region: desaturated app icon + two-line label (app id in grey,
 * window title in bold fg). Falls back to a sparkle glyph + "Desktop" when no
 * window is focused. Bound to Hyprland's active toplevel via ToplevelManager.
 */
Item {
    id: root
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property bool hasWindow: activeWindow?.activated ?? false
    readonly property string appId: hasWindow ? (activeWindow?.appId ?? "") : ""
    readonly property string windowTitle: hasWindow ? (activeWindow?.title ?? "") : ""

    property int maxTitleWidth: 360

    implicitWidth: layout.implicitWidth
    implicitHeight: 32

    Row {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        // App icon (or sparkle fallback when nothing focused)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 21
            height: 21

            PixAppIcon {
                anchors.fill: parent
                visible: root.appId !== ""
                icon: AppSearch.guessIcon(root.appId)
                size: 21
            }
            PixIcon {
                anchors.centerIn: parent
                visible: root.appId === ""
                name: "sparkle"
                size: 18
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            PixText {
                text: root.hasWindow && root.appId !== "" ? root.appId : ""
                visible: text !== ""
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smallest
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.maxTitleWidth)
            }
            PixText {
                text: root.hasWindow && root.windowTitle !== "" ? root.windowTitle : "Desktop"
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.larger
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.maxTitleWidth)
            }
        }
    }
}
