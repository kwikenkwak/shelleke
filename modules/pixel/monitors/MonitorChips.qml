pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A wrapping row of one chip per connected output, used to pick a single monitor
 * (quick single target, primary screen, …). Emits picked(name).
 */
Flow {
    id: root
    property string selected: ""
    // Fill the first chip when nothing is explicitly selected — mirrors how
    // hdm-control.py falls back to Hyprland's own declaration order.
    property bool implicitFirst: false
    signal picked(string name)

    spacing: 6

    Repeater {
        model: Monitors.monitors
        delegate: PixButton {
            id: chip
            required property var modelData
            required property int index
            implicitHeight: 30
            implicitWidth: chipText.implicitWidth + 20
            enabled: !Monitors.busy
            filled: root.selected === modelData.name
                || (root.implicitFirst && root.selected === "" && index === 0)
            onClicked: root.picked(modelData.name)
            PixText {
                id: chipText
                anchors.centerIn: parent
                text: chip.modelData.name
                font.pixelSize: PixTheme.font.pixelSize.smaller
                color: chip.contentColor
            }
        }
    }
}
