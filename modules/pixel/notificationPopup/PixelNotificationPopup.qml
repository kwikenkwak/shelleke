import qs
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PixelNotificationPopup — top-right stack of monochrome toast popups.
 *
 * Driven by the Notifications service (Notifications.popupList). Loader/gating
 * mirror modules/ii/notificationPopup/NotificationPopup.qml: visible only while
 * there are popups and the screen isn't locked; window is click-through except
 * over the toasts (mask). Each toast is a PixelNotificationItem; the service's
 * own timer auto-dismisses, hover pauses it, click dismisses.
 */
Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:pixelNotificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        anchors {
            top: true
            right: true
            bottom: true
        }

        color: "transparent"
        implicitWidth: 380

        mask: Region {
            item: popupColumn
        }

        Column {
            id: popupColumn
            anchors {
                top: parent.top
                right: parent.right
                topMargin: PixTheme.barHeight + 12
                rightMargin: 12
            }
            width: parent.width - 24
            spacing: 10

            Repeater {
                model: Notifications.popupList

                delegate: PixelNotificationItem {
                    required property var modelData
                    width: popupColumn.width
                    notif: modelData
                    onDismissed: {
                        if (modelData)
                            Notifications.discardNotification(modelData.notificationId);
                    }
                }
            }
        }
    }
}
