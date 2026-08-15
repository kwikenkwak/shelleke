pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * One existing task in the reopen list. Click it to get that task's kitty window
 * back with the tabs it was created with — no fetch, no install, no touching the
 * working copies (see worktree-setup.py's `open`).
 *
 * The manuscript change-bar idiom: hover takes the 4 % wash in all three
 * variants, plus a 2 px accent bar in the left margin and an italic title in
 * broadsheet. Ledger prefixes the row with a `branch` glyph.
 */
Item {
    id: root

    property string task: ""
    property var repos: []
    property int tabCount: 0

    signal activated

    readonly property bool hovered: mouse.containsMouse && root.enabled

    implicitHeight: PaperTheme.pick(38, 32, 34)

    Rectangle {
        anchors.fill: parent
        color: root.hovered ? (PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.wash) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: PaperTheme.motion.fast
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }
    }

    // The change bar. Broadsheet marks a hovered row in the margin the way a
    // proof-reader marks a changed line.
    Rectangle {
        visible: PaperTheme.isBroadsheet && root.hovered
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: PaperTheme.changeBarWidth
        color: PaperTheme.accent
        antialiasing: false
    }

    // Hairline and ledger rule between their rows (ledger's reopen list is one
    // card of hairline-ruled rows); broadsheet separates by ground alone.
    PaperRule {
        visible: !PaperTheme.isBroadsheet
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: PaperTheme.pick(0, PaperTheme.spacing.small, PaperTheme.spacing.small)
        anchors.rightMargin: PaperTheme.pick(0, PaperTheme.spacing.small, PaperTheme.spacing.small)
        spacing: PaperTheme.pick(PaperTheme.spacing.large, PaperTheme.spacing.sm, PaperTheme.spacing.sm)

        PaperIcon {
            visible: PaperTheme.isLedger
            name: "branch"
            size: PaperTheme.icon.row
            color: PaperTheme.ink3
        }
        PaperText {
            Layout.maximumWidth: PaperTheme.pick(170, 150, 150)
            text: root.task
            role: PaperTheme.pick("body", "small", "body")
            elide: Text.ElideRight
            font.italic: PaperTheme.isBroadsheet && root.hovered
        }
        PaperText {
            Layout.fillWidth: true
            Layout.maximumWidth: PaperTheme.pick(999, 999, 150)
            text: root.repos.join(", ")
            role: "meta"
            tone: "ink3"
            elide: Text.ElideRight
        }
        PaperText {
            visible: root.tabCount > 0
            text: root.tabCount + " tabs"
            role: "meta"
            mono: !PaperTheme.isBroadsheet
            footnote: PaperTheme.isBroadsheet
            tone: "ink4"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
