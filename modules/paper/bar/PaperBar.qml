import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * PaperBar — §4.2 Bar of the paper family, all three variants.
 *
 * One `PanelWindow` per screen via `Variants { model: Quickshell.screens }`,
 * anchored top/left/right, `implicitHeight` and `exclusiveZone` both
 * `PaperTheme.barHeight` (38 / 34 / 42), visible while the bar is open and the
 * screen is not locked. The window is transparent; the bar itself is a
 * `PaperPanel` with every edge dropped except the bottom, which carries
 * `bottomWeight: "oxford"` — a real Oxford rule in broadsheet (2 px ink, 1 px
 * gap, 1 px `rule-2`, the strongest single piece of structure in the shell) and
 * a plain hairline in the other two, which is exactly what their SPECs ask for.
 * Hairline wants its rule in `rule` rather than the aimable `rule-2`, so it
 * asks for `hair` instead.
 *
 * The bar ground is `paper`, not `paperRaise`: all three SPECs specify an
 * OPAQUE strip of the page laid over the desktop. It never tints or blurs the
 * wallpaper.
 *
 * Two `FocusedScrollMouseArea`s cover the halves and are declared FIRST so
 * every click still lands on the controls above them: scrolling the left half
 * changes brightness by ±0.05, the right half volume; both raise their OSD and
 * close it on `movedAway`. Identical to the pixel bar.
 *
 * Clusters, all three variants:
 *   left   — tray · divider · stats (hover → system monitor) · divider · media
 *   centre — the ten workspace cells
 *   right  — clock (hover → clock popup) · divider · utility glyphs ·
 *            battery chip (hover → battery popup, click → quick settings)
 *
 * No `IpcHandler` and no `GlobalShortcut` live in the bar; the Displays and
 * Worktrees panels still have no bar entry point, by design.
 *
 * See design/paper-{a-hairline,b-ledger,c-broadsheet}/SPEC.md §4 "Bar" and
 * design/current-pixels/SPEC.md §4.2 for the unchanged behavioural contract.
 */
Scope {
    id: bar

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barRoot
            required property ShellScreen modelData
            screen: barRoot.modelData

            visible: GlobalStates.barOpen && !GlobalStates.screenLocked

            WlrLayershell.namespace: "quickshell:paperBar"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: PaperTheme.barHeight
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: PaperTheme.barHeight

            /// The gap that sits either side of every cluster divider.
            readonly property real clusterGap: PaperTheme.pick(20, 12, 13)
            /// How much of the bar's height the bottom rule occupies.
            readonly property real bottomChrome: PaperTheme.ornament.oxfordRules ? (PaperTheme.oxfordThick + PaperTheme.ruleGap + PaperTheme.ruleWidth) : PaperTheme.ruleWidth

            PaperPanel {
                id: barSheet
                anchors.fill: parent
                kind: "sheet"
                // An opaque strip of the page — `paper`, never the raised sheet.
                color: PaperTheme.paper
                edgeTop: false
                edgeLeft: false
                edgeRight: false
                edgeBottom: true
                // Degrades to a hairline in ledger; hairline wants `rule`.
                bottomWeight: PaperTheme.isHairline ? "hair" : "oxford"

                Item {
                    id: barContent
                    anchors {
                        fill: parent
                        leftMargin: PaperTheme.pad.bar
                        rightMargin: PaperTheme.pad.bar
                        bottomMargin: barRoot.bottomChrome + PaperTheme.pick(0, 0, 3)
                    }

                    // Per-screen brightness monitor (null-safe; may be null).
                    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(barRoot.screen)

                    // ---- scroll regions -------------------------------------
                    // Declared first (lowest z) so workspaces and buttons still
                    // receive clicks; scrolling only lands here over empty bar.
                    FocusedScrollMouseArea {
                        id: leftScroll
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.horizontalCenter
                        }
                        acceptedButtons: Qt.NoButton
                        onScrollUp: {
                            if (barContent.brightnessMonitor) {
                                GlobalStates.osdBrightnessOpen = true;
                                barContent.brightnessMonitor.setBrightness(barContent.brightnessMonitor.brightness + 0.05);
                            }
                        }
                        onScrollDown: {
                            if (barContent.brightnessMonitor) {
                                GlobalStates.osdBrightnessOpen = true;
                                barContent.brightnessMonitor.setBrightness(barContent.brightnessMonitor.brightness - 0.05);
                            }
                        }
                        onMovedAway: GlobalStates.osdBrightnessOpen = false
                    }

                    FocusedScrollMouseArea {
                        id: rightScroll
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.horizontalCenter
                            right: parent.right
                        }
                        acceptedButtons: Qt.NoButton
                        onScrollUp: {
                            GlobalStates.osdVolumeOpen = true;
                            Audio.incrementVolume();
                        }
                        onScrollDown: {
                            GlobalStates.osdVolumeOpen = true;
                            Audio.decrementVolume();
                        }
                        onMovedAway: GlobalStates.osdVolumeOpen = false
                    }

                    // ---- LEFT: tray · divider · stats · divider · media -----
                    Row {
                        id: leftCluster
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        BarTray {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: barRoot.clusterGap
                            implicitHeight: 1
                        }
                        BarDivider {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: barRoot.clusterGap
                            implicitHeight: 1
                        }
                        BarStats {
                            anchors.verticalCenter: parent.verticalCenter
                            clusterGap: barRoot.clusterGap
                        }
                    }

                    // ---- CENTRE: workspaces ---------------------------------
                    // Hairline centres the row (its focus rule hangs below the
                    // cell); ledger and broadsheet sit the cells on a baseline
                    // near the bottom edge, so they anchor down instead.
                    BarWorkspaces {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: PaperTheme.isHairline ? parent.verticalCenter : undefined
                        anchors.bottom: PaperTheme.isHairline ? undefined : parent.bottom
                        anchors.bottomMargin: PaperTheme.pick(0, 3, 0)
                    }

                    // ---- RIGHT: clock · divider · controls · battery --------
                    Row {
                        id: rightCluster
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        BarClock {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: barRoot.clusterGap
                            implicitHeight: 1
                        }
                        BarDivider {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: barRoot.clusterGap
                            implicitHeight: 1
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: PaperTheme.pick(18, 8, 13)

                            // Region screenshot — same IPC as the ii/pixel bars.
                            BarControlButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "crop"
                                visible: Config.options.bar.utilButtons.showScreenSnip
                                tooltipText: "Screenshot region"
                                onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"])
                            }
                            // The palette toggle is drawn as the mode you would
                            // switch TO — moon while light, sun while dusk.
                            BarControlButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: PaperTheme.dark ? "sun" : "moon"
                                tooltipText: "Toggle dark mode"
                                onTriggered: {
                                    const mode = Appearance.m3colors.darkmode ? "light" : "dark";
                                    Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode ${mode} --noswitch`);
                                }
                            }
                        }

                        // Broadsheet rules the battery off from the utility
                        // glyphs; the other two just leave whitespace.
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: PaperTheme.pick(18, 10, 13)
                            implicitHeight: 1
                        }
                        BarDivider {
                            visible: PaperTheme.isBroadsheet
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            visible: PaperTheme.isBroadsheet
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: PaperTheme.pick(0, 0, 13)
                            implicitHeight: 1
                        }

                        BarBatteryChip {
                            anchors.verticalCenter: parent.verticalCenter
                            onActivated: GlobalStates.sidebarRightOpen = true
                        }
                    }
                }
            }
        }
    }
}
