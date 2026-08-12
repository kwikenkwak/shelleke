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
 */
ColumnLayout {
    id: root
    spacing: 8

    // "auto" when no quick override is active, else the active quick mode.
    readonly property string current: Monitors.quickActive ? Monitors.quickMode : "auto"

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
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                enabled: !Monitors.busy
                filled: root.current === modelData.id
                onClicked: Monitors.setQuick(modelData.id,
                    modelData.id === "single" ? (Monitors.quickTarget || (Monitors.monitors[0]?.name ?? "")) : "")

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

    // Single-display target picker — visible only in single mode.
    MonitorChips {
        Layout.fillWidth: true
        visible: root.current === "single"
        selected: Monitors.quickTarget
        onPicked: name => Monitors.setQuick("single", name)
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
        onClicked: Monitors.clearQuick()
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
