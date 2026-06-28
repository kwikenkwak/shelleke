import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common
import Qt.labs.synchronizer
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Pixel-family Overview: workspace exposé grid + launcher search, replacing the
 * reused `modules/ii/overview/Overview.qml`.
 *
 * Structure mirrors the ii overview EXACTLY so the user's keybinds keep working:
 *   - full-screen overlay (one PanelWindow per screen) gated by
 *     GlobalStates.overviewOpen,
 *   - HyprlandFocusGrab + Escape to close,
 *   - the SAME IpcHandler target ("search") and the SAME GlobalShortcut names
 *     (searchToggle, searchToggleRelease, searchToggleReleaseInterrupt,
 *     overviewWorkspacesToggle, overviewWorkspacesClose, overviewClipboardToggle,
 *     overviewEmojiToggle).
 *
 * Only the chrome is restyled to the monochrome pixel idiom: a translucent
 * scrim, a hard-bordered search box on top, and a bordered grid of workspace
 * tiles below (see PixelSearchWidget / PixelOverviewWidget). The emoji shortcut
 * is preserved; clipboard search is reused as-is via the LauncherSearch prefix.
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

            WlrLayershell.namespace: "quickshell:pixelOverview"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

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

            function setSearchingText(text) {
                searchWidget.setSearchingText(text);
                searchWidget.focusFirstItem();
            }

            // Translucent monochrome scrim that also closes on click-through.
            Rectangle {
                anchors.fill: parent
                visible: GlobalStates.overviewOpen
                color: Qt.rgba(PixTheme.colors.bg.r, PixTheme.colors.bg.g, PixTheme.colors.bg.b, 0.45)
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
                    topMargin: Math.round(root.height * 0.12)
                }
                spacing: 18

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

                PixelSearchWidget {
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
                    sourceComponent: PixelOverviewWidget {
                        panelWindow: root
                        visible: (root.searchingText == "")
                    }
                }
            }
        }
    }

    function toggleClipboard() {
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

    function toggleEmojis() {
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

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
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
