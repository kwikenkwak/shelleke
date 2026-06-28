import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Top bar for the monochrome pixel-art panel family.
 *
 * Structure mirrors `modules/ii/bar/Bar.qml`: a Scope with Variants over screens,
 * each a top-anchored PanelWindow that reserves `PixTheme.barHeight` of exclusive
 * zone and is visible while the bar is open and the screen isn't locked.
 *
 * The window itself is transparent; the bar is drawn as a bg-filled row with a
 * single 3px bottom border line (a separate Rectangle, since PixPanel borders
 * all four sides). Everything reads from PixTheme so light/dark mode track the
 * shell-wide dark mode toggle automatically.
 */
Scope {
    id: bar

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barRoot
            required property ShellScreen modelData
            screen: modelData

            visible: GlobalStates.barOpen && !GlobalStates.screenLocked

            WlrLayershell.namespace: "quickshell:pixelBar"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: PixTheme.barHeight
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: PixTheme.barHeight

            // Bar background fill
            Rectangle {
                id: barBackground
                anchors.fill: parent
                color: PixTheme.colors.bg
                antialiasing: false

                // 3px bottom border line only
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: PixTheme.barBorderWidth
                    color: PixTheme.colors.line
                    antialiasing: false
                }

                // ---- Bar content row ----
                Item {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                        bottomMargin: PixTheme.barBorderWidth
                    }

                    // LEFT cluster: active window, divider, stats
                    Row {
                        id: leftCluster
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        PixActiveWindow {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PixBarDivider {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PixStats {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // CENTER cluster: workspaces (app icons now live inside the
                    // workspace cells, so the standalone app chip is gone).
                    PixWorkspaces {
                        id: centerCluster
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // RIGHT cluster: clock, controls, tray
                    Row {
                        id: rightCluster
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        PixClock {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        PixBarDivider {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Controls: fullscreen, OSK, dark mode, battery chip
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 13

                            PixControlButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "fullscreen"
                                active: true
                                tooltipText: "Fullscreen"
                                onTriggered: Hyprland.dispatch("fullscreen")
                            }
                            PixControlButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "keyboard"
                                active: GlobalStates.oskOpen
                                tooltipText: "On-screen keyboard"
                                onTriggered: GlobalStates.oskOpen = !GlobalStates.oskOpen
                            }
                            PixControlButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "sun"
                                active: !PixTheme.dark   // sun "on" in light mode
                                tooltipText: "Toggle dark mode"
                                onTriggered: {
                                    const mode = Appearance.m3colors.darkmode ? "light" : "dark";
                                    Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode ${mode} --noswitch`);
                                }
                            }
                            // Dedicated, obvious quick-settings entry point.
                            // Open-only: closing is handled by the panel's focus
                            // grab (outside-click) and Escape. A toggle here would
                            // race the grab's onCleared (which closes on the same
                            // outside click) and immediately re-open the panel.
                            PixControlButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "sliders"
                                active: GlobalStates.sidebarRightOpen
                                tooltipText: "Quick settings"
                                onTriggered: GlobalStates.sidebarRightOpen = true
                            }
                            PixBatteryChip {
                                anchors.verticalCenter: parent.verticalCenter
                                onActivated: GlobalStates.sidebarRightOpen = true
                            }
                        }

                        PixBarDivider {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Tray cluster (also opens quick settings on click of empty area)
                        MouseArea {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: trayCluster.implicitWidth
                            implicitHeight: trayCluster.implicitHeight
                            acceptedButtons: Qt.RightButton
                            onClicked: GlobalStates.sidebarRightOpen = true

                            PixTray {
                                id: trayCluster
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
