pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * "Keep this monitor setup?" — the dead-man's switch on a quick MODE change.
 *
 * A mode change is the one action here that can leave you unable to see the
 * screen you would need in order to undo it (Single hands the desktop to one
 * output; Mirror and Auto can move it too). So every mode change is applied
 * optimistically and then held for 15 s: Keep dismisses, Revert / the countdown
 * running out / closing the overlay all put the previous layout back through
 * Monitors.restoreQuick(snapshot).
 *
 * Usage — snapshot BEFORE the action, always in this order:
 *
 *     quickConfirm.arm();
 *     Monitors.setQuick(mode, target);
 *
 * Rules that matter:
 *   · the snapshot is taken before the change, and a SECOND mode change while one
 *     is pending keeps the ORIGINAL snapshot (so two hops still revert to where
 *     the user actually was) and merely restarts the countdown — never a second
 *     dialog on top of the first;
 *   · the countdown is a plain Timer. It does not depend on the panel having
 *     focus, on hover, or on anything the user must still be able to click;
 *   · if the script REFUSES the change (hdm-control.py's guards), nothing was
 *     applied, so the snapshot is dropped and no dialog is shown.
 */
Item {
    id: root

    /// Seconds before an unconfirmed setup is rolled back.
    property int seconds: 15

    /// The revert point: non-null from arm() until keep()/revert().
    property var snapshot: null
    /// True while hdm-control.py is still applying the change we armed for.
    property bool applying: false
    property int secondsLeft: root.seconds

    /// A change is armed (being applied, or waiting to be confirmed).
    readonly property bool pending: root.snapshot !== null
    /// The dialog is up and asking.
    readonly property bool asking: root.pending && !root.applying

    visible: root.pending

    /// Where a revert would take us — the label the dialog promises.
    readonly property string revertLabel: {
        if (!root.snapshot)
            return "";
        if (!root.snapshot.active)
            return "Auto";
        const m = root.snapshot.mode;
        return m ? m.charAt(0).toUpperCase() + m.slice(1) : "Auto";
    }

    /// Call immediately BEFORE applying a quick mode change.
    function arm() {
        // A second change while one is pending keeps the first snapshot: the user
        // is walking away from where they started, not from the last hop.
        if (!root.pending)
            root.snapshot = Monitors.snapshotQuick();
        root.applying = true;
        root.secondsLeft = root.seconds;
        ticker.stop();
        watchdog.restart();
    }

    function keep() {
        root.snapshot = null;
        root.applying = false;
        ticker.stop();
        watchdog.stop();
    }

    /// Revert now. A no-op when nothing is pending, so it is safe to call from
    /// every teardown path.
    function revert() {
        if (!root.pending)
            return;
        const snap = root.snapshot;
        root.snapshot = null;
        root.applying = false;
        ticker.stop();
        watchdog.stop();
        Monitors.restoreQuick(snap);
    }

    // The overlay was closed with a change still unconfirmed: the user cannot
    // answer a dialog they can no longer see, so treat it as "no".
    Component.onDestruction: root.revert()

    Connections {
        target: Monitors
        function onActionFinished(ok, message) {
            if (!root.applying)
                return;
            root.applying = false;
            watchdog.stop();
            if (ok)
                ticker.restart();
            else
                root.snapshot = null; // refused — nothing changed, nothing to undo
        }
    }

    /// One second of the countdown. Split out from the Timer so the flow can be
    /// exercised without waiting on a wall clock.
    function tick() {
        root.secondsLeft -= 1;
        if (root.secondsLeft <= 0)
            root.revert();
    }

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        onTriggered: root.tick()
    }

    // The service serialises its actions and drops a call made while another is
    // in flight. That should not happen (the mode buttons are disabled while it
    // is busy), but a dropped call means no actionFinished, which would leave
    // this modal up for ever with no countdown. Time the apply out and answer it
    // the safe way instead.
    Timer {
        id: watchdog
        interval: 10000
        repeat: false
        onTriggered: {
            root.applying = false;
            root.revert();
        }
    }

    // Modal ground: dims the panel and swallows every click behind the dialog.
    Rectangle {
        anchors.fill: parent
        color: PixTheme.colors.bg
        opacity: 0.88
        radius: 0
        antialiasing: false

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }
    }

    PixPanel {
        id: box
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 320)
        implicitHeight: content.implicitHeight + 24

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 8

            PixTitle {
                Layout.fillWidth: true
                text: "KEEP THIS SETUP?"
                font.pixelSize: PixTheme.font.pixelSize.title
                wrapMode: Text.WordWrap
            }

            PixText {
                Layout.fillWidth: true
                text: "If you can read this, the layout works. Do nothing and it rolls back."
                font.pixelSize: PixTheme.font.pixelSize.smaller
                color: PixTheme.colors.grey
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // The countdown, big enough to read from across the desk.
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 34
                    color: "transparent"
                    border.width: PixTheme.borderWidth
                    border.color: PixTheme.colors.line
                    radius: 0
                    antialiasing: false

                    PixText {
                        anchors.centerIn: parent
                        text: root.applying ? "…" : String(root.secondsLeft)
                        font.pixelSize: PixTheme.font.pixelSize.large
                        color: PixTheme.colors.fg
                    }
                }

                PixText {
                    Layout.fillWidth: true
                    text: root.applying ? "Applying…" : ("Reverting to " + root.revertLabel)
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                    color: PixTheme.colors.grey
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PixButton {
                    id: revertBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    enabled: root.asking
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.revert()

                    PixText {
                        anchors.centerIn: parent
                        text: "Revert"
                        font.pixelSize: PixTheme.font.pixelSize.small
                        color: revertBtn.contentColor
                    }
                }
                PixButton {
                    id: keepBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    filled: true
                    enabled: root.asking
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.keep()

                    PixText {
                        anchors.centerIn: parent
                        text: "Keep"
                        font.pixelSize: PixTheme.font.pixelSize.small
                        color: keepBtn.contentColor
                    }
                }
            }
        }
    }
}
