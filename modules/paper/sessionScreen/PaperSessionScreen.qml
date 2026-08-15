pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.paper.common
import qs.modules.paper.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * PaperSessionScreen — §4.9 Session screen of the paper family.
 *
 * A `Loader` gated on `GlobalStates.sessionOpen` produces a full-screen overlay
 * `PanelWindow` on the focused screen with
 * `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` and NO focus grab —
 * which is exactly why on-demand creation is safe here (HANDOFF.md §5.3.1: a
 * Loader-created window maps at the instant a grab would activate, so surfaces
 * that need a grab must stay alive; this one does not need one). Clicking the
 * scrim cancels, Escape cancels, and a `Connections` on
 * `GlobalStates.onScreenLockedChanged` closes it when the lock takes over.
 *
 * Structure, per variant:
 *   hairline   — the scrim is `paper` at 92 %, near-opaque, so the six choices
 *                sit on a clean page. SESSION in display caps, then six 120 px
 *                COLUMNS separated by full-height 1 px vertical rules, then the
 *                hint line, then warnings as an alert dot plus alert text.
 *   ledger     — the scrim is paper at 90 %: tracing paper, not a blackout.
 *                `Session` in Charter 30 over a mono sub-line, a 748 px `rule2`
 *                hairline, six 116 px tiles, the hint line, warnings as stamps.
 *   broadsheet — a warm scrim at 72 % so the wallpaper survives as texture.
 *                `Session` in Pagella small caps over a 200 px Oxford rule in
 *                paper white, six 128 px sheets, an italic hint line, and
 *                warnings as paper-backed stamps.
 *
 * Keys (identical in all three, and unchanged from the pixel family):
 * ←/→/↑/↓/Tab move, Home/End jump, Enter/Space run, 1–6 select and run
 * immediately, Escape cancels. Hover also moves the selection. Nothing inverts
 * and nothing fills — the selection is the variant's ordinary mark.
 *
 * `Loader.onActiveChanged` refreshes `SessionWarnings` so the package-manager
 * and download checks are re-run every time the screen opens.
 *
 * IPC: target "session" (toggle / close / open) and the GlobalShortcuts
 * "sessionToggle" / "sessionOpen" / "sessionClose" — the same names the ii and
 * pixel families use, so the user's existing binds keep working.
 */
