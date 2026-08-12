pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Picks where the secondary screens sit relative to the primary one in the quick
 * Extend layout (Hyprland `auto-<dir>` placement, written by hdm-control.py).
 *
 * The pixel icon set has no arrows, so each option draws a two-square diagram
 * instead: filled square = primary screen, hollow = the other screen(s).
 */
RowLayout {
    id: root
    spacing: 8

    readonly property var options: [
        { id: "right", label: "Right" },
        { id: "left", label: "Left" },
        { id: "up", label: "Above" },
        { id: "down", label: "Below" }
    ]

    Repeater {
        model: root.options
        delegate: PixButton {
            id: btn
            required property var modelData
            // Stacked diagram for above/below; the hollow square leads when the
            // secondary screen goes left/up of the primary.
            readonly property bool vertical: modelData.id === "up" || modelData.id === "down"
            readonly property bool secondaryFirst: modelData.id === "left" || modelData.id === "up"

            Layout.fillWidth: true
            Layout.preferredHeight: 52
            enabled: !Monitors.busy
            filled: Monitors.quickArrange === modelData.id
            onClicked: Monitors.setArrange(modelData.id)

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 5

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: btn.vertical ? 1 : 2
                    rowSpacing: 2
                    columnSpacing: 2

                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            required property int index
                            readonly property bool primary: index === (btn.secondaryFirst ? 1 : 0)
                            Layout.preferredWidth: 13
                            Layout.preferredHeight: 9
                            radius: 0
                            antialiasing: false
                            color: primary ? btn.contentColor : "transparent"
                            border.width: PixTheme.borderWidth
                            border.color: btn.contentColor
                        }
                    }
                }

                PixText {
                    Layout.alignment: Qt.AlignHCenter
                    text: btn.modelData.label
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                    color: btn.contentColor
                }
            }
        }
    }
}
