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
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: root.current === "single"

        Repeater {
            model: Monitors.monitors
            delegate: PixButton {
                id: chip
                required property var modelData
                implicitHeight: 30
                implicitWidth: chipText.implicitWidth + 20
                enabled: !Monitors.busy
                filled: Monitors.quickTarget === modelData.name
                onClicked: Monitors.setQuick("single", modelData.name)
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
