pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * One connected output. A read-only summary — the `Monitors` service exposes no
 * per-output enable/disable action, so the enabled state is a MARK, not a
 * control (see the note in PaperMonitorsContent).
 *
 *   hairline   — a bare row one hairline apart from the next: a 16 px `display`
 *                glyph, `NAME · description` at 13, and the mode line in mono.
 *   ledger     — a card with a 26 px `display` plate, blue when the output is
 *                enabled.
 *   broadsheet — a card with a 28 px slot, oxblood when enabled, and a `Mirror`
 *                stamp instead of the inline `mirror→NAME`.
 */
PaperPanel {
    id: card

    property var monitor: ({})
    /// Hairline separates rows with a rule instead of framing them; the last row
    /// in a list turns it off.
    property bool separator: true

    readonly property bool on: !(monitor.disabled ?? false)
    readonly property string mirrorOf: (monitor.mirrorOf && monitor.mirrorOf !== "none") ? monitor.mirrorOf : ""
    readonly property real pad: PaperTheme.pick(6, 9, 10)
    readonly property real plateSize: PaperTheme.pick(0, 26, 28)

    kind: "card"
    implicitHeight: Math.max(text.implicitHeight, card.plateSize) + 2 * card.pad
    // Only ledger dims a disabled output's card. Hairline says it with ink and
    // broadsheet says it in words alone — a disabled output is information, and
    // information does not get greyed out for being inconvenient.
    opacity: (card.on || !PaperTheme.isLedger) ? 1 : 0.6

    // Hairline's row separator — the variant has no card to frame.
    PaperRule {
        visible: PaperTheme.isHairline && card.separator
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // The leading mark. Hairline draws the bare glyph; the other two set it in a
    // plate that carries the "enabled" ink.
    Rectangle {
        id: plate
        visible: !PaperTheme.isHairline
        anchors.left: parent.left
        anchors.leftMargin: card.pad
        anchors.verticalCenter: parent.verticalCenter
        width: card.plateSize
        height: card.plateSize
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
        color: card.on ? PaperTheme.accentWash : "transparent"
        border.width: PaperTheme.ruleWidth
        border.color: card.on ? PaperTheme.accent : PaperTheme.rule
    }

    PaperIcon {
        id: glyph
        anchors.centerIn: PaperTheme.isHairline ? undefined : plate
        anchors.left: PaperTheme.isHairline ? parent.left : undefined
        anchors.verticalCenter: PaperTheme.isHairline ? parent.verticalCenter : undefined
        name: "display"
        size: PaperTheme.pick(16, 15, 16)
        color: card.on ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : PaperTheme.ink3
    }

    Column {
        id: text
        anchors.left: PaperTheme.isHairline ? glyph.right : plate.right
        anchors.leftMargin: PaperTheme.pick(PaperTheme.spacing.medium, PaperTheme.spacing.sm, PaperTheme.spacing.medium)
        anchors.right: stamp.visible ? stamp.left : parent.right
        anchors.rightMargin: card.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        PaperText {
            width: parent.width
            text: (card.monitor.name ?? "?") + (card.monitor.description ? " · " + card.monitor.description : "")
            role: PaperTheme.pick("body", "small", "body")
            tone: card.on ? "ink" : "ink3"
            elide: Text.ElideRight
        }
        PaperText {
            width: parent.width
            role: "meta"
            mono: true
            tone: "ink3"
            elide: Text.ElideRight
            text: {
                if (!card.on)
                    return "Disabled";
                const m = card.monitor;
                // Ledger writes the mode line the way its config file does —
                // "Hz" spelled out and a signed origin; the other two set the
                // bare figures and let the three spaces do the aligning.
                const hz = Math.round(m.refreshRate ?? 0) + (PaperTheme.isLedger ? "Hz" : "");
                const at = (PaperTheme.isLedger ? "+" : "") + m.x + "," + m.y;
                // Ledger's card is the narrowest of the three, so it sets the
                // line on two spaces rather than three.
                const sp = PaperTheme.isLedger ? "  " : "   ";
                let s = `${m.width}×${m.height}@${hz}${sp}${at}${sp}${m.scale}×`;
                // Broadsheet stamps the mirror relation instead of writing it.
                if (card.mirrorOf && !PaperTheme.isBroadsheet)
                    s += sp + "mirror → " + card.mirrorOf;
                return s;
            }
        }
    }

    // Broadsheet stamps the mirror relation rather than spelling it into the
    // mode line — the stamp is the state, and the source it mirrors is one
    // hover away in the layout above.
    PaperStamp {
        id: stamp
        visible: card.mirrorOf !== "" && PaperTheme.isBroadsheet
        anchors.right: parent.right
        anchors.rightMargin: card.pad
        anchors.verticalCenter: parent.verticalCenter
        text: "Mirror"
        icon: "mirror"
        tone: "seal"
    }
}
