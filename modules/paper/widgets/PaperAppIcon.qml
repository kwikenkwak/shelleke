import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.modules.paper.common

/**
 * A third-party app / tray / notification icon, brought onto the page.
 * Mirrors PixAppIcon's pipeline with the paper family's ink policy.
 *
 *   hairline   — desaturate fully AND multiply toward `ink-2`. One ink, no
 *                third-party colour at all.
 *   ledger     — `grayscale(.55) contrast(.95)` and a hairline plate, so a
 *                pasted-in logo reads like a stamp on the page rather than a
 *                sticker. Some brand colour survives, on purpose.
 *   broadsheet — desaturate and duotone toward `ink-2` — a newsprint halftone —
 *                in a hairline slot. Tray icons are drawn WITHOUT the slot so
 *                the bar stays airy (`plate: false`).
 *
 * ALBUM ART IS NOT THIS WIDGET. Cover art is the one place full colour is
 * allowed in the whole shell; render it with a plain Image in a framed well.
 *
 *   PaperAppIcon { icon: trayItem.icon; size: PaperTheme.icon.tray; plate: false }
 *   PaperAppIcon { icon: appClass; size: 16; fallbackIcon: "message" }
 *
 * Provide either `icon` (a theme name, resolved via Quickshell.iconPath) or
 * `source` (an explicit url); `source` wins. Unresolvable icons fall back to a
 * PaperIcon glyph — `puzzle` by default, `message` inside notifications.
 */
Item {
    id: root

    property string icon: ""
    property string source: ""
    property real size: PaperTheme.icon.control
    /// Sit the icon in a hairline plate. Defaults to the variant's habit.
    property bool plate: PaperTheme.appIcon.plate
    /// Shown when the icon can't be resolved. "" disables the fallback.
    property string fallbackIcon: "puzzle"
    property color fallbackColor: PaperTheme.ink2

    /// Outer plate size. Defaults to the glyph plus the variant's own margin;
    /// override where a SPEC gives the plate an absolute size (notifications
    /// spec 28 px in hairline / 32 px in the other two) rather than a margin.
    property real plateSize: root.size + PaperTheme.pick(0, 8, 10)
    readonly property string resolvedSource: root.source !== "" ? root.source : (root.icon !== "" ? Quickshell.iconPath(root.icon, "image-missing") : "")
    readonly property bool resolved: img.status === Image.Ready
    readonly property bool tinted: PaperTheme.appIcon.tintStrength > 0

    implicitWidth: root.plate ? root.plateSize : root.size
    implicitHeight: root.plate ? root.plateSize : root.size

    // The plate — a 1 px hairline square holding the icon.
    Rectangle {
        anchors.fill: parent
        visible: root.plate
        color: "transparent"
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        border.width: PaperTheme.ruleWidth
        border.color: PaperTheme.rule
    }

    Item {
        id: iconBox
        anchors.centerIn: parent
        width: root.size
        height: root.size

        Image {
            id: img
            anchors.fill: parent
            visible: false
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
            source: root.resolvedSource
            sourceSize.width: Math.ceil(root.size * 2)
            sourceSize.height: Math.ceil(root.size * 2)
        }

        Desaturate {
            id: desat
            anchors.fill: parent
            source: img
            desaturation: PaperTheme.appIcon.desaturation
            visible: root.resolved && !root.tinted
            // Feed the tint stage below when there is one.
            layer.enabled: root.tinted
        }

        // Multiply toward the ink. Hairline and broadsheet only; ledger keeps
        // its .55 grayscale and no tint.
        ColorOverlay {
            anchors.fill: parent
            visible: root.resolved && root.tinted
            source: desat
            color: Qt.rgba(PaperTheme.appIcon.tint.r, PaperTheme.appIcon.tint.g, PaperTheme.appIcon.tint.b, PaperTheme.appIcon.tintStrength)
        }

        // Fallback glyph for an empty source or a load error.
        PaperIcon {
            anchors.centerIn: parent
            visible: root.fallbackIcon !== "" && (img.status === Image.Null || img.status === Image.Error)
            name: root.fallbackIcon
            size: root.size * 0.85
            color: root.fallbackColor
        }
    }
}
