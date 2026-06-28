pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Theme singleton for the "pixel" panel family.
 *
 * The Pixel design is strictly monochrome with two inverted modes:
 *   - light: black-on-white  (bg #ffffff, fg #141414)
 *   - dark : white-on-black  (bg #0b0b0b, fg #f4f4f4)
 *
 * Dark mode follows the shell-wide dark mode toggle (Appearance.m3colors.darkmode),
 * so the bar's sun/dark-mode control keeps working.
 *
 * Aesthetic rules baked in here (mirroring the design CSS variables):
 *   - hard 2px/3px solid borders, never rounded (radius 0)
 *   - no drop shadows / bevels
 *   - Pixelify Sans for body text, Silkscreen for titles
 *   - 7x7 bitmap pixel icons (see PixIcon + pixicons_data.js)
 */
Singleton {
    id: root

    // Follows the global dark mode toggle. dark => white-on-black.
    readonly property bool dark: Appearance.m3colors.darkmode

    // ---- Fonts (bundled under assets/fonts) ----
    FontLoader {
        id: pixelifyLoader
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/PixelifySans.ttf"))
    }
    FontLoader {
        id: silkscreenRegularLoader
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/Silkscreen-Regular.ttf"))
    }
    FontLoader {
        id: silkscreenBoldLoader
        source: Qt.resolvedUrl(Quickshell.shellPath("assets/fonts/Silkscreen-Bold.ttf"))
    }

    readonly property string fontMain: pixelifyLoader.status === FontLoader.Ready ? pixelifyLoader.name : "Pixelify Sans"
    readonly property string fontTitle: silkscreenRegularLoader.status === FontLoader.Ready ? silkscreenRegularLoader.name : "Silkscreen"

    // ---- Colors ----
    readonly property QtObject colors: QtObject {
        readonly property color bg: root.dark ? "#0b0b0b" : "#ffffff"
        readonly property color fg: root.dark ? "#f4f4f4" : "#141414"
        // Muted / secondary text
        readonly property color grey: root.dark ? "#9b9b9b" : "#6e6e6e"
        // Faint (e.g. out-of-month calendar days, disabled)
        readonly property color grey2: root.dark ? "#555555" : "#bdbdbd"
        // Lines / borders. Same as fg in this design.
        readonly property color line: root.dark ? "#f4f4f4" : "#141414"
        // Convenience inverse (filled chips: bg-colored content on an fg-colored fill)
        readonly property color onFill: bg
    }

    // ---- Borders ----
    readonly property int borderWidth: 2      // --bd
    readonly property int popupBorderWidth: 3 // --popbd
    readonly property int barBorderWidth: 3   // --barbd

    // ---- Sizes ----
    readonly property int barHeight: 46

    readonly property QtObject font: QtObject {
        readonly property QtObject pixelSize: QtObject {
            readonly property int smallest: 10
            readonly property int smaller: 11
            readonly property int small: 12
            readonly property int normal: 13
            readonly property int large: 14
            readonly property int larger: 15
            readonly property int title: 16
            readonly property int huge: 20
        }
    }

    // Animations are kept snappy/minimal to match the chunky pixel feel.
    readonly property QtObject animation: QtObject {
        readonly property int duration: 110
        readonly property int type: Easing.OutQuad
    }
}
