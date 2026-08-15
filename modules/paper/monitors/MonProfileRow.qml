pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * One row in the profiles list. The whole row is clickable and opens the editor
 * (where enable/disable, reorder, apply-layout and remove live).
 *
 * The leading marker means "this is the profile hyprdynamicmonitors currently
 * has active", and each variant marks it in its own idiom: a 6 px ink dot in
 * hairline, the 14 px ledger tick in ledger, a 13 px oxblood medallion in
 * broadsheet. A disabled profile renders at 45 % / 50 %.
 */
PaperPanel {
    id: row

    property var profile: ({})
    /// Hairline separates rows with a rule instead of framing them.
    property bool separator: true

    readonly property bool active: Monitors.activeProfile === (profile.name ?? "")
    readonly property bool isEnabled: profile.enabled ?? true
    readonly property real pad: PaperTheme.pick(6, 8, 9)
    readonly property real markerSize: PaperTheme.pick(PaperTheme.size.dot, 14, 13)

    signal activated

    kind: "card"
    implicitHeight: text.implicitHeight + 2 * row.pad
    // Broadsheet never dims: it says "· disabled" in words.
    opacity: (row.isEnabled || PaperTheme.isBroadsheet) ? 1 : PaperTheme.pick(0.45, 0.5, 1)
    // The active profile's card takes the accent frame (and, in ledger, the
    // accent wash) — hairline has neither and marks it with the dot alone.
    frameTone: (row.active && !PaperTheme.isHairline) ? "accent" : ""
    color: (row.active && PaperTheme.isLedger) ? PaperTheme.accentWash : (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise)

    PaperRule {
        visible: PaperTheme.isHairline && row.separator
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Rectangle {
        id: marker
        anchors.left: parent.left
        anchors.leftMargin: row.pad + PaperTheme.pick(2, 0, 0)
        anchors.verticalCenter: parent.verticalCenter
        width: row.markerSize
        height: row.markerSize
        // A dot in hairline, a ledger tick box in ledger, a medallion in
        // broadsheet — the three variants' three ways of saying "this one".
        radius: PaperTheme.pick(width / 2, 1, width / 2)
        antialiasing: true
        color: row.active ? (PaperTheme.isLedger ? PaperTheme.accent : PaperTheme.isBroadsheet ? PaperTheme.accent : PaperTheme.ink) : "transparent"
        border.width: PaperTheme.ruleWidth
        border.color: row.active ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : PaperTheme.rule2

        PaperIcon {
            anchors.centerIn: parent
            visible: PaperTheme.isLedger && row.active
            name: "check"
            size: 10
            color: PaperTheme.onAccent
        }
    }

    Column {
        id: text
        anchors.left: marker.right
        anchors.leftMargin: PaperTheme.pick(PaperTheme.spacing.medium, PaperTheme.spacing.sm, PaperTheme.spacing.medium)
        anchors.right: chev.left
        anchors.rightMargin: PaperTheme.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Row {
            width: parent.width
            spacing: PaperTheme.spacing.xs

            PaperText {
                anchors.verticalCenter: parent.verticalCenter
                text: row.profile.name ?? ""
                role: PaperTheme.pick("body", "small", "body")
                tone: row.active && !PaperTheme.isHairline ? "accent" : "ink"
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - suffix.implicitWidth - PaperTheme.spacing.xs)
            }
            PaperText {
                id: suffix
                anchors.verticalCenter: parent.verticalCenter
                visible: row.active || !row.isEnabled
                // Hairline sets the suffix as a micro-cap, ledger as a lowercase
                // micro, broadsheet as a mid-dot footnote in italic.
                text: row.active ? PaperTheme.pick("Active", "active", "· active") : PaperTheme.pick("Disabled", "disabled", "· disabled")
                // A micro-cap in hairline and ledger; a real italic footnote in
                // broadsheet, which is why the role changes rather than the tone.
                role: PaperTheme.isBroadsheet ? "meta" : "micro"
                tone: row.active ? (PaperTheme.isHairline ? "ink2" : "accent") : "ink4"
                footnote: PaperTheme.isBroadsheet
            }
        }

        PaperText {
            width: parent.width
            role: "meta"
            mono: true
            tone: "ink3"
            elide: Text.ElideRight
            // The same syntax the config file uses: `~` = regex, `+` = and,
            // `[…]` = conditions.
            text: {
                const req = row.profile.required ?? [];
                let s = req.length === 0 ? "no required monitors" : req.map(r => (r.regex ? "~" : "") + (r.value || "?")).join("  +  ");
                const c = [];
                if (row.profile.power)
                    c.push(row.profile.power);
                if (row.profile.lid)
                    c.push(row.profile.lid);
                if (row.profile.has_modes && row.profile.static && row.profile.static.mode)
                    c.push("mode:" + row.profile.static.mode);
                // Broadsheet separates the conditions with a mid-dot.
                return c.length ? s + "  [" + c.join(PaperTheme.isBroadsheet ? " · " : ", ") + "]" : s;
            }
        }
    }

    PaperIcon {
        id: chev
        anchors.right: parent.right
        anchors.rightMargin: row.pad
        anchors.verticalCenter: parent.verticalCenter
        name: "chevR"
        size: PaperTheme.icon.row
        color: mouse.containsMouse ? PaperTheme.ink2 : PaperTheme.ink4
    }

    // The row's own hover wash — hairline included, where 4 % is the one ground
    // tint the variant allows.
    Rectangle {
        anchors.fill: parent
        z: -1
        color: mouse.containsMouse ? PaperTheme.wash : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