Scope {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

    /// Every action is named by its OWN glyph — the pixel family had to borrow
    /// `gear` for Lock and `swap` for Log out because its 7 × 7 set had neither.
    readonly property var actionModel: [
        {
            key: "lock",
            icon: "lock",
            label: Translation.tr("Lock"),
            accel: "1"
        },
        {
            key: "logout",
            icon: "logout",
            label: Translation.tr("Log out"),
            accel: "2"
        },
        {
            key: "suspend",
            icon: "moon",
            label: Translation.tr("Suspend"),
            accel: "3"
        },
        {
            key: "hibernate",
            icon: "snow",
            label: Translation.tr("Hibernate"),
            accel: "4"
        },
        {
            key: "reboot",
            icon: "refresh",
            label: Translation.tr("Reboot"),
            accel: "5"
        },
        {
            key: "shutdown",
            icon: "power",
            label: Translation.tr("Shut down"),
            accel: "6"
        }
    ]

    function runAction(key: string): void {
        switch (key) {
        case "lock":
            Session.lock();
            break;
        case "logout":
            Session.logout();
            break;
        case "suspend":
            Session.suspend();
            break;
        case "hibernate":
            Session.hibernate();
            break;
        case "reboot":
            Session.reboot();
            break;
        case "shutdown":
            Session.poweroff();
            break;
        }
        GlobalStates.sessionOpen = false;
    }

    Loader {
        id: sessionLoader
        active: GlobalStates.sessionOpen
        onActiveChanged: {
            if (sessionLoader.active)
                SessionWarnings.refresh();
        }

        Connections {
            target: GlobalStates
            function onScreenLockedChanged(): void {
                if (GlobalStates.screenLocked)
                    GlobalStates.sessionOpen = false;
            }
        }

        sourceComponent: PanelWindow {
            id: sessionRoot

            visible: sessionLoader.active
            screen: root.focusedScreen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:paperSession"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // The ShellScreen is the reliable size source; a layer surface can
            // still be 0 × 0 shortly after a reload.
            implicitWidth: root.focusedScreen?.width ?? 0
            implicitHeight: root.focusedScreen?.height ?? 0

            /// Currently highlighted choice. Reset to the first on open.
            property int selectedIndex: 0
            onVisibleChanged: if (sessionRoot.visible)
                sessionRoot.selectedIndex = 0

            /// Broadsheet lays the masthead over a warm near-black scrim, so its
            /// "ink" there is the light end of the ramp; the other two lay it on
            /// near-opaque paper and use ordinary ink.
            readonly property color onScrim: PaperTheme.isBroadsheet ? (PaperTheme.dark ? PaperTheme.ink : PaperTheme.paper) : PaperTheme.ink
            readonly property color onScrimSoft: PaperTheme.isBroadsheet ? Qt.rgba(sessionRoot.onScrim.r, sessionRoot.onScrim.g, sessionRoot.onScrim.b, 0.72) : PaperTheme.ink3

            function hide(): void {
                GlobalStates.sessionOpen = false;
            }

            function move(delta: int): void {
                const n = root.actionModel.length;
                sessionRoot.selectedIndex = ((sessionRoot.selectedIndex + delta) % n + n) % n;
            }

            // The scrim. Clicking anywhere on it cancels.
            Rectangle {
                id: scrim
                anchors.fill: parent
                color: PaperTheme.scrim2
                antialiasing: false

                // The same grain the panels carry, so scrim and sheet are cut
                // from one page.
                Image {
                    anchors.fill: parent
                    visible: PaperTheme.ornament.grain && PaperTheme.ornament.grainOpacity > 0
                    source: Qt.resolvedUrl(Quickshell.shellPath("assets/images/paper-grain.png"))
                    fillMode: Image.Tile
                    opacity: PaperTheme.ornament.grainOpacity
                    cache: true
                    smooth: false
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionRoot.hide()
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: sessionRoot.visible

                Keys.onPressed: event => {
                    const n = root.actionModel.length;
                    switch (event.key) {
                    case Qt.Key_Escape:
                        sessionRoot.hide();
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                    case Qt.Key_Down:
                    case Qt.Key_Tab:
                        sessionRoot.move(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                    case Qt.Key_Up:
                    case Qt.Key_Backtab:
                        sessionRoot.move(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Home:
                        sessionRoot.selectedIndex = 0;
                        event.accepted = true;
                        break;
                    case Qt.Key_End:
                        sessionRoot.selectedIndex = n - 1;
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.runAction(root.actionModel[sessionRoot.selectedIndex].key);
                        event.accepted = true;
                        break;
                    default:
                        // Number accelerators 1–6: select AND run.
                        if (event.text.length === 1) {
                            const idx = root.actionModel.findIndex(a => a.accel === event.text);
                            if (idx >= 0) {
                                sessionRoot.selectedIndex = idx;
                                root.runAction(root.actionModel[idx].key);
                                event.accepted = true;
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    // ---------------------------------------------- masthead
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: PaperTheme.pick(0, 7, 6)

                        PaperTitle {
                            id: masthead
                            Layout.alignment: Qt.AlignHCenter
                            role: "display"
                            color: sessionRoot.onScrim
                            // Hairline and broadsheet letterspace the masthead;
                            // ledger's Charter 30 sits at 0.
                            font.letterSpacing: PaperTheme.tracking(PaperTheme.font.trackingEm.display, masthead.font.pixelSize)
                            text: Translation.tr("Session")
                        }

                        // Ledger's mono sub-line: host · date · time · uptime.
                        PaperText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: PaperTheme.isLedger
                            role: "meta"
                            tone: "ink3"
                            mono: true
                            text: {
                                const host = Quickshell.env("HOSTNAME") || "";
                                const parts = [];
                                if (host.length > 0)
                                    parts.push(host);
                                parts.push(DateTime.collapsedCalendarFormat);
                                parts.push(DateTime.time);
                                parts.push(Translation.tr("up %1").arg(DateTime.uptime));
                                return parts.join(" · ");
                            }
                        }

                        // Broadsheet's Oxford rule, in the scrim's ink rather
                        // than PaperRule's fixed `ink` — hence drawn locally.
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            visible: PaperTheme.ornament.oxfordRules
                            implicitWidth: 200
                            implicitHeight: PaperTheme.oxfordThick + PaperTheme.ruleGap + PaperTheme.ruleWidth
                            Rectangle {
                                width: parent.width
                                height: PaperTheme.oxfordThick
                                color: sessionRoot.onScrim
                                antialiasing: false
                            }
                            Rectangle {
                                y: PaperTheme.oxfordThick + PaperTheme.ruleGap
                                width: parent.width
                                height: PaperTheme.ruleWidth
                                color: sessionRoot.onScrimSoft
                                antialiasing: false
                            }
                        }
                    }

                    // Ledger's 748 px hairline under the masthead block.
                    PaperRule {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 22
                        visible: PaperTheme.isLedger
                        weight: "fine"
                        length: 748
                        opacity: 0.7
                    }

                    // ----------------------------------------------- choices
                    Loader {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: PaperTheme.pick(40, 22, 22)
                        // A Loader rather than a forest of `visible:` bindings —
                        // the two layouts are structurally different, and this
                        // stays reactive across a live variant switch.
                        sourceComponent: PaperTheme.isHairline ? columnsComponent : tilesComponent
                    }

                    // -------------------------------------------------- hint
                    // Hairline sets the key names in mono `ink2` inside an
                    // `ink3` sentence, so the row has to be built from parts.
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: PaperTheme.pick(40, 22, 22)
                        visible: PaperTheme.isHairline
                        spacing: 0

                        PaperText {
                            role: "meta"
                            tone: "ink3"
                            text: Translation.tr("Arrows or ")
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink2"
                            mono: true
                            text: "1"
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink3"
                            text: "–"
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink2"
                            mono: true
                            text: "6"
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink3"
                            text: Translation.tr(" to choose · ")
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink2"
                            mono: true
                            text: "Enter"
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink3"
                            text: Translation.tr(" to confirm · ")
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink2"
                            mono: true
                            text: "Esc"
                        }
                        PaperText {
                            role: "meta"
                            tone: "ink3"
                            text: Translation.tr(" or a click anywhere to cancel")
                        }
                    }

                    PaperText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: PaperTheme.pick(40, 22, 22)
                        visible: !PaperTheme.isHairline
                        role: PaperTheme.isBroadsheet ? "body" : "meta"
                        // Broadsheet sets its hint in Pagella italic.
                        footnote: PaperTheme.isBroadsheet
                        color: PaperTheme.isBroadsheet ? sessionRoot.onScrimSoft : PaperTheme.ink3
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Arrows or 1–6 to choose, Enter to confirm — Esc or a click anywhere cancels")
                    }

                    // ---------------------------------------------- warnings
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: PaperTheme.pick(26, 22, 22)
                        spacing: PaperTheme.pick(28, 10, 10)
                        visible: SessionWarnings.packageManagerRunning || SessionWarnings.downloadRunning

                        SessionWarning {
                            visible: SessionWarnings.packageManagerRunning
                            text: PaperTheme.isHairline ? Translation.tr("Your package manager is running") : Translation.tr("Package manager running")
                        }
                        SessionWarning {
                            visible: SessionWarnings.downloadRunning
                            text: PaperTheme.isHairline ? Translation.tr("There might be a download in progress") : Translation.tr("Download in progress")
                        }
                    }
                }

                // --------------------------------------------- the two rows

                /// Hairline: six 120 px columns divided by full-height rules.
                Component {
                    id: columnsComponent

                    Row {
                        spacing: 0

                        Repeater {
                            model: root.actionModel

                            delegate: Row {
                                id: cell
                                required property int index
                                required property var modelData
                                spacing: 0

                                PaperRule {
                                    visible: cell.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    vertical: true
                                    length: column.columnHeight
                                }

                                SessionColumn {
                                    id: column
                                    glyph: cell.modelData.icon
                                    label: cell.modelData.label
                                    accelerator: cell.modelData.accel
                                    selected: sessionRoot.selectedIndex === cell.index
                                    onSelectRequested: sessionRoot.selectedIndex = cell.index
                                    onActivated: root.runAction(cell.modelData.key)
                                }
                            }
                        }
                    }
                }

                /// Ledger / broadsheet: six square tiles.
                Component {
                    id: tilesComponent

                    Row {
                        spacing: PaperTheme.size.sessionGap

                        Repeater {
                            model: root.actionModel

                            delegate: SessionTile {
                                id: tile
                                required property int index
                                required property var modelData

                                glyph: tile.modelData.icon
                                label: tile.modelData.label
                                accelerator: tile.modelData.accel
                                selected: sessionRoot.selectedIndex === tile.index
                                onSelectRequested: sessionRoot.selectedIndex = tile.index
                                onActivated: root.runAction(tile.modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ IPC
    // Same target and shortcut names as the ii and pixel session screens, so
    // existing binds (Ctrl-Alt-Delete → quickshell:sessionToggle,
    // `qs -c ii ipc call session toggle`) keep working. Only one family loads
    // at a time, so they cannot collide.

    IpcHandler {
        target: "session"
        function toggle(): void {
            GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
        }
        function close(): void {
            GlobalStates.sessionOpen = false;
        }
        function open(): void {
            GlobalStates.sessionOpen = true;
        }
    }

    GlobalShortcut {
        name: "sessionToggle"
        description: "Toggles session screen on press"
        onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen
    }
    GlobalShortcut {
        name: "sessionOpen"
        description: "Opens session screen on press"
        onPressed: GlobalStates.sessionOpen = true
    }
    GlobalShortcut {
        name: "sessionClose"
        description: "Closes session screen on press"
        onPressed: GlobalStates.sessionOpen = false
    }
}
