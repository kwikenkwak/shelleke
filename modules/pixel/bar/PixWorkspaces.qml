import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Pixel workspaces: a row of square cells, each holding the icon of the
 * representative app running on that workspace. Three distinct states:
 *   - empty (no windows):  hollow grey-bordered cell with a faint number, no icon.
 *   - occupied (windows, not focused):  fg-bordered cell containing the
 *     grayscale app icon (via PixAppIcon, so it contributes no color).
 *   - current (focused):  fg-FILLED cell with a heavier border and the icon,
 *     clearly dominant over the merely-occupied cells.
 * Clicking a cell switches to that workspace; scrolling cycles workspaces.
 * Occupancy/focus logic mirrors the ii bar; window->workspace->icon mapping
 * uses HyprlandData (hyprctl clients) like ii's Workspaces.qml.
 */
Item {
    id: root
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property int workspacesShown: 10
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int workspaceGroup: Math.floor((activeId - 1) / workspacesShown)

    property int cellSize: 24
    property int iconSize: 18
    property int gap: 6

    property list<bool> workspaceOccupied: []

    function baseId(index) { return workspaceGroup * workspacesShown + index + 1; }

    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) =>
            Hyprland.workspaces.values.some(ws => ws.id === root.baseId(i)));
    }

    // Representative app icon name for a workspace, or "" when empty.
    // Uses the biggest window on the workspace (HyprlandData/hyprctl clients),
    // matching the ii bar's window->workspace->class->icon mapping.
    function iconForWorkspace(wsId) {
        const win = HyprlandData.biggestWindowForWorkspace(wsId);
        if (!win || !win.class) return "";
        return AppSearch.guessIcon(win.class);
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
    // Window list changes (open/close/move) should refresh the per-cell icons.
    Connections {
        target: HyprlandData
        function onWindowListChanged() { root.updateWorkspaceOccupied(); }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: cellSize

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
                // Recomputed whenever occupancy/group/window-list updates.
                readonly property string iconName:
                    (root.workspaceOccupied, cell.occupied) ? root.iconForWorkspace(cell.wsId) : ""

                width: root.cellSize
                height: root.cellSize
                anchors.verticalCenter: parent.verticalCenter

                // Keep the fill transparent in all states so the grayscale app
                // icon stays visible (a filled fg cell would hide a dark icon).
                // Distinguish states by border instead:
                //   current  = heavy 3px fg border + inset double border
                //   occupied = 2px fg border
                //   empty    = 2px dim grey border
                Rectangle {
                    id: cellBox
                    anchors.fill: parent
                    antialiasing: false
                    color: "transparent"
                    border.width: cell.active ? 3 : 2
                    border.color: cell.active ? PixTheme.colors.fg
                        : (cell.occupied ? PixTheme.colors.fg : PixTheme.colors.grey)

                    // Inner border (double-border "selected" cue for the focused ws).
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        visible: cell.active
                        antialiasing: false
                        color: "transparent"
                        border.width: 1
                        border.color: PixTheme.colors.fg
                    }
                }

                // App icon for occupied workspaces. PixAppIcon is grayscale so
                // it stays monochrome and visible on the transparent cell.
                PixAppIcon {
                    anchors.centerIn: parent
                    visible: cell.iconName !== ""
                    icon: cell.iconName
                    size: root.iconSize
                    pixelResolution: 16
                }

                // Faint workspace number for empty cells only.
                PixText {
                    anchors.centerIn: parent
                    visible: !cell.occupied
                    text: cell.wsId
                    font.pixelSize: PixTheme.font.pixelSize.smallest
                    color: PixTheme.colors.grey2
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
