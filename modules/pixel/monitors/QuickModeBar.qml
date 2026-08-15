pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * The headline control: one tap to make every connected monitor Extend / Mirror /
 * Single, plus "Auto" to hand control back to the user's own hyprdynamicmonitors
 * profiles. When Single is active a chip row picks which output stays on.
 *
 * With more than one screen, Extend also exposes where the secondary screens are
 * placed (ArrangePicker) and which screen is primary; Mirror exposes the primary
 * (= mirror source). Any quick layout exposes per-screen zoom (ZoomPicker).
 *
 * Reads/writes purely through the Monitors service; never touches the user's
 * profiles or monitors.conf directly.
 *
 * A MODE change (Extend/Mirror/Single/Auto) is not applied from here: it leaves
 * as `modeRequested`, so the host can snapshot the current layout and hold the
 * change for confirmation (QuickConfirm). Arrangement, primary screen and zoom
 * are applied directly — they cannot take a screen away.
 */
ColumnLayout {
    id: root
    spacing: 8

    // Emitted for a mode change. mode: "extend"|"mirror"|"single"|"auto";
    // target is the output "single" keeps on, "" otherwise.
    signal modeRequested(string mode, string target)

    // "auto" when no quick override is active, else the active quick mode.
    readonly property string current: Monitors.quickActive ? Monitors.quickMode : "auto"

    // Which output "Single" would keep on. Empty when nothing is connected — the
    // one case where Single has no safe meaning, so the button is disabled rather
    // than left to be refused by hdm-control.py.
    readonly property string singleTarget: Monitors.singleTargetCandidate

    readonly property var modes: [
        { id: "extend", icon: "nodes", label: "Extend" },
        { id: "mirror", icon: "swap", label: "Mirror" },
        { id: "single", icon: "fullscreen", label: "Single" }
    ]

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.modes
            delegate: PixButton {
                id: modeBtn
                required property var modelData
                readonly property bool possible: modelData.id !== "single" || root.singleTarget !== ""

                Layout.fillWidth: true
                Layout.preferredHeight: 54
                enabled: !Monitors.busy && modeBtn.possible
                opacity: modeBtn.possible ? 1 : 0.4
                filled: root.current === modelData.id
                onClicked: root.modeRequested(modelData.id, modelData.id === "single" ? root.singleTarget : "")

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 3
                    PixIcon {
                        Layout.alignment: Qt.AlignHCenter
                        name: modeBtn.modelData.icon
                        size: 18
                        color: modeBtn.contentColor
                    }
                    PixText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modeBtn.modelData.label
                        font.pixelSize: PixTheme.font.pixelSize.small
                        color: modeBtn.contentColor
                    }
                }
            }
        }
    }

    // Why Single is dead. A disabled control with no explanation reads as a bug;
    // this is the one case where the layout has no safe meaning at all.
    PixText {
        Layout.fillWidth: true
        visible: root.singleTarget === ""
        text: "Single needs a connected screen to keep on."
        font.pixelSize: PixTheme.font.pixelSize.smaller
        color: PixTheme.colors.grey
        wrapMode: Text.WordWrap
    }

    // Single-display target picker — visible only in single mode. Every chip is a
    // CONNECTED output, so picking one can never black the machine out; the
    // target that would be dangerous (an absent one) is not offered, and
    // hdm-control.py refuses it anyway.
    MonitorChips {
        Layout.fillWidth: true
        visible: root.current === "single"
        selected: Monitors.quickTarget
        // Switching the target moves the desktop to another screen and turns the
        // current one off, so it is confirmed exactly like a mode change.
        onPicked: name => root.modeRequested("single", name)
    }

    // Alignment of the extended desktop.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 5
        visible: root.current === "extend" && Monitors.monitors.length > 1

        PixText {
            text: "OTHER SCREENS GO"
            font.bold: true
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
        ArrangePicker { Layout.fillWidth: true }
    }

    // Which screen everything else is arranged around: pinned to 0x0 when
    // extending, the mirror source when mirroring.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 5
        visible: (root.current === "extend" || root.current === "mirror") && Monitors.monitors.length > 1

        PixText {
            text: "PRIMARY SCREEN"
            font.bold: true
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
        MonitorChips {
            Layout.fillWidth: true
            selected: Monitors.quickAnchor
            implicitFirst: true
            onPicked: name => Monitors.setAnchor(name)
        }
    }

    // Per-screen zoom. Only offered for quick layouts — that's where the shell owns
    // the monitor lines; under "Auto" the active profile decides the scale.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 5
        visible: root.current !== "auto" && Monitors.monitors.length > 0

        PixText {
            text: "ZOOM"
            font.bold: true
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
        ZoomPicker { Layout.fillWidth: true }
    }

    // Return to the user's auto-selected profiles.
    PixButton {
        id: autoBtn
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        enabled: !Monitors.busy
        filled: root.current === "auto"
        // Auto is a mode change too — handing the layout back to the user's own
        // profiles can move or drop screens just as Single can, so it is held for
        // confirmation like the other three.
        onClicked: root.modeRequested("auto", "")
        RowLayout {
            anchors.centerIn: parent
            spacing: 7
            PixIcon {
                name: "refresh"
                size: 15
                color: autoBtn.contentColor
            }
            PixText {
                text: "Auto (my profiles)"
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.small
                color: autoBtn.contentColor
            }
        }
    }
}
