import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.pixel.common

/**
 * Pixel workspaces: a row of small squares with three distinct states.
 *   - empty (no windows):  hollow 2px-bordered square, dimmed to grey.
 *   - occupied (windows, not focused):  solid filled fg square.
 *   - current (focused):  elongated filled fg pill, ~double width.
 * Clicking a cell switches to that workspace; scrolling cycles workspaces.
 * Occupancy logic mirrors the ii bar.
 */
Item {
    id: root
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property int workspacesShown: 6
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int workspaceGroup: Math.floor((activeId - 1) / workspacesShown)

    property int square: 9
    property int activeWidth: 20   // elongated pill width for the focused workspace
    property int gap: 7

    property list<bool> workspaceOccupied: []

    function baseId(index) { return workspaceGroup * workspacesShown + index + 1; }

    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) =>
            Hyprland.workspaces.values.some(ws => ws.id === root.baseId(i)));
    }

    Component.onCompleted: updateWorkspaceOccupied()
    onWorkspaceGroupChanged: updateWorkspaceOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.updateWorkspaceOccupied(); }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.updateWorkspaceOccupied(); }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 32

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y < 0) Hyprland.dispatch("workspace r+1");
            else if (event.angleDelta.y > 0) Hyprland.dispatch("workspace r-1");
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.workspacesShown

            delegate: Item {
                id: cell
                required property int index
                readonly property int wsId: root.baseId(index)
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: root.workspaceOccupied[index] ?? false

                width: active ? root.activeWidth : root.square
                height: root.square
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation {
                        duration: PixTheme.animation.duration
                        easing.type: PixTheme.animation.type
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    antialiasing: false
                    // current = filled fg pill; occupied = filled fg square;
                    // empty = hollow grey bordered square.
                    color: (cell.active || cell.occupied) ? PixTheme.colors.fg : "transparent"
                    border.width: (cell.active || cell.occupied) ? 0 : 2
                    border.color: cell.occupied ? PixTheme.colors.fg : PixTheme.colors.grey
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3   // easier hit target
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${cell.wsId}`)
                }
            }
        }
    }
}
