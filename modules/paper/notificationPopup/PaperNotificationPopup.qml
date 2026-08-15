pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.paper.common
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PaperNotificationPopup — §4.4 Notification popups of the paper family.
 *
 * One overlay `PanelWindow` on the focused screen, anchored top + right +
 * bottom, `PaperTheme.size.notificationWindow` wide (400 / 368 / 380), visible
 * only while `Notifications.popupList` is non-empty and the screen is not
 * locked. The window is click-through except over the toasts themselves
 * (`mask: Region { item: popupColumn }`), so the desktop underneath keeps every
 * click that does not land on a toast.
 *
 * The stack starts `PaperTheme.size.toastTop` (barHeight + 12/12/16 = 50/46/58)
 * from the top, `PaperTheme.size.toastGap` apart, with toasts
 * `PaperTheme.size.toast` wide (372 / 344 / 356).
 *
 * The window is kept permanently alive and only its `visible` is toggled — the
 * same shape the pixel family uses. There is no focus grab here (a toast never
 * takes keyboard focus) but a live window also avoids re-mapping a layer
 * surface on every notification.
 *
 * Services: `Notifications.popupList` drives the model, `cancelTimeout` on
 * hover, `attemptInvokeAction` on click, `discardNotification` on dismiss. The
 * auto-dismiss timer belongs to the service, not to this surface.
 *
 * No IpcHandler and no GlobalShortcut — this surface is entirely reactive.
 */
Scope {
    id: root

    PanelWindow {
        id: popupWindow

        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:paperNotificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
            top: true
            right: true
            bottom: true
        }

        color: "transparent"
        implicitWidth: PaperTheme.size.notificationWindow

        mask: Region {
            item: popupColumn
        }

        Column {
            id: popupColumn

            anchors {
                top: parent.top
                right: parent.right
                topMargin: PaperTheme.size.toastTop
                rightMargin: PaperTheme.pick(14, 12, 12)
            }
            width: PaperTheme.size.toast
            spacing: PaperTheme.size.toastGap

            Repeater {
                model: Notifications.popupList

                delegate: NotifToast {
                    id: toast
                    required property var modelData

                    width: popupColumn.width
                    notif: toast.modelData
                    onDismissed: {
                        if (toast.modelData)
                            Notifications.discardNotification(toast.modelData.notificationId);
                    }
                }
            }
        }
    }
}
