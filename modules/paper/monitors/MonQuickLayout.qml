pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The headline control of the Displays overlay: one tap to make every connected
 * monitor Extend / Mirror / Single, plus "Auto" to hand control back to the
 * user's own hyprdynamicmonitors profiles.
 *
 * With more than one screen, Extend also exposes where the secondary screens go
 * (PaperArrange) and which screen is primary; Mirror exposes the primary (= the
 * mirror source). Any quick layout exposes per-screen zoom.
 *
 * Reads and writes purely through the `Monitors` service; it never touches the
 * user's profiles or monitors.conf.
 *
 * A MODE change (Extend/Mirror/Single/Auto) is deliberately NOT applied from
 * here: it leaves as `modeRequested`, so the host can snapshot the current
 * layout and hold the change for confirmation (MonQuickConfirm). Arrangement,
 * primary screen and zoom are applied directly — none of them can take a screen
 * away.
 */
ColumnLayout {
    id: root

    spacing: PaperTheme.spacing.small

    /// Emitted for a mode change. mode ∈ extend | mirror | single | auto;
    /// `target` is the output "single" keeps on, "" otherwise.
    signal modeRequested(string mode, string target)

    /// "auto" when no quick override is active, else the active quick mode.
    readonly property string current: Monitors.quickActive ? Monitors.quickMode : "auto"

    /// Which output "Single" would keep on. Empty when nothing is connected — the
    /// one case where Single has no safe meaning, so the button is disabled
    /// rather than left for hdm-control.py to refuse.
    readonly property string singleTarget: Monitors.singleTargetCandidate

    readonly property var modes: [
        {
            id: "extend",
            icon: "nodes",
            label: "Extend"
        },
        {
            id: "mirror",
            icon: "swap",
            label: "Mirror"
        },
        {
            id: "single",
            icon: "fullscreen",
            label: "Single"
        }
    ]

    readonly property var arrangements: [
        {
            id: "right",
            label: "Right"
        },
        {
            id: "left",
            label: "Left"
        },
        {
            id: "up",
            label: "Above"
        },
        {
            id: "down",
            label: "Below"
        }
    ]

    // ---- the three modes ----
    RowLayout {
        Layout.fillWidth: true
        spacing: PaperTheme.pick(PaperTheme.spacing.large, PaperTheme.spacing.xs, PaperTheme.spacing.xs)

        Repeater {
            model: root.modes

            // Each mode owns a third of the width. In hairline the button keeps
            // its natural width inside that third — a button there IS its
            // label, and its underline is drawn to the label, not to the cell.
            delegate: Item {
                id: cell
                required property var modelData

                /// "Single" with nothing connected has no output to keep on. The
                /// widget draws the variant's own not-available mark for it.
                readonly property bool possible: cell.modelData.id !== "single" || root.singleTarget !== ""

                Layout.fillWidth: true
                Layout.preferredHeight: PaperTheme.pick(56, 50, 52)

                PaperButton {
                    anchors.fill: PaperTheme.isHairline ? undefined : parent
                    anchors.centerIn: PaperTheme.isHairline ? parent : undefined
                    shape: "stacked"
                    icon: cell.modelData.icon
                    iconSize: 18
                    label: cell.modelData.label
                    checked: root.current === cell.modelData.id
                    enabled: !Monitors.busy && cell.possible
                    onClicked: root.modeRequested(cell.modelData.id, cell.modelData.id === "single" ? root.singleTarget : "")
                }
            }
        }
    }

    // Why Single is dead. A disabled control with no explanation reads as a bug,
    // and this is the one case where the layout has no safe meaning at all.
    PaperText {
        Layout.fillWidth: true
        visible: root.singleTarget === ""
        text: "Single needs a connected screen to keep on."
        role: "meta"
        tone: "ink3"
        wrapMode: Text.WordWrap
    }

    // ---- which screen stays on, in single mode ----
    // Every chip is a CONNECTED output, so picking one can never black the
    // machine out; the dangerous target (an absent one) is never offered, and
    // hdm-control.py refuses it anyway.
    MonMonitorChips {
        Layout.fillWidth: true
        visible: root.current === "single"
        selected: Monitors.quickTarget
        // Switching the target moves the desktop to another screen and turns the
        // current one off, so it is confirmed exactly like a mode change.
        onPicked: name => root.modeRequested("single", name)
    }

    // ---- where the other screens go (extend only) ----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: PaperTheme.spacing.hair
        spacing: PaperTheme.spacing.xs
        visible: root.current === "extend" && Monitors.monitors.length > 1

        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Other screens go"
            // Hairline keeps its sub-labels bare; broadsheet rules above its heads.
            rule: PaperTheme.isLedger
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.pick(PaperTheme.spacing.medium, PaperTheme.spacing.xs, PaperTheme.spacing.xs)

            Repeater {
                model: root.arrangements

                delegate: PaperArrange {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: PaperTheme.pick(52, 52, 50)
                    direction: modelData.id
                    label: modelData.label
                    enabled: !Monitors.busy
                    checked: Monitors.quickArrange === modelData.id
                    onClicked: Monitors.setArrange(modelData.id)
                }
            }
        }
    }

    // ---- which screen everything else is arranged around ----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: PaperTheme.spacing.hair
        spacing: PaperTheme.spacing.xs
        visible: (root.current === "extend" || root.current === "mirror") && Monitors.monitors.length > 1

        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Primary screen"
            // Hairline keeps its sub-labels bare; broadsheet rules above its heads.
            rule: PaperTheme.isLedger
        }
        MonMonitorChips {
            Layout.fillWidth: true
            selected: Monitors.quickAnchor
            implicitFirst: true
            onPicked: name => Monitors.setAnchor(name)
        }
    }

    // ---- per-screen zoom ----
    // Only offered for quick layouts: that is where the shell owns the monitor
    // lines. Under "Auto" the active profile decides the scale.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: PaperTheme.spacing.hair
        spacing: PaperTheme.spacing.xs
        visible: root.current !== "auto" && Monitors.monitors.length > 0

        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Zoom"
            // Hairline keeps its sub-labels bare; broadsheet rules above its heads.
            rule: PaperTheme.isLedger
        }
        MonZoomPicker {
            Layout.fillWidth: true
        }
    }

    // ---- back to the user's own profiles ----
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: PaperTheme.spacing.tiny
        spacing: 0

        PaperButton {
            // Full width where a button is a box; natural width where it is a
            // line of type, so the underline sits under the words.
            Layout.fillWidth: !PaperTheme.isHairline
            Layout.preferredHeight: PaperTheme.pick(24, 30, 34)
            icon: "refresh"
            // Hairline sets its verbs with an em dash rather than parentheses.
            label: PaperTheme.isHairline ? "Auto — my profiles" : "Auto (my profiles)"
            checked: root.current === "auto"
            enabled: !Monitors.busy
            // Auto is a mode change too — handing the layout back to the user's
            // own profiles can move or drop screens just as Single can, so it is
            // held for confirmation like the other three.
            onClicked: root.modeRequested("auto", "")
        }
        Item {
            Layout.fillWidth: PaperTheme.isHairline
        }
    }
}
