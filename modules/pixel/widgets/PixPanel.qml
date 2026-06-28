import QtQuick
import qs.modules.pixel.common

/**
 * A hard-bordered, square (radius 0) container — the building block for popups
 * and panels. Default border is the thick popup border; set `borderWidth` for
 * thinner inline chips (PixTheme.borderWidth).
 */
Rectangle {
    id: root
    property int borderWidth: PixTheme.popupBorderWidth
    color: PixTheme.colors.bg
    radius: 0
    antialiasing: false
    border.width: borderWidth
    border.color: PixTheme.colors.line
}
