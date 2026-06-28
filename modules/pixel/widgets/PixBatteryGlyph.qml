import QtQuick
import qs.modules.pixel.common

/**
 * The pixel battery glyph from the design: a 2px-bordered cell with an inner
 * fill proportional to `percent`, plus a small terminal nub on the right.
 * Everything is drawn from rectangles so it stays crisp. `u` is the pixel unit
 * (scale it up for larger glyphs).
 */
Item {
    id: root
    property real percent: 100      // 0..100
    property bool charging: false
    property color color: PixTheme.colors.fg
    property int u: 1               // pixel unit multiplier

    // Body 18x11, nub 2 wide => 20 x 11 (in base pixels)
    implicitWidth: 20 * u
    implicitHeight: 11 * u

    // Battery body outline
    Rectangle {
        id: body
        x: 0
        y: 0
        width: 18 * root.u
        height: 11 * root.u
        color: "transparent"
        radius: 0
        antialiasing: false
        border.width: 2 * root.u
        border.color: root.color
    }

    // Inner fill, proportional to charge (inset 1px from the border)
    Rectangle {
        x: 3 * root.u
        y: 3 * root.u
        readonly property real maxFill: 12 * root.u // 18 - 2*border(2) - 2*inset(1)
        width: Math.max(0, Math.min(1, root.percent / 100) * maxFill)
        height: 5 * root.u
        color: root.color
        antialiasing: false
        visible: !root.charging
    }

    // Charging bolt overlay (simple lightning made of cells)
    PixIcon {
        anchors.centerIn: body
        visible: root.charging
        name: "bolt"
        size: 7 * root.u
        color: root.color
    }

    // Terminal nub
    Rectangle {
        x: 18 * root.u
        y: 3 * root.u
        width: 2 * root.u
        height: 5 * root.u
        color: root.color
        antialiasing: false
    }
}
