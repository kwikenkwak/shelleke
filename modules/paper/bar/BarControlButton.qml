import QtQuick
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * A bare clickable glyph for the bar's controls cluster (region screenshot, the
 * palette toggle). Not a `PaperButton`: the bar's utility glyphs have no label
 * and no resting frame in any of the three variants — they are ink on paper,
 * and hover is the only affordance.
 *
 * Ledger is the one variant whose SPEC gives the control a hover ground
 * (`paper-sunk`, radius 2), so that is gated on `ornament.tintedFills`.
 */
MouseArea {
    id: root

    property string icon: ""
    /// Hover hint. Empty = no tooltip.
    property string tooltipText: ""
    signal triggered

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    implicitWidth: 22
    implicitHeight: 22
    onClicked: root.triggered()

    Rectangle {
        anchors.fill: parent
        visible: PaperTheme.ornament.tintedFills && root.containsMouse
        color: PaperTheme.paperSunk
        radius: PaperTheme.radiusControl
        antialiasing: radius > 0
    }

    PaperIcon {
        anchors.centerIn: parent
        name: root.icon
        size: PaperTheme.icon.control
        color: root.containsMouse ? PaperTheme.ink : PaperTheme.ink2
    }

    PaperTooltip {
        text: root.tooltipText
        visibleCondition: root.containsMouse
    }
}
