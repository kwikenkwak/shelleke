pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * Body of the Displays overlay — a three-screen stack:
 *   main     — quick Extend/Mirror/Single, the connected outputs, the profile list
 *   editor   — full profile create/edit (MonProfileEditor), covering the panel
 *   settings — HDM globals and daemon controls (MonSettingsScreen), likewise
 *
 * Everything reads and writes through the `Monitors` singleton. The service
 * debounces its own refreshes, so calling refresh() on open is cheap.
 *
 * Quick MODE changes (Extend/Mirror/Single/Auto) are the one class of action
 * that can leave the user unable to see the panel that would undo them, so they
 * are routed through MonQuickConfirm: snapshot → apply → "Keep this setup?" with
 * a 15 s countdown, and anything other than Keep puts the previous layout back.
 *
 * NOTE (spec deviation, deliberate): hairline's §4.8 asks for a SWITCH on each
 * connected output. `Monitors` exposes no per-output enable/disable action —
 * hdm-control.py has none — so the output's enabled state is drawn as a mark
 * (plate ink / "Disabled") rather than as a control that could not do anything.
 * When such an action lands, MonMonitorRow is where the switch belongs — and it
 * must be DISABLED for the last enabled output, with a hint saying why, for the
 * same reason Single is disabled when nothing is connected: no control in this
 * overlay may be able to turn off the final screen.
 */
