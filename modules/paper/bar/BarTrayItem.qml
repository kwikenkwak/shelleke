import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * One system-tray item. Behaviour is identical to `PixTrayItem`: left click
 * activates, right click opens the item's menu below it, hover shows the
 * tooltip text `TrayService` reports.
 *
 * The icon is a `PaperAppIcon` at `PaperTheme.icon.tray` (15 / 15 / 19 px).
 * Only ledger plates its tray icons; hairline has no plates at all and
 * broadsheet deliberately drops the slot in the bar "so the bar stays airy".
 */
MouseArea {
    id: root
    required property SystemTrayItem item

    readonly property real hitSize: Math.max(20, PaperTheme.icon.tray + PaperTheme.spacing.tiny)

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    implicitWidth: root.hitSize
    implicitHeight: root.hitSize

    onPressed: event => {
        switch (event.button) {
        case Qt.LeftButton:
            root.item?.activate();
            break;
        case Qt.RightButton:
            if (root.item?.hasMenu)
                menu.open();
            break;
        }
        event.accepted = true;
    }

    PaperAppIcon {
        anchors.centerIn: parent
        size: PaperTheme.icon.tray
        plate: PaperTheme.isLedger
        source: root.item?.icon ?? ""
    }

    PaperTooltip {
        text: root.item ? TrayService.getTooltipForItem(root.item) : ""
        visibleCondition: root.containsMouse
    }

    QsMenuAnchor {
        id: menu
        menu: root.item?.menu
        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }
    }
}
