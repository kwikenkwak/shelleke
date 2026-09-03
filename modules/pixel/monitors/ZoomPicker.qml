pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Per-screen zoom (Hyprland monitor scale) for the quick layout: one row per
 * screen, one chip per step. Steps that wouldn't divide the screen's resolution
 * into whole logical pixels are dimmed — Hyprland substitutes a nearby scale for
 * those, so offering them would lie about what you get.
 *
 * Values are stored per output in the managed quick profile (Monitors.setScale ->
 * hdm-control.py), so they survive mode/arrangement changes and replugging.
 */
ColumnLayout {
    id: root
    spacing: 5

    readonly property var steps: ["0.75", "0.8", "1", "1.25", "1.5", "1.75", "2"]

    // In single mode only the screen that stays on is worth showing.
    readonly property var screens: Monitors.quickMode === "single"
        ? Monitors.monitors.filter(m => m.name === Monitors.quickTarget)
        : Monitors.monitors

    // What to highlight: the stored quick value when the quick layout is the one on
    // screen, otherwise whatever the live layout is actually using.
    function currentScale(monitor: var): string {
        if (Monitors.quickApplied)
            return Monitors.quickScales[monitor.name] ?? "1";
        return String(Math.round((monitor.scale ?? 1) * 1000) / 1000);
    }

    function exact(monitor: var, step: string): bool {
        const s = parseFloat(step);
        const w = (monitor.width ?? 0) / s;
        const h = (monitor.height ?? 0) / s;
        return Math.abs(w - Math.round(w)) < 0.002 && Math.abs(h - Math.round(h)) < 0.002;
    }

    Repeater {
        model: root.screens
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 5

            PixText {
                Layout.preferredWidth: 56
                text: row.modelData.name ?? "?"
                elide: Text.ElideRight
                font.pixelSize: PixTheme.font.pixelSize.smaller
                color: PixTheme.colors.grey
            }

            Repeater {
                model: root.steps
                delegate: PixButton {
                    id: step
                    required property string modelData
                    readonly property bool fits: root.exact(row.modelData, modelData)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    enabled: step.fits && !Monitors.busy
                    opacity: step.fits ? 1 : 0.3
                    filled: root.currentScale(row.modelData) === modelData
                    onClicked: Monitors.setScale(row.modelData.name, modelData)

                    PixText {
                        anchors.centerIn: parent
                        text: step.modelData + "x"
                        font.pixelSize: PixTheme.font.pixelSize.smaller
                        color: step.contentColor
                    }
                }
            }
        }
    }
}
