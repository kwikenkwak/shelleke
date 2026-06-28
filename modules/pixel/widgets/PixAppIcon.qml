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
 * or `source` (an explicit url). `source` wins when set.
 */
Item {
    id: root
    property string icon: ""
    property string source: ""
    property real size: 22
    // Lower = chunkier pixels. The icon is decoded to this many px then scaled up.
    property int pixelResolution: 16

    implicitWidth: size
    implicitHeight: size

    readonly property string resolvedSource: root.source !== "" ? root.source
        : (root.icon !== "" ? Quickshell.iconPath(root.icon, "image-missing") : "")

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
    }
}
