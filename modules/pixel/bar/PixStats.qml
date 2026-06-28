import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Stats cluster: ram / swap / cpu values with PixIcons, a Claude session-usage
 * indicator (shown only when ClaudeUsage is available), plus a media "note"
 * indicator (track title in grey, "No media" when nothing playing).
 * Hovering anywhere over the cluster shows the system-monitor popup.
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
                PixStatItem { icon: "swap"; value: root.pct(ResourceUsage.swapUsedPercentage) }
                PixStatItem { icon: "cpu"; value: root.pct(ResourceUsage.cpuUsage) }
                PixStatItem {
                    icon: "sparkle"
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

        // Media note indicator — hovering it shows the media popup.
        MouseArea {
            id: mediaArea
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            implicitWidth: mediaRow.implicitWidth
            implicitHeight: 32

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

            PixelBarPopup {
                hoverTarget: mediaArea
                contentMargin: 14
                PixMediaPopup {}
            }
        }
    }
}
