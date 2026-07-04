pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * HDM global settings + daemon controls: profile-scoring weights, desktop
 * notifications, and read-only info (destination, debounce). Help text mirrors
 * the hyprdynamicmonitors docs. Writes go through the Monitors service.
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

    Component.onCompleted: {
        const s = Monitors.scoring ?? ({});
        scName = s.name_match ?? 10;
        scDesc = s.description_match ?? 5;
        scPower = s.power_state_match ?? 3;
        scLid = s.lid_state_match ?? 2;
        const n = Monitors.notifications ?? ({});
        notifOn = !(n.disabled ?? false);
        notifTimeout = n.timeout_ms ?? 10000;
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
            spacing: 10

            // back bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PixButton {
                    implicitWidth: 34; implicitHeight: 30
                    onClicked: root.done()
                    PixIcon { anchors.centerIn: parent; name: "chevL"; size: 14; color: parent.contentColor }
                }
                PixTitle { Layout.fillWidth: true; text: "SETTINGS"; font.pixelSize: PixTheme.font.pixelSize.title }
            }

            // daemon
            PixText { text: "DAEMON"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Rectangle {
                    Layout.preferredWidth: 14; Layout.preferredHeight: 14; radius: 0; antialiasing: false
                    color: Monitors.daemonRunning ? PixTheme.colors.fg : "transparent"
                    border.width: PixTheme.borderWidth; border.color: PixTheme.colors.line
                }
                PixText { Layout.fillWidth: true
                    text: Monitors.daemonRunning ? "Running" : "Not running"
                    font.pixelSize: PixTheme.font.pixelSize.small; color: PixTheme.colors.grey }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [
                        { label: "Validate", act: "validate" },
                        { label: "Reapply", act: "reapply" },
                        { label: "Reload", act: "reload" }
                    ]
                    delegate: PixButton {
                        id: dBtn
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        enabled: !Monitors.busy
                        onClicked: {
                            if (modelData.act === "validate") Monitors.validate();
                            else if (modelData.act === "reapply") Monitors.reapply();
                            else Monitors.reload();
                        }
                        PixText { anchors.centerIn: parent; text: dBtn.modelData.label
                            font.pixelSize: PixTheme.font.pixelSize.small; color: dBtn.contentColor }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

            // scoring
            PixText { text: "PROFILE SCORING"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            PixText { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smallest
                text: "When several profiles match the connected monitors, the highest total score wins (ties go to the profile defined last)." }
            StepperRow { Layout.fillWidth: true; label: "Name match"; help: "exact connector name (eDP-1)"
                value: root.scName; onChanged: v => root.scName = v }
            StepperRow { Layout.fillWidth: true; label: "Description match"; help: "monitor model string"
                value: root.scDesc; onChanged: v => root.scDesc = v }
            StepperRow { Layout.fillWidth: true; label: "Power state match"; help: "AC/battery condition"
                value: root.scPower; onChanged: v => root.scPower = v }
            StepperRow { Layout.fillWidth: true; label: "Lid state match"; help: "open/closed condition"
                value: root.scLid; onChanged: v => root.scLid = v }
            PixButton {
                id: applyScoring
                Layout.fillWidth: true; Layout.preferredHeight: 32
                enabled: !Monitors.busy
                onClicked: Monitors.setScoring({ name_match: root.scName, description_match: root.scDesc,
                    power_state_match: root.scPower, lid_state_match: root.scLid })
                PixText { anchors.centerIn: parent; text: "Apply scoring"; font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small; color: applyScoring.contentColor }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

            // notifications
            PixText { text: "NOTIFICATIONS"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            PixButton {
                id: notifBtn
                Layout.fillWidth: true; Layout.preferredHeight: 32
                filled: root.notifOn
                onClicked: root.notifOn = !root.notifOn
                PixText { anchors.centerIn: parent
                    text: (root.notifOn ? "✓ " : "") + "Desktop notifications on profile switch"
                    font.pixelSize: PixTheme.font.pixelSize.small; color: notifBtn.contentColor }
            }
            StepperRow { Layout.fillWidth: true; label: "Timeout (ms)"; value: root.notifTimeout
                from: 0; to: 60000; step: 1000; onChanged: v => root.notifTimeout = v }
            PixButton {
                id: applyNotif
                Layout.fillWidth: true; Layout.preferredHeight: 32
                enabled: !Monitors.busy
                onClicked: Monitors.setNotifications({ disabled: !root.notifOn, timeout_ms: root.notifTimeout })
                PixText { anchors.centerIn: parent; text: "Apply notifications"; font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.small; color: applyNotif.contentColor }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

            // read-only info
            PixText { text: "INFO"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            PixText { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smallest
                text: "Destination: " + (Monitors.destination || "?") }
            PixText { Layout.fillWidth: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smallest
                text: "Debounce: " + (Monitors.general && Monitors.general.debounce_time_ms !== undefined
                    && Monitors.general.debounce_time_ms !== null ? Monitors.general.debounce_time_ms + " ms" : "default") }

            Item { Layout.preferredHeight: 4 }
        }
    }
}
