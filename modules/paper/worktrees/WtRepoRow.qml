pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * One candidate repo in the "New worktree" dialog: a check for "make a worktree
 * of this repo" and, once selected, a chip per vitulina server for "open a
 * `vitulina up` tab for it". Clicking anywhere on the row toggles the repo.
 *
 *   hairline   — a bare row separated by a hairline; selecting it takes the
 *                standard left ink gutter (the change bar) and only then reveals
 *                the server chips, which are a free row of underlined words.
 *   ledger     — a card whose selected state is the blue frame over the blue
 *                wash, unfolding a three-column grid of server chips.
 *   broadsheet — a card whose selected state is the oxblood frame; the selected
 *                repo is the only card with one.
 */
PaperPanel {
    id: root

    property string repo: ""
    property var servers: []
    property bool selected: false
    property var pickedServers: []
    /// Hairline separates rows with a rule rather than framing them.
    property bool separator: true

    signal toggled
    signal serverToggled(string server)

    readonly property real cardPad: PaperTheme.pick(0, 8, 9)
    readonly property real gutter: PaperTheme.changeBarIndent

    kind: "card"
    implicitHeight: content.implicitHeight + 2 * PaperTheme.pick(PaperTheme.spacing.medium, 8, 9)
    frameTone: root.selected ? "accent" : ""
    color: (root.selected && PaperTheme.isLedger) ? PaperTheme.accentWash : (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.paperRaise)

    PaperRule {
        visible: PaperTheme.isHairline && root.separator
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Hairline's selected marker: a 1 px ink change bar in the left margin, the
    // same gutter the list rows use everywhere else in the family.
    Rectangle {
        visible: PaperTheme.isHairline && root.selected
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: PaperTheme.spacing.small
        anchors.bottomMargin: PaperTheme.spacing.small
        width: PaperTheme.changeBarWidth
        color: PaperTheme.ink
        antialiasing: false
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.cardPad + (PaperTheme.isHairline && root.selected ? root.gutter : 0)
        anchors.rightMargin: root.cardPad
        spacing: PaperTheme.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.pick(PaperTheme.spacing.large, PaperTheme.spacing.sm, PaperTheme.spacing.sm)

            PaperCheck {
                checked: root.selected
                onToggled: root.toggled()
            }
            PaperText {
                Layout.fillWidth: true
                text: root.repo
                role: PaperTheme.pick("body", "small", "body")
                tone: root.selected && !PaperTheme.isHairline ? "accent" : (root.selected ? "ink" : "ink2")
                elide: Text.ElideRight
            }
            PaperText {
                // "4 srv" / "no servers" — ledger writes the empty case as a
                // bare em dash, which is what its ledger columns do elsewhere.
                text: root.servers.length > 0 ? (root.servers.length + " srv") : PaperTheme.pick("no servers", "—", "no srv")
                role: "meta"
                mono: true
                tone: "ink3"
            }
        }

        // The servers. A free-flowing row of words in hairline; a real
        // three-column grid in the other two, where a chip has bounds.
        GridLayout {
            Layout.fillWidth: true
            visible: root.selected && root.servers.length > 0
            columns: PaperTheme.isHairline ? 4 : 3
            columnSpacing: PaperTheme.pick(PaperTheme.spacing.xxl, 5, 6)
            rowSpacing: PaperTheme.pick(PaperTheme.spacing.medium, 5, 6)

            Repeater {
                model: root.servers

                delegate: PaperChip {
                    required property string modelData

                    Layout.fillWidth: !PaperTheme.isHairline
                    label: modelData
                    tick: true
                    checked: root.pickedServers.indexOf(modelData) >= 0
                    onClicked: root.serverToggled(modelData)
                }
            }
        }

        PaperText {
            Layout.fillWidth: true
            visible: root.selected && root.servers.length === 0
            text: "no vitulina servers — gets a shell tab"
            role: "meta"
            tone: "ink4"
            footnote: true
        }
    }

    // Clicking anywhere on the row (outside the chips) toggles the repo.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
