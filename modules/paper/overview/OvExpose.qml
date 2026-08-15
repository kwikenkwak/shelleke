pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * The workspace exposé — hidden while a query is typed.
 *
 * All of the layout, workspace and drag mechanism is ported from
 * modules/pixel/overview/PixelOverviewWidget.qml unchanged: the same
 * getWsRow / getWsColumn / getWsInCell maths, the same ScriptModel filtering of
 * ToplevelManager by workspace group, the same per-window xOffset / yOffset
 * placement, and the same dispatches — `workspace N` on an empty tile,
 * `focuswindow` on left click, `closewindow` on middle click,
 * `movetoworkspacesilent` when a window is dropped on another tile and
 * `movewindowpixel exact` when a floating one is repositioned in place.
 *
 * The chrome is the only thing that changes:
 *   hairline   — a bare 1 px `rule` outline with the number in mono 11 px
 *                `ink-4` at the top-left; the focused tile's outline and
 *                number go to `ink`. No ring, no fill.
 *   ledger     — a hairline card with the number set in Charter at 40 % of the
 *                tile height, half-opacity: a watermark, not a label. The
 *                focused tile takes a blue hairline plus a 2 px blue underline.
 *   broadsheet — a tinted card with the number in Pagella oldstyle at 36 % of
 *                the tile height; the focused tile takes a 1 px blue keyline
 *                held off the tile by a 2 px paper gap, plus blue corner ticks.
 */
