pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * One row in the profiles list. The whole row is clickable and opens the editor
 * (where enable/disable, reorder, apply-layout and remove live). Filled marker =
 * the profile HDM currently has active; dimmed = disabled.
 */
PixPanel {
    id: row
    property var profile: ({})
    readonly property bool active: Monitors.activeProfile === (profile.name ?? "")
    readonly property bool isEnabled: profile.enabled ?? true
    signal clicked

    borderWidth: PixTheme.borderWidth
    implicitHeight: rl.implicitHeight + 14
    opacity: isEnabled ? 1 : 0.45

    RowLayout {
        id: rl
        anchors.fill: parent
        anchors.margins: 7
        spacing: 9

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
                text: (row.profile.name ?? "") + (row.active ? "  · active" : "") + (row.isEnabled ? "" : "  · disabled")
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
                    let s = req.length === 0 ? "no required monitors"
                        : req.map(r => (r.regex ? "~" : "") + (r.value || "?")).join("  +  ");
                    const c = [];
                    if (row.profile.power)
                        c.push(row.profile.power);
                    if (row.profile.lid)
                        c.push(row.profile.lid);
                    if (row.profile.has_modes && row.profile.static && row.profile.static.mode)
                        c.push("mode:" + row.profile.static.mode);
                    return c.length ? s + "   [" + c.join(", ") + "]" : s;
                }
            }
        }

        PixIcon {
            Layout.alignment: Qt.AlignVCenter
            name: "chevR"
            size: 14
            color: PixTheme.colors.grey
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
