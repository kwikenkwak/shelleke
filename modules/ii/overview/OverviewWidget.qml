pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingFromSpecial: ""
    property string draggingTargetSpecial: ""

    // Special workspaces (scratchpads): shown as a centered row of
    // workspace-sized tiles below the panel, floating on nothing — the space
    // beside them stays transparent. Only ones that exist (= have windows)
    // are listed by Hyprland.
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

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + (root.hasSpecials ? root.workspaceImplicitHeight + overviewBackground.padding * 2 + root.workspaceSpacing * 2 : 0)

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []
    
    function getWsRow(ws) {
        // 1-indexed workspace, 0-indexed row
        var normalRow = Math.floor((ws - 1) / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }
    function getWsColumn(ws) {
        // 1-indexed workspace, 0-indexed column
        var normalCol = (ws - 1) % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }
    function getWsInCell(ri, ci) {
        // 1-indexed workspace, 0-indexed row and column index
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) * Config.options.overview.columns + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) + 1
    }

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.top: parent.top
        anchors.topMargin: Appearance.sizes.elevationMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: implicitWidth
        height: implicitHeight

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Column { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: Config.options.overview.rows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.columns
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown + getWsInCell(row.index, colIndex)
                            property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === Config.options.overview.rows - 1
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`workspace ${workspace.workspaceValue}`)
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }

                        }
                    }
                }
            }
        }

        StyledRectangularShadow {
            target: specialBackground
            visible: root.hasSpecials
        }
        Rectangle { // Special workspaces panel — same chrome as the main block
            id: specialBackground
            visible: root.hasSpecials
            anchors.top: parent.bottom
            anchors.topMargin: root.workspaceSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: implicitWidth
            height: implicitHeight
            implicitWidth: specialRow.implicitWidth + overviewBackground.padding * 2
            implicitHeight: specialRow.implicitHeight + overviewBackground.padding * 2
            radius: root.largeWorkspaceRadius + overviewBackground.padding
            color: Appearance.colors.colBackgroundSurfaceContainer

            Row {
                id: specialRow
                anchors.centerIn: parent
                spacing: root.workspaceSpacing

            Repeater {
                model: root.specialWorkspaces
                delegate: Rectangle { // Special workspace tile
                    id: specialTile
                    required property var modelData
                    required property int index
                    readonly property string wsName: modelData.name
                    readonly property bool isOpen: root.monitorData?.specialWorkspace?.name === specialTile.wsName
                    property bool hoveredWhileDragging: false

                    implicitWidth: root.workspaceImplicitWidth
                    implicitHeight: root.workspaceImplicitHeight
                    property bool tileAtLeft: specialTile.index === 0
                    property bool tileAtRight: specialTile.index === root.specialWorkspaces.length - 1
                    topLeftRadius: specialTile.tileAtLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomLeftRadius: specialTile.tileAtLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    topRightRadius: specialTile.tileAtRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomRightRadius: specialTile.tileAtRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    color: hoveredWhileDragging ? ColorUtils.mix(Appearance.colors.colSurfaceContainerLow, Appearance.colors.colLayer1Hover, 0.1) : Appearance.colors.colSurfaceContainerLow
                    border.width: 2
                    border.color: hoveredWhileDragging ? Appearance.colors.colLayer2Hover : specialTile.isOpen ? root.activeBorderColor : "transparent"

                    StyledText { // Name — same treatment as the workspace numbers
                        anchors.centerIn: parent
                        text: root.specialDisplayName(specialTile.wsName)
                        font {
                            pixelSize: root.workspaceNumberSize * root.scale * 0.6
                            weight: Font.DemiBold
                            family: Appearance.font.family.expressive
                        }
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: {
                            if (root.draggingTargetWorkspace === -1 && root.draggingTargetSpecial === "") {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(root.specialToggleDispatch(specialTile.wsName))
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            root.draggingTargetSpecial = specialTile.wsName
                            if (root.draggingFromSpecial === specialTile.wsName) return;
                            specialTile.hoveredWhileDragging = true
                        }
                        onExited: {
                            specialTile.hoveredWhileDragging = false
                            if (root.draggingTargetSpecial === specialTile.wsName) root.draggingTargetSpecial = ""
                        }
                    }

                    Repeater { // Windows on this special workspace
                        model: ScriptModel {
                            values: ToplevelManager.toplevels.values.filter((toplevel) => {
                                const address = `0x${toplevel.HyprlandToplevel?.address}`
                                return root.windowByAddress[address]?.workspace?.name === specialTile.wsName
                            })
                        }
                        delegate: OverviewWindow {
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
                            topLeftRadius: Appearance.rounding.small
                            topRightRadius: Appearance.rounding.small
                            bottomLeftRadius: Appearance.rounding.small
                            bottomRightRadius: Appearance.rounding.small

                            Timer {
                                id: resetSpecialWindowPosition
                                interval: Config.options.hacks.arbitraryRaceConditionDelay
                                repeat: false
                                running: false
                                onTriggered: {
                                    specialWindow.x = specialWindow.initX
                                    specialWindow.y = specialWindow.initY
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
                                    root.draggingFromWorkspace = specialWindow.windowData?.workspace.id
                                    root.draggingFromSpecial = specialTile.wsName
                                    specialWindow.pressed = true
                                    specialWindow.Drag.active = true
                                    specialWindow.Drag.source = specialWindow
                                    specialWindow.Drag.hotSpot.x = mouse.x
                                    specialWindow.Drag.hotSpot.y = mouse.y
                                }
                                onReleased: {
                                    const targetWorkspace = root.draggingTargetWorkspace
                                    const targetSpecial = root.draggingTargetSpecial
                                    specialWindow.pressed = false
                                    specialWindow.Drag.active = false
                                    root.draggingFromWorkspace = -1
                                    root.draggingFromSpecial = ""
                                    if (targetWorkspace !== -1) {
                                        Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${specialWindow.windowData?.address}`)
                                    } else if (targetSpecial !== "" && targetSpecial !== specialTile.wsName) {
                                        Hyprland.dispatch(`movetoworkspacesilent ${targetSpecial}, address:${specialWindow.windowData?.address}`)
                                    }
                                    resetSpecialWindowPosition.restart()
                                }
                                onClicked: (event) => {
                                    if (!specialWindow.windowData) return;
                                    if (event.button === Qt.LeftButton) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`focuswindow address:${specialWindow.windowData.address}`)
                                        event.accepted = true
                                    } else if (event.button === Qt.MiddleButton) {
                                        Hyprland.dispatch(`closewindow address:${specialWindow.windowData.address}`)
                                        event.accepted = true
                                    }
                                }

                                StyledToolTip {
                                    extraVisibleCondition: false
                                    alternativeVisibleCondition: specialDragArea.containsMouse && !specialWindow.Drag.active
                                    text: `${specialWindow.windowData?.title}\n[${specialWindow.windowData?.class}] ${specialWindow.windowData?.xwayland ? "[XWayland] " : ""}`
                                }
                            }
                        }
                    }
                }
            }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        // console.log(JSON.stringify(ToplevelManager.toplevels.values.map(t => t), null, 2))
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            var win = windowByAddress[address]
                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown)
                            return inWorkspaceGroup;
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: windowByAddress[address]

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceColIndex: getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === Config.options.overview.columns - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === Config.options.overview.rows - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(xWithinWorkspaceWidget + xOffset)
                            window.y = Math.round(yWithinWorkspaceWidget + yOffset)
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace.id
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                            // console.log(`[OverviewWindow] Dragging window ${windowData?.address} from position (${window.x}, ${window.y})`)
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            const targetSpecial = root.draggingTargetSpecial
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            if (targetSpecial !== "") {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetSpecial}, address:${window.windowData?.address}`)
                                updateWindowPosition.restart()
                            }
                            else if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`)
                                updateWindowPosition.restart()
                            }
                            else {
                                if (!window.windowData.floating) {
                                    updateWindowPosition.restart()
                                    return
                                }
                                const percentageX = Math.round((window.x - xOffset) / root.workspaceImplicitWidth * 100)
                                const percentageY = Math.round((window.y - yOffset) / root.workspaceImplicitHeight * 100)
                                Hyprland.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${window.windowData?.address}`)
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title}\n[${windowData?.class}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(monitor.activeWorkspace?.id)
                property int colIndex: getWsColumn(monitor.activeWorkspace?.id)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                property bool workspaceAtLeft: colIndex === 0
                property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                property bool workspaceAtTop: rowIndex === 0
                property bool workspaceAtBottom: rowIndex === Config.options.overview.rows - 1
                topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on topLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on topRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
            }
        }
    }
}