Item {
    id: root
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor(((monitor?.activeWorkspace?.id ?? 1) - 1) / workspacesShown)
    property var windowByAddress: HyprlandData.windowByAddress
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale

    // Paper chrome metrics.
    property real workspaceSpacing: PaperTheme.pick(8, 6, 6)
    property real padding: PaperTheme.pick(20, 12, 12)

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) : ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) : ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)

    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    readonly property int focusedWorkspace: root.monitor?.activeWorkspace?.id ?? 1

    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight

    function getWsRow(ws) {
        var normalRow = Math.floor((ws - 1) / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }
    function getWsColumn(ws) {
        var normalCol = (ws - 1) % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }
    function getWsInCell(ri, ci) {
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) * Config.options.overview.columns + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) + 1;
    }

    PaperPanel {
        id: overviewBackground
        anchors.centerIn: parent
        kind: "sheet"
        // DELIBERATELY not `floating`. PaperPanel's shadow is a MultiEffect,
        // which renders the whole sheet through an offscreen layer — and this
        // sheet contains every live ScreencopyView on the machine. The exposé
        // trades its shadow for keeping the captures on the direct path; the
        // hairline edge and (in C) the corner ticks still frame it.
        floating: false
        ticks: true
        implicitWidth: workspaceColumnLayout.implicitWidth + root.padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + root.padding * 2

        Column {
            id: workspaceColumnLayout
            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: root.workspaceSpacing

            Repeater {
                model: Config.options.overview.rows
                delegate: Row {
                    id: tileRow
                    required property int index
                    spacing: root.workspaceSpacing

                    Repeater {
                        model: Config.options.overview.columns

                        Rectangle {
                            id: workspace
                            required property int index
                            readonly property int colIndex: workspace.index
                            readonly property int workspaceValue: root.workspaceGroup * root.workspacesShown + root.getWsInCell(tileRow.index, workspace.colIndex)
                            property bool hoveredWhileDragging: false
                            readonly property bool focused: workspace.workspaceValue === root.focusedWorkspace

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            radius: PaperTheme.radiusCard
                            antialiasing: radius > 0
                            // A drops the ground entirely (it has no cards); B
                            // raises a sheet; C tints one.
                            color: workspace.hoveredWhileDragging ? (PaperTheme.isHairline ? PaperTheme.wash : PaperTheme.accentWash) : PaperTheme.isBroadsheet ? PaperTheme.paperSunk : PaperTheme.isLedger ? PaperTheme.paperRaise : "transparent"
                            border.width: PaperTheme.ruleWidth
                            // B draws the drop target as a DASHED blue border,
                            // so its solid edge steps aside for the dotted
                            // rules below; A and C keep a solid active edge.
                            border.color: workspace.hoveredWhileDragging ? (PaperTheme.isLedger ? "transparent" : PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent) : PaperTheme.rule

                            Behavior on color {
                                ColorAnimation {
                                    duration: PaperTheme.motion.fast
                                    easing.type: PaperTheme.motion.type
                                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                                }
                            }

                            // The dashed drop-target frame (B only).
                            PaperRule {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                visible: workspace.hoveredWhileDragging && PaperTheme.isLedger
                                dotted: true
                                tone: "accent"
                            }
                            PaperRule {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                visible: workspace.hoveredWhileDragging && PaperTheme.isLedger
                                dotted: true
                                tone: "accent"
                            }
                            PaperRule {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                visible: workspace.hoveredWhileDragging && PaperTheme.isLedger
                                vertical: true
                                dotted: true
                                tone: "accent"
                            }
                            PaperRule {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                visible: workspace.hoveredWhileDragging && PaperTheme.isLedger
                                vertical: true
                                dotted: true
                                tone: "accent"
                            }

                            // The workspace number. A prints a small mono
                            // numeral in the corner; B and C set a watermark
                            // across the tile in the title / figure face.
                            PaperText {
                                visible: PaperTheme.isHairline
                                x: PaperTheme.spacing.small
                                y: PaperTheme.spacing.xs
                                text: workspace.workspaceValue
                                mono: true
                                role: "meta"
                                tone: workspace.focused ? "ink" : "ink4"
                            }
                            PaperText {
                                anchors.centerIn: parent
                                visible: !PaperTheme.isHairline
                                text: workspace.workspaceValue
                                // C's oldstyle figures come from `figure`; B
                                // wants Charter, which is the title face.
                                figure: PaperTheme.isBroadsheet
                                tone: (PaperTheme.isLedger && workspace.focused) ? "accent" : "ink4"
                                opacity: (PaperTheme.isLedger && workspace.focused) ? 0.35 : 0.5
                                font.family: PaperTheme.isBroadsheet ? PaperTheme.fontFigure : PaperTheme.fontTitle
                                font.weight: PaperTheme.font.weight.bold
                                font.pixelSize: Math.max(16, Math.round(workspace.implicitHeight * PaperTheme.pick(0.40, 0.40, 0.355)))
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false;
                                        Hyprland.dispatch(`workspace ${workspace.workspaceValue}`);
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue;
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace)
                                        return;
                                    workspace.hoveredWhileDragging = true;
                                }
                                onExited: {
                                    workspace.hoveredWhileDragging = false;
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue)
                                        root.draggingTargetWorkspace = -1;
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater {
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter(toplevel => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`;
                            var win = root.windowByAddress[address];
                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown);
                            return inWorkspaceGroup;
                        });
                    }
                }
                delegate: OvWindowThumbnail {
                    id: window
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: root.windowByAddress[address]

                    property int workspaceColIndex: root.getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: root.getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + root.workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * root.scale, 0)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(window.xWithinWorkspaceWidget + window.xOffset);
                            window.y = Math.round(window.yWithinWorkspaceWidget + window.yOffset);
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: window.hovered = true
                        onExited: window.hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: mouse => {
                            root.draggingFromWorkspace = window.windowData?.workspace.id;
                            window.pressed = true;
                            window.Drag.active = true;
                            window.Drag.source = window;
                            window.Drag.hotSpot.x = mouse.x;
                            window.Drag.hotSpot.y = mouse.y;
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace;
                            window.pressed = false;
                            window.Drag.active = false;
                            root.draggingFromWorkspace = -1;
                            if (targetWorkspace !== -1 && targetWorkspace !== window.windowData?.workspace.id) {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`);
                                updateWindowPosition.restart();
                            } else {
                                if (!window.windowData.floating) {
                                    updateWindowPosition.restart();
                                    return;
                                }
                                const percentageX = Math.round((window.x - window.xOffset) / root.workspaceImplicitWidth * 100);
                                const percentageY = Math.round((window.y - window.yOffset) / root.workspaceImplicitHeight * 100);
                                Hyprland.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${window.windowData?.address}`);
                            }
                        }
                        onClicked: event => {
                            if (!window.windowData)
                                return;
                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false;
                                Hyprland.dispatch(`focuswindow address:${window.windowData.address}`);
                                event.accepted = true;
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${window.windowData.address}`);
                                event.accepted = true;
                            }
                        }

                        PaperTooltip {
                            visibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: window.windowData?.title ?? ""
                            subtext: `[${window.windowData?.class ?? ""}]`
                        }
                    }
                }
            }

            // The focused-workspace mark. Not a 5 px ring: a hairline in A, a
            // hairline plus a 2 px underline in B, and a printed keyline held
            // off the tile by a paper gap in C. It travels between cells in
            // 140 / 140 / 160 ms and nothing else moves.
            Item {
                id: focusedWorkspaceIndicator
                readonly property int rowIndex: root.getWsRow(root.focusedWorkspace)
                readonly property int colIndex: root.getWsColumn(root.focusedWorkspace)
                x: (root.workspaceImplicitWidth + root.workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + root.workspaceSpacing) * rowIndex
                z: root.windowDraggingZ - 1
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight

                Behavior on x {
                    NumberAnimation {
                        duration: PaperTheme.motion.base
                        easing.type: PaperTheme.motion.type
                        easing.bezierCurve: PaperTheme.motion.bezierCurve
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: PaperTheme.motion.base
                        easing.type: PaperTheme.motion.type
                        easing.bezierCurve: PaperTheme.motion.bezierCurve
                    }
                }

                // A and B: the tile's own outline goes active.
                Rectangle {
                    anchors.fill: parent
                    visible: !PaperTheme.isBroadsheet
                    color: "transparent"
                    radius: PaperTheme.radiusCard
                    antialiasing: radius > 0
                    border.width: PaperTheme.ruleWidth
                    border.color: PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.accent
                }
                // B only: the 2 px blue underline inside the bottom edge.
                PaperRule {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: PaperTheme.ruleWidth
                    anchors.rightMargin: PaperTheme.ruleWidth
                    visible: PaperTheme.isLedger
                    weight: "mark"
                    tone: "accent"
                }

                // C: a 1 px ink-blue keyline, held off the tile by 2 px of
                // paper — a printed keyline, not a glow.
                Rectangle {
                    visible: PaperTheme.isBroadsheet
                    x: -3
                    y: -3
                    width: parent.width + 6
                    height: parent.height + 6
                    color: "transparent"
                    antialiasing: false
                    border.width: PaperTheme.ruleWidth
                    border.color: PaperTheme.link
                }
                Rectangle {
                    visible: PaperTheme.isBroadsheet
                    x: -2
                    y: -2
                    width: parent.width + 4
                    height: parent.height + 4
                    color: "transparent"
                    antialiasing: false
                    border.width: 2
                    border.color: PaperTheme.paper
                }
                // C: blue corner ticks on the focused tile.
                Repeater {
                    model: PaperTheme.ornament.cornerTicks ? 4 : 0
                    delegate: Item {
                        id: tick
                        required property int index
                        readonly property bool atRight: tick.index === 1 || tick.index === 2
                        readonly property bool atBottom: tick.index >= 2
                        x: tick.atRight ? focusedWorkspaceIndicator.width - 4 - 6 : 4
                        y: tick.atBottom ? focusedWorkspaceIndicator.height - 4 - 6 : 4
                        width: 6
                        height: 6
                        Rectangle {
                            x: 0
                            y: tick.atBottom ? 5 : 0
                            width: 6
                            height: 1
                            color: PaperTheme.link
                            antialiasing: false
                        }
                        Rectangle {
                            x: tick.atRight ? 5 : 0
                            y: 0
                            width: 1
                            height: 6
                            color: PaperTheme.link
                            antialiasing: false
                        }
                    }
                }
            }
        }
    }
}
