pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * A wrapping row of one chip per connected output, used wherever a single
 * monitor has to be picked: the quick "Single" target and the primary screen.
 * Emits picked(name). Behaviour is identical to the pixel MonitorChips.
 */
Flow {
    id: root

    property string selected: ""
    /// Fill the first chip when nothing is explicitly selected — mirrors how
    /// hdm-control.py falls back to Hyprland's own declaration order.
    property bool implicitFirst: false

    signal picked(string name)

    spacing: PaperTheme.gap.chip

    Repeater {
        model: Monitors.monitors

        delegate: PaperChip {
            required property var modelData
            required property int index

            label: modelData.name ?? "?"
            mono: true
            enabled: !Monitors.busy
            checked: root.selected === modelData.name || (root.implicitFirst && root.selected === "" && index === 0)
            onClicked: root.picked(modelData.name)
        }
    }
}
