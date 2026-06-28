import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.modules.pixel.common

/**
 * App icon rendered to match the pixel aesthetic: decoded at a low resolution
 * and upscaled with nearest-neighbor (chunky pixels), then fully desaturated so
 * there is NO color from arbitrary app icons.
 *
 * Use this for every app/system-tray/notification icon in the pixel family.
 * Do NOT use it for music cover art in the media controls — that keeps color.
 *
 * Provide either `icon` (an icon-theme name, resolved via Quickshell.iconPath)
 * or `source` (an explicit url). `source` wins when set. When the icon can't be
 * resolved (no source / load error — e.g. a Slack notification with no theme
 * icon), a `fallbackIcon` PixIcon glyph is shown instead of a blank square.
 */
Item {
    id: root
    property string icon: ""
    property string source: ""
    property real size: 22
    // Lower = chunkier pixels. The icon is decoded to this many px then scaled up.
    property int pixelResolution: 16
    // Shown when the app icon can't be resolved. "" disables the fallback.
    property string fallbackIcon: "puzzle"
    property color fallbackColor: PixTheme.colors.fg

    implicitWidth: size
    implicitHeight: size

    readonly property string resolvedSource: root.source !== "" ? root.source
        : (root.icon !== "" ? Quickshell.iconPath(root.icon, "image-missing") : "")
    readonly property bool resolved: img.status === Image.Ready

    Image {
        id: img
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: true
        smooth: false
        mipmap: false
        fillMode: Image.PreserveAspectFit
        source: root.resolvedSource
        sourceSize.width: root.pixelResolution
        sourceSize.height: root.pixelResolution
    }

    Desaturate {
        anchors.fill: parent
        source: img
        desaturation: 1.0 // fully grayscale — no color
        smooth: false
        visible: root.resolved
    }

    // Fallback glyph for unresolved icons (empty source or load error).
    PixIcon {
        anchors.centerIn: parent
        visible: root.fallbackIcon !== ""
            && (img.status === Image.Null || img.status === Image.Error)
        name: root.fallbackIcon
        size: root.size * 0.85
        color: root.fallbackColor
    }
}
