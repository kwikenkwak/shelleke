import QtQuick
import qs.modules.paper.common

/**
 * A rubber stamp — a state you would press onto paper: `Charging`, `Daemon on`,
 * `Connected`, `Mirror`, `Running`, and the two session warnings.
 *
 *   ledger     — 9 px caps in `red` on `red-wash` inside a 1 px `red-2` frame,
 *                rotated −1.1°. The only rotated element in the variant and the
 *                only place stamp red carries a fill. Never clickable.
 *   broadsheet — a 1 px `seal` (sepia) frame over `sealWash`, letterspaced
 *                9.5 px caps, rotated −3.5°. `accent` and `link` tones exist.
 *   hairline   — hairline has NO stamps. This renders as plain micro-caps text
 *                in the requested tone, with no frame, no fill and no rotation,
 *                so shared surface code can use it unconditionally.
 *
 *   PaperStamp { text: "Charging" }
 *   PaperStamp { text: "Daemon on"; tone: "link" }
 *   PaperStamp { text: "Download in progress"; tone: "alert" }
 */
Item {
    id: root

    property string text: ""
    /// seal | accent | link | alert. Ignored in hairline beyond the text colour.
    property string tone: "seal"
    /// A leading glyph inside the stamp (`bolt` on a Charging stamp).
    property string icon: ""

    readonly property bool framed: PaperTheme.ornament.stamps

    readonly property color inkColor: {
        switch (root.tone) {
        case "accent":
            return PaperTheme.accent;
        case "link":
            return PaperTheme.link;
        case "alert":
            return PaperTheme.alert;
        default:
            return PaperTheme.seal;
        }
    }
    readonly property color washColor: {
        switch (root.tone) {
        case "accent":
            return PaperTheme.accentWash;
        case "link":
            return PaperTheme.linkWash;
        case "alert":
            return PaperTheme.alertWash;
        default:
            return PaperTheme.sealWash;
        }
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight

    Item {
        id: frame
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + (root.framed ? 2 * PaperTheme.pick(0, 6, 7) : 0)
        implicitHeight: row.implicitHeight + (root.framed ? 2 * PaperTheme.pick(0, 3, 4) : 0)
        rotation: root.framed ? PaperTheme.ornament.stampRotation : 0

        Rectangle {
            anchors.fill: parent
            visible: root.framed
            color: root.washColor
            radius: PaperTheme.radiusControl
            antialiasing: radius > 0
            border.width: PaperTheme.ruleWidth
            border.color: PaperTheme.isLedger ? PaperTheme.alertSoft : root.inkColor
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: PaperTheme.gap.icon
            PaperIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: 11
                color: root.inkColor
            }
            PaperText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                role: "micro"
                color: root.inkColor
                font.pixelSize: root.framed ? 9.5 : PaperTheme.font.size.micro
            }
        }
    }
}
