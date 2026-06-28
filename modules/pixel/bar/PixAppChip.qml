import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * A 2px-bordered chip containing pinned/active app icons (desaturated via
 * PixAppIcon). Uses the dock's pinned apps when configured, otherwise falls
 * back to the currently-running apps. Hidden when there's nothing to show.
 */
PixButton {
    id: root
    interactive: false
    fillOnHover: false
    borderWidth: PixTheme.borderWidth

    readonly property var appIds: {
        const pinned = Config.options?.dock?.pinnedApps ?? [];
        if (pinned.length > 0)
            return pinned.slice(0, 6);
        // Fallback: distinct running app ids
        const seen = [];
        for (const entry of (TaskbarApps.apps ?? [])) {
            if (!entry || entry.appId === "separator" || entry.appId === "SEPARATOR") continue;
            if ((entry.toplevels?.length ?? 0) === 0) continue;
            if (!seen.includes(entry.appId)) seen.push(entry.appId);
            if (seen.length >= 6) break;
        }
        return seen;
    }

    visible: appIds.length > 0
    implicitWidth: visible ? (iconRow.implicitWidth + 16) : 0
    implicitHeight: 30

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.appIds
            delegate: PixAppIcon {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                icon: AppSearch.guessIcon(modelData)
                size: 16
            }
        }
    }
}
