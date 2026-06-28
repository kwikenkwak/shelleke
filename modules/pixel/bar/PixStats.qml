import QtQuick
import Quickshell.Io
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Stats cluster: ram / swap / cpu / proc values with PixIcons, plus a media
 * "note" indicator (track title in grey, "No media" when nothing playing).
 * Hovering anywhere over the cluster shows the system-monitor popup.
 *
 * Bound to ResourceUsage and MprisController. "proc" (process count) is read
 * from /proc/loadav's running-process field via a small polled FileView.
 */
MouseArea {
    id: root
    hoverEnabled: true
    implicitWidth: row.implicitWidth
    implicitHeight: 32

    readonly property var activePlayer: MprisController.activePlayer
    readonly property string trackTitle: activePlayer?.trackTitle ?? ""

    // Running process count, parsed from /proc/loadavg ("running/total").
    property int processCount: 0

    function pct(v) { return Math.round((v ?? 0) * 100); }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: loadavgFile.reload()
    }

    FileView {
        id: loadavgFile
        path: "/proc/loadavg"
        onLoaded: {
            const parts = (loadavgFile.text() ?? "").trim().split(" ");
            const procs = parts[3] ?? "";       // e.g. "2/843"
            root.processCount = Number(procs.split("/")[0] ?? 0);
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        PixStatItem { icon: "ram"; value: root.pct(ResourceUsage.memoryUsedPercentage) }
        PixStatItem { icon: "swap"; value: root.pct(ResourceUsage.swapUsedPercentage) }
        PixStatItem { icon: "cpu"; value: root.pct(ResourceUsage.cpuUsage) }
        PixStatItem { icon: "proc"; value: root.processCount }

        // Media note indicator
        Row {
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
    }

    PixelBarPopup {
        hoverTarget: root
        contentMargin: 16
        PixSystemMonitorPopup {}
    }
}
