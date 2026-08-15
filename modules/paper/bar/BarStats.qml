import QtQuick
import qs
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The stats cluster — RAM / CPU / Claude — followed by a divider and the media
 * indicator.
 *
 * Hovering the stats group opens the system-monitor popup (left-aligned).
 * Clicking the media indicator opens the media controls (open-only; the media
 * panel's own focus grab closes it), and it carries a "Media controls" tooltip.
 *
 * `PaperStat` carries the variant disagreement: hairline shows glyph + figure,
 * ledger shows caps-label + figure with NO glyph at all ("the label is the
 * icon"), broadsheet shows glyph + kicker + oldstyle figure.
 *
 * Bound to ResourceUsage, ClaudeUsage, MprisController.
 */
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: PaperTheme.barHeight - PaperTheme.pick(8, 6, 10)

    /// The bar's cluster gap, so the divider before the media indicator matches
    /// the ones the bar itself draws.
    property real clusterGap: PaperTheme.pick(20, 12, 13)

    readonly property var activePlayer: MprisController.activePlayer
    readonly property string trackTitle: root.activePlayer?.trackTitle ?? ""
    readonly property bool hasMedia: root.trackTitle !== ""

    function pct(v: real): string {
        const n = Math.round((v ?? 0) * 100);
        return PaperTheme.isHairline ? `${n} %` : `${n}%`;
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // ---- system stats — hover opens the system monitor -----------------
        MouseArea {
            id: statsArea
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            implicitWidth: statsRow.implicitWidth
            implicitHeight: root.implicitHeight

            Row {
                id: statsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: PaperTheme.pick(20, 14, 15)

                PaperStat {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "ram"
                    label: PaperTheme.isBroadsheet ? "Mem" : "Ram"
                    value: root.pct(ResourceUsage.memoryUsedPercentage)
                }
                PaperStat {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "cpu"
                    label: "Cpu"
                    value: root.pct(ResourceUsage.cpuUsage)
                }
                PaperStat {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ClaudeUsage.available
                    icon: "robot"
                    label: "Claude"
                    value: PaperTheme.isHairline ? `${Math.round(ClaudeUsage.sessionPercent ?? 0)} %` : `${Math.round(ClaudeUsage.sessionPercent ?? 0)}%`
                    alert: ClaudeUsage.warning
                }
            }

            BarPopup {
                hoverTarget: statsArea
                alignLeft: true
                BarSystemMonitorPopup {}
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.clusterGap
            implicitHeight: 1
        }
        BarDivider {
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.clusterGap
            implicitHeight: 1
        }

        // ---- media indicator — click opens the media controls ---------------
        MouseArea {
            id: mediaArea
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            implicitWidth: mediaRow.implicitWidth
            implicitHeight: root.implicitHeight
            // Open-only: closing is the media panel's focus grab / Escape.
            onClicked: GlobalStates.mediaControlsOpen = true

            Row {
                id: mediaRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: PaperTheme.pick(9, 7, 7)

                PaperIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "note"
                    size: PaperTheme.pick(14, 13, 13)
                    color: PaperTheme.ink3
                }

                PaperText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hasMedia ? root.trackTitle : "No media"
                    // Broadsheet sets the track in Pagella ITALIC — it is a
                    // title, and the one thing on the bar quoting something else.
                    role: PaperTheme.isBroadsheet ? "body" : "small"
                    footnote: PaperTheme.isBroadsheet || !root.hasMedia
                    tone: root.hasMedia ? "ink2" : "ink4"
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, PaperTheme.pick(190, 190, 220))
                }
            }

            PaperTooltip {
                text: "Media controls"
                subtext: root.hasMedia ? (root.activePlayer?.trackArtist ?? "") : ""
                visibleCondition: mediaArea.containsMouse
            }
        }
    }
}
