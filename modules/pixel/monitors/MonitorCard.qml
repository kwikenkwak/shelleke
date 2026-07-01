pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A read-only summary of one connected monitor: filled screen square when the
 * output is enabled, name + description, and a resolution/position/scale line
 * with a mirror badge. Built so a phase-2 "edit mode" (steppers/toggles) can be
 * dropped in without restructuring — see the `editable` hook.
 */
PixPanel {
    id: card
    property var monitor: ({})
    property bool editable: false // phase-2 hook; unused in phase 1

    readonly property bool on: !(monitor.disabled ?? false)
    readonly property string mirrorOf: (monitor.mirrorOf && monitor.mirrorOf !== "none") ? monitor.mirrorOf : ""

    borderWidth: PixTheme.borderWidth
    implicitHeight: rl.implicitHeight + 16

    RowLayout {
        id: rl
        anchors.fill: parent
        anchors.margins: 8
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: 0
            antialiasing: false
            color: card.on ? PixTheme.colors.fg : "transparent"
            border.width: PixTheme.borderWidth
            border.color: PixTheme.colors.line

            PixIcon {
                anchors.centerIn: parent
                name: "fullscreen"
                size: 16
                color: card.on ? PixTheme.colors.bg : PixTheme.colors.fg
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            PixText {
                Layout.fillWidth: true
                text: (card.monitor.name ?? "?") + (card.monitor.description ? "  ·  " + card.monitor.description : "")
                font.bold: true
                font.pixelSize: PixTheme.font.pixelSize.normal
                elide: Text.ElideRight
            }
            PixText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller
                text: {
                    if (!card.on)
                        return "Disabled";
                    const m = card.monitor;
                    let s = `${m.width}×${m.height}@${Math.round(m.refreshRate ?? 0)}   ${m.x},${m.y}   ${m.scale}x`;
                    if (card.mirrorOf)
                        s += "   mirror→" + card.mirrorOf;
                    return s;
                }
            }
        }
    }
}
