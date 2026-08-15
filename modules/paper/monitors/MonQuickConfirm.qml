pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * "Keep this monitor setup?" — the dead-man's switch on a quick MODE change.
 *
 * A mode change is the one action in this overlay that can leave you unable to
 * see the screen you would need in order to undo it (Single hands the desktop to
 * one output; Mirror and Auto can move it too). So the change is applied
 * optimistically and then held for 15 s: Keep dismisses it, and Revert / the
 * countdown running out / closing the overlay all put the previous layout back
 * through Monitors.restoreQuick(snapshot).
 *
 * Usage — snapshot BEFORE the action, always in this order:
 *
 *     quickConfirm.arm();
 *     Monitors.setQuick(mode, target);
 *
 * Rules that matter:
 *   · a SECOND mode change while one is pending keeps the ORIGINAL snapshot (two
 *     hops still revert to where the user actually was) and merely restarts the
 *     countdown — never a second dialog stacked on the first;
 *   · the countdown is a plain Timer: it does not depend on the panel having
 *     focus, on hover, or on anything the user must still be able to click;
 *   · a change the script REFUSES (hdm-control.py's guards) was never applied, so
 *     the snapshot is dropped and no dialog appears.
 *
 * Per variant this is the family's ordinary modal: `scrim2` tracing paper over
 * the panel, a floating sheet (ticked in broadsheet), micro-caps verbs, and the
 * countdown set as a figure so the digits do not jitter as it ticks down.
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

    /// Where a revert would take us — the layout this dialog promises to restore.
    readonly property string revertLabel: {
        if (!root.snapshot)
            return "";
        if (!root.snapshot.active)
            return "Auto";
        const m = root.snapshot.mode;
        return m ? m.charAt(0).toUpperCase() + m.slice(1) : "Auto";
    }

    /// Call immediately BEFORE applying a quick mode change.
    function arm(): void {
        // A second change while one is pending keeps the first snapshot: the user
        // is walking away from where they started, not from the last hop.
        if (!root.pending)
            root.snapshot = Monitors.snapshotQuick();
        root.applying = true;
        root.secondsLeft = root.seconds;
        ticker.stop();
        watchdog.restart();
    }

    function keep(): void {
        root.snapshot = null;
        root.applying = false;
        ticker.stop();
        watchdog.stop();
    }

    /// Revert now. A no-op when nothing is pending, so it is safe to call from
    /// every teardown path.
    function revert(): void {
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
        function onActionFinished(ok: bool, message: string): void {
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
    function tick(): void {
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

    // Tracing paper over the panel; it also swallows every click behind the sheet.
    Rectangle {
        anchors.fill: parent
        color: PaperTheme.scrim2

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }
    }

    PaperPanel {
        id: sheet

        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * PaperTheme.spacing.medium, PaperTheme.pick(340, 320, 330))
        implicitHeight: content.implicitHeight + 2 * PaperTheme.pad.dialog
        kind: "sheet"
        floating: true
        ticks: true

        ColumnLayout {
            id: content

            anchors.centerIn: parent
            width: parent.width - 2 * PaperTheme.pad.dialog
            spacing: PaperTheme.spacing.small

            PaperTitle {
                Layout.fillWidth: true
                text: "Keep this monitor setup?"
                wrapMode: Text.WordWrap
            }

            PaperText {
                Layout.fillWidth: true
                text: "If you can read this, the layout works. Do nothing and it rolls back."
                role: "meta"
                tone: "ink3"
                wrapMode: Text.WordWrap
            }

            PaperRule {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperText {
                    Layout.fillWidth: true
                    text: root.applying ? "Applying…" : ("Reverting to " + root.revertLabel)
                    role: "meta"
                    tone: "ink2"
                    elide: Text.ElideRight
                }
                // The countdown. `figure` keeps the digits tabular so 15 → 9 does
                // not shuffle the line every second.
                PaperText {
                    text: root.applying ? "…" : (root.secondsLeft + " s")
                    role: "lead"
                    figure: true
                    tone: "ink"
                }
            }

            // A time bar rather than a second number: the sweep is readable from
            // across the desk, which is where the user will be standing.
            PaperMeter {
                Layout.fillWidth: true
                value: root.seconds > 0 ? root.secondsLeft / root.seconds : 0
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: PaperTheme.spacing.tiny
                spacing: PaperTheme.gap.chip

                Item {
                    Layout.fillWidth: true
                }
                PaperButton {
                    label: "Revert"
                    // Reverting is the safe half of this dialog, not the
                    // destructive one — the destructive thing already happened.
                    enabled: root.asking
                    onClicked: root.revert()
                }
                PaperButton {
                    label: "Keep"
                    primary: true
                    enabled: root.asking
                    onClicked: root.keep()
                }
            }
        }
    }
}
