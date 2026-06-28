import QtQuick
import qs.modules.pixel.common
import "../common/pixicons_data.js" as PixIcons

/**
 * A 7x7 bitmap pixel icon, rendered as crisp square cells so it stays sharp
 * at any integer scale. `name` must be one of the keys in pixicons_data.js
 * (parsed from the design's icons.js). Color follows `color` (default fg).
 *
 * Available names: bell, bluetooth, bolt, calendar, chevD, chevL, chevR,
 * clock, coffee, cpu, dropper, flashoff, fullscreen, gear, heart, keyboard,
 * message, mic, moon, nodes, note, pencil, power, proc, puzzle, ram, refresh,
 * sliders, snow, sparkle, speaker, sun, swap, terminal, timer, todo, trash, wifi
 */
Item {
    id: root
    property string name: ""
    // Requested icon size in px. Actual size is snapped to a multiple of 7
    // so every pixel cell is an identical integer size (no seams/blur).
    property real size: 14
    property color color: PixTheme.colors.fg

    readonly property int cell: Math.max(1, Math.round(size / 7))
    readonly property var coords: PixIcons.icons[name] ?? []

    implicitWidth: cell * 7
    implicitHeight: cell * 7

    Repeater {
        model: root.coords
        delegate: Rectangle {
            id: pixelCell
            required property var modelData
            x: modelData[0] * root.cell
            y: modelData[1] * root.cell
            width: root.cell
            height: root.cell
            color: root.color
            antialiasing: false
        }
    }
}
