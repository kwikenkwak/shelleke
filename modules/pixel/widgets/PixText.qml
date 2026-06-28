import QtQuick
import qs.modules.pixel.common

/** Body text in Pixelify Sans, foreground color. */
Text {
    id: root
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    color: PixTheme.colors.fg
    font {
        family: PixTheme.fontMain
        pixelSize: PixTheme.font.pixelSize.normal
        hintingPreference: Font.PreferFullHinting
    }
}
