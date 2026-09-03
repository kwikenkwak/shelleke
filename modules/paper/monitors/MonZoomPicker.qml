pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * Per-screen zoom (Hyprland monitor scale) for the quick layout: one row per
 * screen — the connector in mono in a fixed column, then the steps
 * 0.75 / 0.8 / 1 / 1.25 / 1.5 / 1.75 / 2× (sub-1 zooms OUT for more room).
 *
 * Steps that would not divide the screen's resolution into whole logical pixels
 * are marked impossible: Hyprland substitutes a nearby scale for those, so
 * offering them would lie about what you get. `PaperSegment` draws that in each
 * variant's own idiom — ink-4 with no underline in hairline, 35 % in ledger, a
 * dotted rule in broadsheet — which is exactly what the three SPECs ask for.
 *
 * Values are stored per output in the managed quick profile
 * (Monitors.setScale → hdm-control.py), so they survive mode/arrangement
 * changes and replugging.
 */
ColumnLayout {
    id: root

    spacing: PaperTheme.spacing.xs

    readonly property var steps: ["0.75", "0.8", "1", "1.25", "1.5", "1.75", "2"]

    /// In single mode only the screen that stays on is worth showing.
    readonly property var screens: Monitors.quickMode === "single" ? Monitors.monitors.filter(m => m.name === Monitors.quickTarget) : Monitors.monitors

    /// What to highlight: the stored quick value when the quick layout is the
    /// one actually on screen, otherwise whatever the live layout is using.
    function currentScale(monitor: var): string {
        if (Monitors.quickApplied)
            return Monitors.quickScales[monitor.name] ?? "1";
        return String(Math.round((monitor.scale ?? 1) * 1000) / 1000);
    }

    /// True when `step` divides the output's resolution into whole logical px.
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
            spacing: PaperTheme.spacing.small

            PaperText {
                Layout.preferredWidth: PaperTheme.pick(62, 58, 52)
                text: row.modelData.name ?? "?"
                role: "meta"
                mono: true
                tone: "ink3"
                elide: Text.ElideRight
            }

            // Ledger rules the five steps into ONE segmented control (its idiom
            // for "one of these"); hairline and broadsheet keep them as five
            // separate chips. Same data, same actions — a genuine structural
            // difference, so it is a Loader rather than a pile of `visible`s.
            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: PaperTheme.pick(24, 26, 26)
                sourceComponent: PaperTheme.isLedger ? segmentComponent : chipsComponent

                Component {
                    id: segmentComponent
                    PaperSegment {
                        mono: true
                        enabled: !Monitors.busy
                        options: root.steps.map(s => ({
                                    label: s + "×",
                                    value: s,
                                    enabled: root.exact(row.modelData, s)
                                }))
                        value: root.currentScale(row.modelData)
                        onPicked: v => Monitors.setScale(row.modelData.name, v)
                    }
                }
                Component {
                    id: chipsComponent
                    RowLayout {
                        spacing: PaperTheme.pick(PaperTheme.spacing.large, PaperTheme.spacing.xs, PaperTheme.spacing.xs)

                        Repeater {
                            model: root.steps

                            delegate: PaperChip {
                                required property string modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: PaperTheme.pick(20, 26, 26)
                                label: modelData + "×"
                                mono: true
                                enabled: root.exact(row.modelData, modelData) && !Monitors.busy
                                checked: root.currentScale(row.modelData) === modelData
                                onClicked: Monitors.setScale(row.modelData.name, modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
