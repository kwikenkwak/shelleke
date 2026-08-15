pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.paper.common
import Qt.labs.synchronizer
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PaperOverview — §4.6 Overview / launcher of the paper family.
 *
 *   design/paper-a-hairline/SPEC.md   §4.6   design/paper-b-ledger/SPEC.md §4.5
 *   design/paper-c-broadsheet/SPEC.md §4.6   design/current-pixels/SPEC.md §4.6
 *
 * The window lifecycle, focus-grab hack, IPC target ("search") and all seven
 * GlobalShortcut names are copied from modules/pixel/overview/PixelOverview.qml
 * VERBATIM so the user's Hyprland binds keep working. Only the chrome changes:
 *
 *   hairline   — a bare query line over typographic results; the field's own
 *                1 px underline doubles as the seam to the result list. The
 *                scrim BLEACHES the desktop (paper @ 62 %) instead of dimming.
 *   ledger     — a 560 × 46 ruled field welded to a ruled result table; blue
 *                selection mark; exposé tiles carry a Charter watermark number.
 *   broadsheet — an editorial masthead field (Pagella 21 + oxblood caret) with
 *                corner ticks, and corner-ticked exposé tiles behind a printed
 *                blue keyline on the focused workspace.
 *
 * Everything styling flows through PaperTheme bindings, so `paperVariant cycle`
 * restyles a *running* overview with no reload.
 */
Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    Variants {
        id: overviewVariants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData
            property string searchingText: ""
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            screen: modelData
            visible: GlobalStates.overviewOpen

            WlrLayershell.namespace: "quickshell:paperOverview"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Gotcha #1 in HANDOFF §5.3: the grab only attaches once the window
            // is mapped, and it must only ever grab on the focused monitor.
            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    if (!active)
                        GlobalStates.overviewOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (!GlobalStates.overviewOpen) {
                        searchWidget.disableExpandAnimation();
                        overviewScope.dontAutoCancelSearch = false;
                    } else {
                        if (!overviewScope.dontAutoCancelSearch)
                            searchWidget.cancelSearch();
                        delayedGrabTimer.start();
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return;
                    grab.active = GlobalStates.overviewOpen;
                }
            }

            function setSearchingText(text: string): void {
                searchWidget.setSearchingText(text);
                searchWidget.focusFirstItem();
            }

            // The scrim. A and B BLEACH the desktop (paper at 62 % / 90 %) —
            // the light-mode counterpart of the pixel theme's black wash; C
            // uses a warm dark at 55 %. All three come out of PaperTheme.scrim.
            Rectangle {
                anchors.fill: parent
                visible: GlobalStates.overviewOpen
                color: PaperTheme.scrim
                Behavior on color {
                    ColorAnimation {
                        duration: PaperTheme.motion.fast
                        easing.type: PaperTheme.motion.type
                        easing.bezierCurve: PaperTheme.motion.bezierCurve
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.overviewOpen = false
                }
            }

            Column {
                id: columnLayout
                visible: GlobalStates.overviewOpen
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    // 12 % of screen height in all three variants.
                    topMargin: Math.round(root.height * 0.12)
                }
                spacing: PaperTheme.pick(24, 18, 18)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    } else if (event.key === Qt.Key_Left) {
                        if (!root.searchingText)
                            Hyprland.dispatch("workspace r-1");
                    } else if (event.key === Qt.Key_Right) {
                        if (!root.searchingText)
                            Hyprland.dispatch("workspace r+1");
                    }
                }

                OvSearchWidget {
                    id: searchWidget
                    anchors.horizontalCenter: parent.horizontalCenter
                    Synchronizer on searchingText {
                        property alias source: root.searchingText
                    }
                }

                Loader {
                    id: overviewLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: GlobalStates.overviewOpen && (Config?.options.overview.enable ?? true)
                    sourceComponent: OvExpose {
                        panelWindow: root
                        visible: (root.searchingText == "")
                    }
                }
            }
        }
    }

    function toggleClipboard(): void {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        for (let i = 0; i < overviewVariants.instances.length; i++) {
            let panelWindow = overviewVariants.instances[i];
            if (panelWindow.modelData.name == Hyprland.focusedMonitor.name) {
                overviewScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
                GlobalStates.overviewOpen = true;
                return;
            }
        }
    }

    function toggleEmojis(): void {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        for (let i = 0; i < overviewVariants.instances.length; i++) {
            let panelWindow = overviewVariants.instances[i];
            if (panelWindow.modelData.name == Hyprland.focusedMonitor.name) {
                overviewScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(Config.options.search.prefix.emojis);
                GlobalStates.overviewOpen = true;
                return;
            }
        }
    }

    // Same IPC target and shortcut names as the ii/pixel overviews — only one
    // panel family is loaded at a time, so they can never collide at runtime.
    IpcHandler {
        target: "search"

        function toggle(): void {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle(): void {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close(): void {
            GlobalStates.overviewOpen = false;
        }
        function open(): void {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt(): void {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle(): void {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"
        onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"
        onPressed: GlobalStates.overviewOpen = false
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"
        onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"
        onPressed: GlobalStates.superReleaseMightTrigger = true
        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."
        onPressed: GlobalStates.superReleaseMightTrigger = false
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"
        onPressed: overviewScope.toggleClipboard()
    }
    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"
        onPressed: overviewScope.toggleEmojis()
    }
}
