pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A read-only row for one of the user's hyprdynamicmonitors profiles. The active
 * profile (as reported by HDM) gets a filled marker. Profiles are shown but not
 * edited in phase 1; the trailing space is where phase-2 "Edit" / "Save current
 * here" actions will live.
 */
PixPanel {
    id: row
    property var profile: ({})
    readonly property bool active: Monitors.activeProfile === (profile.name ?? "")

    borderWidth: PixTheme.borderWidth
    implicitHeight: rl.implicitHeight + 14

    RowLayout {
        id: rl
        anchors.fill: parent
        anchors.margins: 7
        spacing: 9

        // Active marker: filled square when this profile is the one in effect.
        Rectangle {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            radius: 0
            antialiasing: false
            color: row.active ? PixTheme.colors.fg : "transparent"
            border.width: PixTheme.borderWidth
            border.color: PixTheme.colors.line
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            PixText {
                Layout.fillWidth: true
                text: (row.profile.name ?? "") + (row.active ? "  · active" : "")
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
                    const req = row.profile.required ?? [];
                    if (req.length === 0)
                        return "no required monitors";
                    return req.map(r => r.description || r.name || "?").join("  +  ");
                }
            }
        }

        // Static-mode hint (e.g. beide_aan mode=both), read-only.
        PixText {
            visible: row.profile.has_modes ?? false
            Layout.alignment: Qt.AlignVCenter
            text: "mode:" + ((row.profile.static_values && row.profile.static_values.mode) || "?")
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smallest
        }
    }
}
