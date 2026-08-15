import QtQuick
import qs.modules.paper.common

/**
 * A settings row that carries its own state: glyph, title over a status line,
 * and a SWITCH or a CHEVRON at the right. Replaces the pixel family's 46 px
 * bordered `PixToggleTile` wherever a variant lays its toggles out as rows.
 *
 *   PaperToggleRow {
 *       width: parent.width
 *       icon: "coffee"; title: "Keep awake"
 *       status: idleToggle.toggled ? "Idle inhibited" : "Idle allowed"
 *       on: idleToggle.toggled
 *       tooltip: "Keep system awake"
 *       onToggled: idleToggle.mainAction()
 *   }
 *   PaperToggleRow {
 *       icon: "wifi"; title: "Internet"; status: Network.networkName
 *       on: connected; control: "chevron"
 *       onActivated: overlay = "wifi"
 *   }
 *
 * The height is `PaperTheme.size.toggleRow` — 56 px in hairline, where these
 * rows replace a whole grid of bordered tiles, and 42/48 px in the other two.
 *
 * The switch does NOT flip itself: `on` is the caller's state, because every
 * real toggle in this shell is a round-trip through a service. Clicking a
 * switch row anywhere fires `toggled`, so the entire band is the hit target; a
 * chevron row fires `activated` instead, because it navigates.
 *
 * Extends PaperListRow, so it inherits the hover wash, the change bar, the
 * separator, the tooltip and the ink policy. Children go into the trailing
 * slot, before the switch/chevron.
 */
PaperListRow {
    id: row

    /// switch | chevron | none
    property string control: "switch"
    /// The status line. An alias of PaperListRow's `subtitle`, spelled the way
    /// all four SPECs spell it.
    property alias status: row.subtitle

    /// Fired by the switch, and by a click anywhere on a switch row.
    signal toggled

    minHeight: PaperTheme.size.toggleRow

    onActivated: {
        if (row.control === "switch")
            row.toggled();
    }

    PaperSwitch {
        anchors.verticalCenter: parent.verticalCenter
        visible: row.control === "switch"
        checked: row.on
        connected: row.connected
        onToggled: row.toggled()
    }

    PaperIcon {
        anchors.verticalCenter: parent.verticalCenter
        visible: row.control === "chevron"
        name: "chevR"
        size: PaperTheme.icon.row
        color: row.hovered ? PaperTheme.ink : PaperTheme.ink3
    }
}
