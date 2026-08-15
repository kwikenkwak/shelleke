pragma ComponentBehavior: Bound

import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick

/**
 * One session warning (package manager running / download in progress).
 *
 * SURFACE-LOCAL: session-specific. Prefixed `Session…` per the surface-group
 * convention. Its "stamp on a paper backing plate over a dark scrim" trick is
 * a promotion candidate if a second dark-ground surface ever needs a stamp —
 * see HANDOFF §3.
 *
 *   hairline   — has no stamps. A 6 px `alert` dot plus 11 px `alert` text —
 *                one of the handful of places §2.2 permits the hue at all.
 *   ledger     — a PaperStamp: 9 px caps in stamp red on a red wash inside a
 *                red hairline, rotated barely more than a degree so the row
 *                reads as marks pressed onto the page.
 *   broadsheet — the same stamp in sepia, but the scrim there is warm near-black
 *                rather than paper, so the stamp is backed by a paper-white
 *                plate rotated with it. Without the plate a sepia frame on a
 *                72 % dark scrim is unreadable.
 */
Item {
    id: root

    property string text: ""

    /// Broadsheet backs its stamp with a paper plate; the others do not.
    readonly property int backingPad: PaperTheme.isBroadsheet ? 8 : 0

    implicitWidth: PaperTheme.isHairline ? dotRow.implicitWidth : (stamp.implicitWidth + root.backingPad)
    implicitHeight: PaperTheme.isHairline ? dotRow.implicitHeight : (stamp.implicitHeight + root.backingPad)

    // -- hairline: a dot and a line of alert text ---------------------------
    Row {
        id: dotRow
        visible: PaperTheme.isHairline
        anchors.centerIn: parent
        spacing: 9

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: PaperTheme.size.dot
            height: PaperTheme.size.dot
            radius: PaperTheme.size.dot / 2
            antialiasing: true
            color: PaperTheme.alert
        }
        PaperText {
            anchors.verticalCenter: parent.verticalCenter
            role: "meta"
            tone: "alert"
            text: root.text
        }
    }

    // -- ledger / broadsheet: a stamp ---------------------------------------

    // Broadsheet's paper plate under the stamp, rotated with it.
    Rectangle {
        visible: PaperTheme.isBroadsheet
        anchors.centerIn: parent
        width: stamp.implicitWidth + root.backingPad
        height: stamp.implicitHeight + root.backingPad
        rotation: PaperTheme.ornament.stampRotation
        color: Qt.rgba(PaperTheme.paper.r, PaperTheme.paper.g, PaperTheme.paper.b, 0.9)
        antialiasing: false
    }

    PaperStamp {
        id: stamp
        visible: !PaperTheme.isHairline
        anchors.centerIn: parent
        text: root.text
        tone: "seal"
    }
}