PaperPanel {
    id: root

    readonly property real pad: PaperTheme.pad.panel
    readonly property real gap: PaperTheme.pick(16, 10, 12)

    /// "main" | "settings"
    property string screen: "main"
    /// null | an existing profile object | { __new__: true }
    property var editingProfile: null

    // Docked against the left screen edge: only the inboard (right) rule is
    // drawn, exactly as the SPECs ask.
    kind: "sheet"
    floating: false
    edgeLeft: false
    edgeTop: false
    edgeBottom: false

    Component.onCompleted: Monitors.refresh()

    Connections {
        target: GlobalStates
        function onMonitorsOpenChanged(): void {
            if (GlobalStates.monitorsOpen) {
                root.screen = "main";
                root.editingProfile = null;
                Monitors.refresh();
            } else {
                // Closing the overlay answers a pending "Keep this setup?" with
                // no. (MonQuickConfirm also reverts from its own onDestruction,
                // for whichever of the two fires first; revert() is idempotent.)
                quickConfirm.revert();
            }
        }
    }

    // ============================== MAIN ==============================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap
        visible: root.screen === "main" && root.editingProfile === null

        // ---- masthead ----
        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PaperTitle {
                    text: "Displays"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                // Ledger prints what the panel is a GUI for under its title.
                PaperText {
                    visible: PaperTheme.isLedger
                    text: "hyprdynamicmonitors"
                    role: "micro"
                    tone: "ink4"
                }
            }

            PaperButton {
                shape: "icon"
                icon: "refresh"
                enabled: !Monitors.busy
                onClicked: Monitors.refresh()
                PaperTooltip {
                    // Left-docked panel: the hints hang off the RIGHT edge, as
                    // they do in the pixel build, rather than over the content.
                    text: "Refresh"
                    anchorEdges: Edges.Right
                    anchorGravity: Edges.Right
                }
            }
            PaperButton {
                shape: "icon"
                icon: "gear"
                onClicked: root.screen = "settings"
                PaperTooltip {
                    text: "Settings & daemon"
                    anchorEdges: Edges.Right
                    anchorGravity: Edges.Right
                }
            }
        }

        // Broadsheet's masthead sits over an Oxford rule; the other two run
        // straight into the status line.
        PaperRule {
            visible: PaperTheme.ornament.oxfordRules
            Layout.fillWidth: true
            weight: "oxford"
        }

        // ---- daemon + active status ----
        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.spacing.small

            // Broadsheet stamps the daemon state; the other two use the 6 px dot.
            PaperStamp {
                visible: PaperTheme.isBroadsheet
                text: Monitors.daemonRunning ? "Daemon on" : "Daemon off"
                tone: Monitors.daemonRunning ? "link" : "seal"
            }
            Rectangle {
                visible: !PaperTheme.isBroadsheet
                Layout.preferredWidth: PaperTheme.size.dot
                Layout.preferredHeight: PaperTheme.size.dot
                radius: width / 2
                antialiasing: true
                color: Monitors.daemonRunning ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.link) : "transparent"
                border.width: PaperTheme.ruleWidth
                border.color: Monitors.daemonRunning ? (PaperTheme.isHairline ? PaperTheme.ink : PaperTheme.link) : PaperTheme.rule2
            }
            PaperText {
                visible: !PaperTheme.isBroadsheet
                text: Monitors.daemonRunning ? "Daemon running" : "Daemon not running"
                role: "meta"
                tone: "ink3"
            }

            Item {
                Layout.fillWidth: true
            }

            PaperText {
                // "Active docked-dual" (hairline) · "active: desk" (ledger) ·
                // "Active · desk-triple" (broadsheet).
                text: {
                    const key = Monitors.quickActive ? "Quick" : "Active";
                    const value = Monitors.quickActive ? Monitors.quickMode : Monitors.activeProfile;
                    if (!value)
                        return "No profile";
                    return PaperTheme.pick(key + " ", key.toLowerCase() + ": ", key + " · ") + value;
                }
                role: "meta"
                mono: !PaperTheme.isBroadsheet
                footnote: PaperTheme.isBroadsheet
                tone: (Monitors.activeProfile || Monitors.quickActive) ? "ink2" : "ink4"
                elide: Text.ElideRight
                Layout.maximumWidth: PaperTheme.pick(200, 180, 190)
            }
        }

        PaperRule {
            Layout.fillWidth: true
        }

        // ---- scrolling body ----
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: root.gap

                PaperSectionHeader {
                    Layout.fillWidth: true
                    label: "Quick layout"
                }
                MonQuickLayout {
                    Layout.fillWidth: true
                    // Snapshot BEFORE applying, always in this order.
                    onModeRequested: (mode, target) => {
                        quickConfirm.arm();
                        if (mode === "auto")
                            Monitors.clearQuick();
                        else
                            Monitors.setQuick(mode, target);
                    }
                }

                PaperSectionHeader {
                    Layout.fillWidth: true
                    // Broadsheet bakes the count into the head; the other two set
                    // it as the right-hand cut-in after the rule.
                    label: PaperTheme.isBroadsheet ? ("Connected (" + Monitors.monitors.length + ")") : "Connected"
                    meta: PaperTheme.isBroadsheet ? "" : String(Monitors.monitors.length)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    // Hairline separates rows with a rule and no gap; the others
                    // stack cards with a gap and no separator.
                    spacing: PaperTheme.pick(0, PaperTheme.gap.tile, PaperTheme.gap.tile)

                    Repeater {
                        model: Monitors.monitors

                        delegate: MonMonitorRow {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            monitor: modelData
                            separator: index < Monitors.monitors.length - 1
                        }
                    }
                }

                PaperSectionHeader {
                    Layout.fillWidth: true
                    label: "Profiles"

                    PaperButton {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "+ New"
                        onClicked: root.editingProfile = ({
                                __new__: true
                            })
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: PaperTheme.pick(0, PaperTheme.gap.tile, PaperTheme.gap.tile)

                    Repeater {
                        model: Monitors.profiles

                        delegate: MonProfileRow {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            profile: modelData
                            separator: index < Monitors.profiles.length - 1
                            onActivated: root.editingProfile = modelData
                        }
                    }
                }
                PaperEmpty {
                    Layout.fillWidth: true
                    visible: Monitors.profiles.length === 0
                    text: "No profiles yet — press + New or pick a quick layout"
                }

                Item {
                    Layout.preferredHeight: PaperTheme.spacing.tiny
                }
            }
        }

        // ---- status line ----
        RowLayout {
            Layout.fillWidth: true
            visible: Monitors.busy || Monitors.lastMessage.length > 0
            spacing: PaperTheme.spacing.small

            PaperText {
                Layout.fillWidth: true
                text: Monitors.busy ? "Working…" : Monitors.lastMessage
                role: "meta"
                footnote: Monitors.busy
                tone: (!Monitors.busy && !Monitors.lastOk) ? "alert" : "ink3"
                elide: Text.ElideRight
            }
            // Broadsheet signs the line with the tool that produced it.
            PaperText {
                visible: PaperTheme.isBroadsheet
                text: "hdm-control"
                role: "micro"
                mono: true
                tone: "ink4"
            }
        }
    }

    // ===================== OVERLAY (editor / settings) =====================
    // An opaque paper ground, so the main screen never shows through.
    Rectangle {
        anchors.fill: parent
        anchors.margins: PaperTheme.ruleWidth
        visible: overlayLoader.active
        color: PaperTheme.paper
        radius: 0
        antialiasing: false
    }
    Loader {
        id: overlayLoader
        anchors.fill: parent
        anchors.margins: root.pad
        active: root.editingProfile !== null || root.screen !== "main"
        visible: active
        sourceComponent: root.editingProfile !== null ? editorComponent : settingsComponent
    }
    Component {
        id: editorComponent
        MonProfileEditor {
            profile: root.editingProfile
            onDone: root.editingProfile = null
        }
    }
    Component {
        id: settingsComponent
        MonSettingsScreen {
            onDone: root.screen = "main"
        }
    }

    // ================== QUICK-LAYOUT CONFIRMATION ==================
    // Last child, so it covers the editor and settings screens too: a mode change
    // is never left unanswered behind another screen.
    MonQuickConfirm {
        id: quickConfirm
        anchors.fill: parent
        anchors.margins: PaperTheme.ruleWidth
    }
}
