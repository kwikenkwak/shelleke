import QtQuick
import qs
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Stats cluster: ram / cpu values with PixIcons, a Claude session-usage
 * indicator (robot icon, shown only when ClaudeUsage is available), plus a
 * media "note" indicator (track title in grey, "No media" when nothing
 * playing). Hovering the stats shows the system-monitor popup; clicking the
 * media indicator opens the pixel media controls.
 *
 * Bound to ResourceUsage, ClaudeUsage and MprisController.
 */
MouseArea {
    id: root
    hoverEnabled: true
    implicitWidth: row.implicitWidth
    implicitHeight: 32

    readonly property var activePlayer: MprisController.activePlayer
    readonly property string trackTitle: activePlayer?.trackTitle ?? ""

    function pct(v) { return Math.round((v ?? 0) * 100); }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        // System stats — hovering this group shows the system-monitor popup.
        MouseArea {
            id: statsArea
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            implicitWidth: statsRow.implicitWidth
            implicitHeight: 32

            Row {
                id: statsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                PixStatItem { icon: "ram"; value: root.pct(ResourceUsage.memoryUsedPercentage) }
                PixStatItem { icon: "cpu"; value: root.pct(ResourceUsage.cpuUsage) }
                PixStatItem {
                    icon: "robot"
                    value: Math.round(ClaudeUsage.sessionPercent ?? 0)
                    visible: ClaudeUsage.available
                }
            }

            PixelBarPopup {
                hoverTarget: statsArea
                contentMargin: 16
                PixSystemMonitorPopup {}
            }
        }

        // Media note indicator — click to open the pixel media controls.
        MouseArea {
            id: mediaArea
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            implicitWidth: mediaRow.implicitWidth
            implicitHeight: 32
            // Open-only (closing is handled by the media controls' focus grab /
            // Escape), matching the quick-settings sliders button.
            onClicked: GlobalStates.mediaControlsOpen = true

            Row {
                id: mediaRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                PixIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "note"
                    size: 14
                    color: PixTheme.colors.grey
                }
                PixText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.trackTitle !== "" ? root.trackTitle : "No media"
                    color: PixTheme.colors.grey
                    font.pixelSize: PixTheme.font.pixelSize.larger
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 200)
                }
            }

            PixTooltip { text: "Media controls"; visibleCondition: mediaArea.containsMouse }
        }
    }
}
