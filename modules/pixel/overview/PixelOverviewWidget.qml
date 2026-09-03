pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Workspace exposé grid for the pixel overview.
 *
 * The whole layout/positioning/drag mechanism is ported from
 * `modules/ii/overview/OverviewWidget.qml`: same row/column workspace math
 * (getWsRow/getWsColumn/getWsInCell), same ScriptModel window filtering by
 * workspace group, same per-window xOffset/yOffset placement, same drag-to-move
 * (movetoworkspacesilent / movewindowpixel) and click-to-focus dispatches.
 *
 * Restyled to the monochrome pixel idiom: workspace tiles are hard-edged
 * (radius 0) bordered rectangles, numbered in Silkscreen (PixTitle), and the
 * focused workspace gets a heavy double-thickness border. No rounding, shadows
 * or accent colors.
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

    // Pixel chrome metrics
    property int tileBorder: PixTheme.borderWidth
    property int focusedBorder: PixTheme.popupBorderWidth + 2
    property real workspaceSpacing: 6
    property real padding: 12

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ?
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ?
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)

    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingFromSpecial: ""
    property string draggingTargetSpecial: ""

    // Special workspaces (scratchpads): a centered row of workspace-sized
    // hard-edged tiles floating below the panel — the space beside them stays
    // transparent. Hyprland only lists the ones that exist (= have windows).
    readonly property var specialWorkspaces: HyprlandData.workspaces.filter(ws => ws.id < 0).sort((a, b) => a.name.localeCompare(b.name))
    readonly property bool hasSpecials: specialWorkspaces.length > 0

    function specialDisplayName(wsName) {
        // The purposes are fixed (see hypr/custom/keybinds.conf).
        const bare = wsName.startsWith("special:") ? wsName.slice("special:".length) : wsName;
        const fixedNames = { web: "Browser", music: "Spotify", slack: "Slack" };
        if (fixedNames[bare] !== undefined) return fixedNames[bare];
        if (bare === "" || bare === "special") return "Scratchpad";
        return bare.charAt(0).toUpperCase() + bare.slice(1);
    }
    function specialToggleDispatch(wsName) {
        const bare = wsName.startsWith("special:") ? wsName.slice("special:".length) : "";
        return (bare === "" || bare === "special") ? "togglespecialworkspace" : `togglespecialworkspace ${bare}`;
    }

    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight + (root.hasSpecials ? root.workspaceImplicitHeight + root.padding * 2 + root.workspaceSpacing * 2 : 0)

    function getWsRow(ws) {
        var normalRow = Math.floor((ws - 1) / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }
    function getWsColumn(ws) {
        var normalCol = (ws - 1) % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }
    function getWsInCell(ri, ci) {
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) * Config.options.overview.columns
            + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) + 1;
    }

    PixPanel { // Background — hard-edged bordered container
        id: overviewBackground
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        borderWidth: PixTheme.popupBorderWidth
        implicitWidth: workspaceColumnLayout.implicitWidth + root.padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + root.padding * 2

        Column { // Workspace tiles
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
                        Rectangle { // Workspace tile
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown
                                + root.getWsInCell(tileRow.index, colIndex)
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            radius: 0
                            antialiasing: false
                            color: hoveredWhileDragging
                                ? Qt.rgba(PixTheme.colors.line.r, PixTheme.colors.line.g, PixTheme.colors.line.b, 0.12)
                                : "transparent"
                            border.width: root.tileBorder
                            border.color: hoveredWhileDragging ? PixTheme.colors.fg : PixTheme.colors.grey2

                            PixTitle { // Workspace number (Silkscreen)
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                color: PixTheme.colors.grey2
                                font.pixelSize: Math.max(16, Math.round(workspace.implicitHeight * 0.4))
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

        PixPanel { // Special workspaces panel — same chrome as the main block
            id: specialBackground
            visible: root.hasSpecials
            anchors.top: parent.bottom
            anchors.topMargin: root.workspaceSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            borderWidth: PixTheme.popupBorderWidth
            implicitWidth: specialRow.implicitWidth + root.padding * 2
            implicitHeight: specialRow.implicitHeight + root.padding * 2

            Row {
                id: specialRow
                anchors.centerIn: parent
                spacing: root.workspaceSpacing

            Repeater {
                model: root.specialWorkspaces
                delegate: Rectangle { // Special workspace tile
                    id: specialTile
                    required property var modelData
                    readonly property string wsName: modelData.name
                    readonly property bool isOpen: root.monitorData?.specialWorkspace?.name === specialTile.wsName
                    property bool hoveredWhileDragging: false

                    implicitWidth: root.workspaceImplicitWidth
                    implicitHeight: root.workspaceImplicitHeight
                    radius: 0
                    antialiasing: false
                    color: hoveredWhileDragging
                        ? Qt.rgba(PixTheme.colors.line.r, PixTheme.colors.line.g, PixTheme.colors.line.b, 0.12)
                        : "transparent"
                    border.width: specialTile.isOpen ? root.focusedBorder : root.tileBorder
                    border.color: (hoveredWhileDragging || specialTile.isOpen) ? PixTheme.colors.fg : PixTheme.colors.grey2

                    PixTitle { // Name — same treatment as the workspace numbers (Silkscreen)
                        anchors.centerIn: parent
                        text: root.specialDisplayName(specialTile.wsName)
                        color: PixTheme.colors.grey2
                        font.pixelSize: Math.max(12, Math.round(specialTile.implicitHeight * 0.16))
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: {
                            if (root.draggingTargetWorkspace === -1 && root.draggingTargetSpecial === "") {
                                GlobalStates.overviewOpen = false;
                                Hyprland.dispatch(root.specialToggleDispatch(specialTile.wsName));
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            root.draggingTargetSpecial = specialTile.wsName;
                            if (root.draggingFromSpecial === specialTile.wsName)
                                return;
                            specialTile.hoveredWhileDragging = true;
                        }
                        onExited: {
                            specialTile.hoveredWhileDragging = false;
                            if (root.draggingTargetSpecial === specialTile.wsName)
                                root.draggingTargetSpecial = "";
                        }
                    }

                    Repeater { // Windows on this special workspace
                        model: ScriptModel {
                            values: ToplevelManager.toplevels.values.filter((toplevel) => {
                                const address = `0x${toplevel.HyprlandToplevel?.address}`;
                                return root.windowByAddress[address]?.workspace?.name === specialTile.wsName;
                            })
                        }
                        delegate: PixelOverviewWindow {
                            id: specialWindow
                            required property var modelData
                            property int monitorId: windowData?.monitor
                            property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                            property var address: `0x${modelData.HyprlandToplevel.address}`
                            toplevel: modelData
                            monitorData: this.monitor
                            scale: root.scale
                            widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                            windowData: root.windowByAddress[address]

                            Timer {
                                id: resetSpecialWindowPosition
                                interval: Config.options.hacks.arbitraryRaceConditionDelay
                                repeat: false
                                running: false
                                onTriggered: {
                                    specialWindow.x = specialWindow.initX;
                                    specialWindow.y = specialWindow.initY;
                                }
                            }

                            z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating)
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            MouseArea {
                                id: specialDragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: specialWindow.hovered = true
                                onExited: specialWindow.hovered = false
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                drag.target: parent
                                onPressed: (mouse) => {
                                    root.draggingFromWorkspace = specialWindow.windowData?.workspace.id;
                                    root.draggingFromSpecial = specialTile.wsName;
                                    specialWindow.pressed = true;
                                    specialWindow.Drag.active = true;
                                    specialWindow.Drag.source = specialWindow;
                                    specialWindow.Drag.hotSpot.x = mouse.x;
                                    specialWindow.Drag.hotSpot.y = mouse.y;
                                }
                                onReleased: {
                                    const targetWorkspace = root.draggingTargetWorkspace;
                                    const targetSpecial = root.draggingTargetSpecial;
                                    specialWindow.pressed = false;
                                    specialWindow.Drag.active = false;
                                    root.draggingFromWorkspace = -1;
                                    root.draggingFromSpecial = "";
                                    if (targetWorkspace !== -1) {
                                        Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${specialWindow.windowData?.address}`);
                                    } else if (targetSpecial !== "" && targetSpecial !== specialTile.wsName) {
                                        Hyprland.dispatch(`movetoworkspacesilent ${targetSpecial}, address:${specialWindow.windowData?.address}`);
                                    }
                                    resetSpecialWindowPosition.restart();
                                }
                                onClicked: (event) => {
                                    if (!specialWindow.windowData)
                                        return;
                                    if (event.button === Qt.LeftButton) {
                                        GlobalStates.overviewOpen = false;
                                        Hyprland.dispatch(`focuswindow address:${specialWindow.windowData.address}`);
                                        event.accepted = true;
                                    } else if (event.button === Qt.MiddleButton) {
                                        Hyprland.dispatch(`closewindow address:${specialWindow.windowData.address}`);
                                        event.accepted = true;
                                    }
                                }

                                PixTooltip {
                                    visibleCondition: specialDragArea.containsMouse && !specialWindow.Drag.active
                                    text: `${specialWindow.windowData?.title ?? ""}\n[${specialWindow.windowData?.class ?? ""}]`
                                }
                            }
                        }
                    }
                }
            }
            }
        }

        Item { // Windows + focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`;
                            var win = root.windowByAddress[address];
                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id
                                && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown);
                            return inWorkspaceGroup;
                        });
                    }
                }
                delegate: PixelOverviewWindow {
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
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = window.windowData?.workspace.id;
                            window.pressed = true;
                            window.Drag.active = true;
                            window.Drag.source = window;
                            window.Drag.hotSpot.x = mouse.x;
                            window.Drag.hotSpot.y = mouse.y;
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace;
                            const targetSpecial = root.draggingTargetSpecial;
                            window.pressed = false;
                            window.Drag.active = false;
                            root.draggingFromWorkspace = -1;
                            if (targetSpecial !== "") {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetSpecial}, address:${window.windowData?.address}`);
                                updateWindowPosition.restart();
                            } else if (targetWorkspace !== -1 && targetWorkspace !== window.windowData?.workspace.id) {
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
                        onClicked: (event) => {
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

                        PixTooltip {
                            visibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${window.windowData?.title ?? ""}\n[${window.windowData?.class ?? ""}]`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator — heavy double border
                id: focusedWorkspaceIndicator
                property int rowIndex: root.getWsRow(root.monitor?.activeWorkspace?.id)
                property int colIndex: root.getWsColumn(root.monitor?.activeWorkspace?.id)
                x: (root.workspaceImplicitWidth + root.workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + root.workspaceSpacing) * rowIndex
                z: root.windowDraggingZ - 1
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                radius: 0
                antialiasing: false
                color: "transparent"
                border.width: root.focusedBorder
                border.color: PixTheme.colors.fg
                Behavior on x {
                    NumberAnimation { duration: PixTheme.animation.duration; easing.type: PixTheme.animation.type }
                }
                Behavior on y {
                    NumberAnimation { duration: PixTheme.animation.duration; easing.type: PixTheme.animation.type }
                }
            }
        }
    }
}
