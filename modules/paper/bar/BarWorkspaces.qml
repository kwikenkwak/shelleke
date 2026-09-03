pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * The workspace row. Occupancy, focus, the window → workspace → class → icon
 * mapping, the click-to-switch and the scroll-to-cycle are all lifted verbatim
 * from `PixWorkspaces`; only the marks change.
 *
 *   hairline   — no boxes at all. Occupied = the biggest window's app glyph in
 *                ink-2, empty = its number in mono `ink-4`, focused = a 1 px
 *                `ink` rule 3 px UNDER the cell that slides between cells.
 *   ledger     — every cell sits on one ruled baseline: `rule` when empty,
 *                `rule-2` when occupied, and the focused cell's baseline
 *                THICKENS to 2 px ink blue while the cell takes a blue wash.
 *   broadsheet — one continuous hairline baseline under the whole row; the
 *                focused cell takes a 1 px ink-blue frame, a blue wash and four
 *                blue corner ticks.
 *
 * Nothing inverts and nothing fills, in any variant — the app icons have to
 * stay legible. The mark travels in `PaperTheme.motion.base` (140/140/160 ms),
 * which is the largest movement the family permits.
 */
Item {
    id: root

    /// The screen this bar sits on. Passed IN by PaperBar rather than resolved
    /// through `root.QsWindow.window?.screen`: that attached property
    /// re-resolves on every `windowChanged` in the item tree, including the one
    /// Qt emits while it is tearing the bar down on a config reload — and
    /// reading it then dereferences a half-destroyed item and segfaults inside
    /// QQuickItem::window(). PaperBar already has the ShellScreen in hand, so
    /// there is nothing to resolve. See modules/paper/widgets/PaperTooltip.qml
    /// for the long version of the note.
    required property ShellScreen screen

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
    readonly property int workspacesShown: 10
    readonly property int activeId: root.monitor?.activeWorkspace?.id ?? 1
    readonly property int workspaceGroup: Math.floor((root.activeId - 1) / root.workspacesShown)

    readonly property real cellWidth: PaperTheme.size.workspaceCellWidth
    readonly property real cellHeight: PaperTheme.size.workspaceCellHeight
    readonly property real gap: PaperTheme.size.workspaceGap
    /// Room under the cells for the mark (hairline) or the baseline (broadsheet).
    readonly property real underGap: PaperTheme.pick(4, 0, 4)

    property list<bool> workspaceOccupied: []

    /// Index of the focused cell within the shown group, or -1.
    readonly property int focusedIndex: {
        const i = root.activeId - (root.workspaceGroup * root.workspacesShown) - 1;
        return (i >= 0 && i < root.workspacesShown) ? i : -1;
    }

    function baseId(index: int): int {
        return root.workspaceGroup * root.workspacesShown + index + 1;
    }

    function updateWorkspaceOccupied(): void {
        root.workspaceOccupied = Array.from({
            length: root.workspacesShown
        }, (_, i) => Hyprland.workspaces.values.some(ws => ws.id === root.baseId(i)));
    }

    // Representative app icon for a workspace ("" when empty) — the biggest
    // window on it, via HyprlandData (hyprctl clients) → AppSearch.guessIcon.
    function iconForWorkspace(wsId: int): string {
        const win = HyprlandData.biggestWindowForWorkspace(wsId);
        if (!win || !win.class)
            return "";
        return AppSearch.guessIcon(win.class);
    }

    Component.onCompleted: root.updateWorkspaceOccupied()
    onWorkspaceGroupChanged: root.updateWorkspaceOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged(): void {
            root.updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void {
            root.updateWorkspaceOccupied();
        }
    }
    Connections {
        target: HyprlandData
        function onWindowListChanged(): void {
            root.updateWorkspaceOccupied();
        }
    }

    implicitWidth: root.workspacesShown * root.cellWidth + (root.workspacesShown - 1) * root.gap
    implicitHeight: root.cellHeight + root.underGap

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch("workspace r+1");
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch("workspace r-1");
        }
    }

    // Broadsheet: one continuous hairline baseline under the whole row.
    PaperRule {
        visible: PaperTheme.isBroadsheet
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    // ---- the travelling mark ---------------------------------------------
    // One object for all three variants: a rule under the cell (hairline), the
    // thickened blue baseline plus wash (ledger), or the framed, tick-marked
    // blue cell (broadsheet).
    Item {
        id: mark
        visible: root.focusedIndex >= 0
        width: root.cellWidth
        height: root.cellHeight
        y: 0
        x: root.focusedIndex >= 0 ? root.focusedIndex * (root.cellWidth + root.gap) : 0

        Behavior on x {
            NumberAnimation {
                duration: PaperTheme.motion.base
                easing.type: PaperTheme.motion.type
                easing.bezierCurve: PaperTheme.motion.bezierCurve
            }
        }

        // The wash. Ledger tints with `accentWash`, broadsheet with `linkWash`;
        // hairline has no tinted fills at all, so this simply never draws.
        Rectangle {
            anchors.fill: parent
            visible: PaperTheme.ornament.tintedFills
            color: PaperTheme.isBroadsheet ? PaperTheme.linkWash : PaperTheme.accentWash
            radius: PaperTheme.radiusCard
            antialiasing: radius > 0
            border.width: PaperTheme.isBroadsheet ? PaperTheme.ruleWidth : 0
            border.color: PaperTheme.link
        }

        // Hairline / ledger: the underline. Hairline hangs it 3 px below the
        // cell in `ink`; ledger thickens the baseline itself to 2 px ink blue.
        Rectangle {
            visible: !PaperTheme.isBroadsheet
            x: 0
            y: PaperTheme.isHairline ? root.cellHeight + 3 : root.cellHeight - PaperTheme.markWidth
            width: root.cellWidth
            height: PaperTheme.markWidth
            color: PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent
            antialiasing: false
        }

        // Broadsheet: four ink-blue corner ticks, 4 × 4, hung 1 px outside.
        Repeater {
            model: PaperTheme.ornament.cornerTicks ? 4 : 0
            delegate: Item {
                id: tick
                required property int index
                readonly property bool atRight: tick.index === 1 || tick.index === 2
                readonly property bool atBottom: tick.index >= 2
                x: tick.atRight ? mark.width - 3 : -1
                y: tick.atBottom ? mark.height - 3 : -1
                width: 4
                height: 4
                Rectangle {
                    x: 0
                    y: tick.atBottom ? 3 : 0
                    width: 4
                    height: PaperTheme.ruleWidth
                    color: PaperTheme.link
                    antialiasing: false
                }
                Rectangle {
                    x: tick.atRight ? 3 : 0
                    y: 0
                    width: PaperTheme.ruleWidth
                    height: 4
                    color: PaperTheme.link
                    antialiasing: false
                }
            }
        }
    }

    // ---- the cells --------------------------------------------------------
    Row {
        id: cellRow
        anchors.top: parent.top
        anchors.left: parent.left
        spacing: root.gap

        Repeater {
            model: root.workspacesShown

            delegate: Item {
                id: cell
                required property int index
                readonly property int wsId: root.baseId(cell.index)
                readonly property bool active: root.activeId === cell.wsId
                readonly property bool occupied: root.workspaceOccupied[cell.index] ?? false
                // Recomputed whenever occupancy / group / window list updates.
                readonly property string iconName: (root.workspaceOccupied, cell.occupied) ? root.iconForWorkspace(cell.wsId) : ""

                width: root.cellWidth
                height: root.cellHeight

                // Ledger: each cell carries its own stretch of baseline.
                Rectangle {
                    visible: PaperTheme.isLedger && !cell.active
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: PaperTheme.ruleWidth
                    color: cell.occupied ? PaperTheme.rule2 : PaperTheme.rule
                    antialiasing: false
                }

                PaperAppIcon {
                    anchors.centerIn: parent
                    visible: cell.iconName !== ""
                    icon: cell.iconName
                    size: PaperTheme.pick(16, 14, 17)
                    plate: false
                    fallbackIcon: ""
                }

                // Empty cells show their number instead.
                PaperText {
                    anchors.centerIn: parent
                    visible: cell.iconName === ""
                    text: cell.wsId
                    figure: true
                    tone: cell.active ? "ink3" : "ink4"
                    font.pixelSize: PaperTheme.pick(11, 9, 12)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${cell.wsId}`)
                }
            }
        }
    }
}
