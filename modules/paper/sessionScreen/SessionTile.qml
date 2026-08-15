pragma ComponentBehavior: Bound

import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick

/**
 * Ledger's and broadsheet's session choice — §4.8 / §4.9 of their SPECs.
 *
 * SURFACE-LOCAL: session-specific, not a shared composite. Prefixed `Session…`
 * per the surface-group convention.
 *
 *   ledger     — a 116 px hairline CARD. The number accelerator is boxed in a
 *                15 px hairline square in the top-left corner, like a line
 *                number in a ledger; then a 28 px line icon and a 10 px caps
 *                label. The selection is the variant's ordinary mark: blue
 *                hairline, blue wash, blue ink and a 2 px blue underline.
 *   broadsheet — a 128 px SHEET of paper laid on the scrim with its own shadow.
 *                The accelerator is set in Pagella oldstyle 12 with no box, the
 *                glyph is 38 px, the label is Pagella small caps. The selected
 *                tile does NOT invert: it takes an oxblood frame, oxblood
 *                corner ticks, an oxblood glyph and an oxblood label — quieter
 *                and much easier to track while arrowing across the row.
 *
 * Both variants draw every action with its own glyph; nothing is substituted.
 */
PaperPanel {
    id: root

    required property string glyph
    required property string label
    required property string accelerator
    property bool selected: false

    signal activated
    signal selectRequested

    readonly property bool hovered: mouse.containsMouse

    kind: PaperTheme.isBroadsheet ? "sheet" : "card"
    floating: PaperTheme.isBroadsheet
    // Broadsheet marks the SELECTED sheet with oxblood corner ticks — the
    // panel's own ticks, recoloured. (`ticks` is gated on `ornament.cornerTicks`
    // inside PaperPanel, so this is already broadsheet-only.)
    ticks: root.selected
    tickColor: PaperTheme.accent

    implicitWidth: PaperTheme.size.sessionTile
    implicitHeight: PaperTheme.size.sessionTile

    frameTone: root.selected ? "accent" : ""
    color: root.selected ? (PaperTheme.isBroadsheet ? PaperTheme.paper : PaperTheme.accentWash) : root.hovered ? PaperTheme.paperSunk : (PaperTheme.isBroadsheet ? PaperTheme.paper : PaperTheme.paperRaise)

    // The accelerator. Ledger boxes it; broadsheet sets it bare in oldstyle.
    Item {
        id: accelBox
        x: PaperTheme.pick(7, 7, 9)
        y: PaperTheme.pick(7, 7, 7)
        z: 4
        implicitWidth: PaperTheme.isLedger ? 15 : accelText.implicitWidth
        implicitHeight: PaperTheme.isLedger ? 15 : accelText.implicitHeight

        Rectangle {
            anchors.fill: parent
            visible: PaperTheme.isLedger
            color: "transparent"
            radius: 1
            antialiasing: false
            border.width: PaperTheme.ruleWidth
            border.color: root.selected ? PaperTheme.accent : PaperTheme.rule
        }

        PaperText {
            id: accelText
            anchors.centerIn: parent
            role: PaperTheme.isBroadsheet ? "small" : "micro"
            mono: !PaperTheme.isBroadsheet
            figure: PaperTheme.isBroadsheet
            font.pixelSize: PaperTheme.pick(9, 9, 12)
            font.letterSpacing: 0
            color: root.selected ? PaperTheme.accent : PaperTheme.ink4
            text: root.accelerator
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: PaperTheme.pick(12, 12, 13)

        PaperIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.glyph
            size: PaperTheme.icon.session
            color: root.selected ? PaperTheme.accent : PaperTheme.ink2
        }

        PaperTitle {
            id: tileLabel
            anchors.horizontalCenter: parent.horizontalCenter
            // Ledger letterspaces uppercase; broadsheet uses real small caps.
            caps: !PaperTheme.isBroadsheet
            role: PaperTheme.isBroadsheet ? "lead" : "micro"
            font.weight: PaperTheme.isLedger ? PaperTheme.font.weight.bold : PaperTheme.font.weight.title
            font.letterSpacing: PaperTheme.tracking(PaperTheme.font.trackingEm.micro, tileLabel.font.pixelSize)
            color: root.selected ? PaperTheme.accent : PaperTheme.ink2
            text: root.label
        }
    }

    // Ledger's 2 px selection underline, inset inside the card frame.
    Rectangle {
        visible: root.selected && !PaperTheme.isBroadsheet
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: PaperTheme.ruleWidth
        height: PaperTheme.markWidth
        color: PaperTheme.accent
        antialiasing: false
        z: 4
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.selectRequested()
        onClicked: root.activated()
    }
}
