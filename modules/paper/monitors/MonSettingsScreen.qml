pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * hyprdynamicmonitors globals and daemon controls: the profile-scoring weights,
 * desktop notifications on profile switch, and the read-only info block. The
 * help text mirrors the hyprdynamicmonitors docs; every write goes through the
 * `Monitors` service.
 *
 * The values are edited locally and committed by an explicit "Apply" — exactly
 * as in the pixel SettingsScreen, because each apply rewrites a block of the
 * user's config.
 */
Item {
    id: root

    signal done

    property int scName: 10
    property int scDesc: 5
    property int scPower: 3
    property int scLid: 2
    property bool notifOn: true
    property int notifTimeout: 10000

    readonly property real gap: PaperTheme.pick(14, 10, 12)

    Component.onCompleted: {
        const s = Monitors.scoring ?? ({});
        root.scName = s.name_match ?? 10;
        root.scDesc = s.description_match ?? 5;
        root.scPower = s.power_state_match ?? 3;
        root.scLid = s.lid_state_match ?? 2;
        const n = Monitors.notifications ?? ({});
        root.notifOn = !(n.disabled ?? false);
        root.notifTimeout = n.timeout_ms ?? 10000;
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: root.gap

            // ---- back bar ----
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperButton {
                    shape: "icon"
                    icon: "chevL"
                    onClicked: root.done()
                }
                PaperTitle {
                    Layout.fillWidth: true
                    text: "Settings"
                }
            }
            PaperRule {
                visible: PaperTheme.ornament.oxfordRules
                Layout.fillWidth: true
                weight: "oxford"
            }

            // ---- daemon ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Daemon"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperStamp {
                    visible: PaperTheme.isBroadsheet
                    text: Monitors.daemonRunning ? "Running" : "Not running"
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
                    Layout.fillWidth: true
                    visible: !PaperTheme.isBroadsheet
                    text: Monitors.daemonRunning ? "Running" : "Not running"
                    role: "meta"
                    tone: "ink3"
                }
                Item {
                    Layout.fillWidth: PaperTheme.isBroadsheet
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.gap.chip

                PaperButton {
                    Layout.fillWidth: !PaperTheme.isHairline
                    Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                    label: "Validate"
                    enabled: !Monitors.busy
                    onClicked: Monitors.validate()
                }
                PaperButton {
                    Layout.fillWidth: !PaperTheme.isHairline
                    Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                    label: "Reapply"
                    enabled: !Monitors.busy
                    onClicked: Monitors.reapply()
                }
                PaperButton {
                    Layout.fillWidth: !PaperTheme.isHairline
                    Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                    label: "Reload"
                    enabled: !Monitors.busy
                    onClicked: Monitors.reload()
                }
                // Hairline packs its caps buttons left and lets the rest of the
                // measure stay white; the other two divide the row evenly.
                Item {
                    Layout.fillWidth: PaperTheme.isHairline
                }
            }

            // ---- scoring ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Profile scoring"
            }
            PaperText {
                Layout.fillWidth: true
                text: "When several profiles match the connected monitors, the highest total score wins (ties go to the profile defined last)."
                role: "meta"
                tone: "ink4"
                footnote: true
                wrapMode: Text.WordWrap
            }
            PaperStepper {
                Layout.fillWidth: true
                label: "Name match"
                help: "connector matched exactly"
                value: root.scName
                onChanged: v => root.scName = v
            }
            PaperStepper {
                Layout.fillWidth: true
                label: "Description match"
                help: "monitor model string matched"
                value: root.scDesc
                onChanged: v => root.scDesc = v
            }
            PaperStepper {
                Layout.fillWidth: true
                label: PaperTheme.isBroadsheet ? "Power state" : "Power state match"
                help: "AC / battery condition met"
                value: root.scPower
                onChanged: v => root.scPower = v
            }
            PaperStepper {
                Layout.fillWidth: true
                label: PaperTheme.isBroadsheet ? "Lid state" : "Lid state match"
                help: "lid condition met"
                value: root.scLid
                onChanged: v => root.scLid = v
            }
            PaperButton {
                Layout.fillWidth: !PaperTheme.isHairline
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                label: "Apply scoring"
                enabled: !Monitors.busy
                onClicked: Monitors.setScoring({
                    name_match: root.scName,
                    description_match: root.scDesc,
                    power_state_match: root.scPower,
                    lid_state_match: root.scLid
                })
            }

            // ---- notifications ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Notifications"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperText {
                    Layout.fillWidth: true
                    text: "Desktop notification on profile switch"
                    role: "small"
                    wrapMode: Text.WordWrap
                }
                PaperSwitch {
                    checked: root.notifOn
                    onToggled: root.notifOn = !root.notifOn
                }
            }
            PaperStepper {
                Layout.fillWidth: true
                label: "Timeout (ms)"
                help: "milliseconds · step 1000 · max 60000"
                value: root.notifTimeout
                from: 0
                to: 60000
                step: 1000
                onChanged: v => root.notifTimeout = v
            }
            PaperButton {
                Layout.fillWidth: !PaperTheme.isHairline
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                label: "Apply notifications"
                enabled: !Monitors.busy
                onClicked: Monitors.setNotifications({
                    disabled: !root.notifOn,
                    timeout_ms: root.notifTimeout
                })
            }

            // ---- read-only info ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Info"
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Dest"
                value: Monitors.destination || "?"
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Debounce"
                value: (Monitors.general && Monitors.general.debounce_time_ms !== undefined && Monitors.general.debounce_time_ms !== null) ? (Monitors.general.debounce_time_ms + " ms") : "default"
                figure: false
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Fallback"
                value: Monitors.hasFallback ? "yes" : "none"
            }

            Item {
                Layout.preferredHeight: PaperTheme.spacing.tiny
            }
        }
    }
}
