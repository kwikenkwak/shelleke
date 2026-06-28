import QtQuick
import qs.modules.pixel.common

/** Title text in Silkscreen, foreground color, slight letter spacing. */
Text {
    id: root
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    color: PixTheme.colors.fg
    font {
        family: PixTheme.fontTitle
        pixelSize: PixTheme.font.pixelSize.title
        weight: Font.Bold
        letterSpacing: 1
        hintingPreference: Font.PreferFullHinting
    }
}
