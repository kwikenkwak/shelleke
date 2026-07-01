pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Backing service for the pixel "Displays" overlay: a thin bridge to
 * hyprdynamicmonitors via scripts/monitors/hdm-control.py.
 *
 * All state comes from the script's `state` subcommand (one JSON blob). Actions
 * (quick/clear/freeze/validate/reapply/reload) run the script and re-`refresh()`
 * afterwards. The service itself never edits monitors.conf or the user's profiles;
 * see hdm-control.py for the safety model.
 */
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/monitors/hdm-control.py")

    // ---- snapshot (populated by `state`) ----
    property var monitors: []
    property var profiles: []
    property string activeProfile: ""
    property bool daemonRunning: false
    property bool quickActive: false
    property string quickMode: ""
    property string quickTarget: ""
    property string destination: ""

    // ---- action feedback ----
    property bool busy: false
    property string lastMessage: ""
    property bool lastOk: true
    signal actionFinished(bool ok, string message)

    // Debounced: monitor plug/unplug and quick actions trigger a storm of Hyprland
    // events while Quickshell is rebuilding per-screen surfaces. Coalesce refreshes
    // (each spawns an HDM dry-run) so we don't pile heavy work into that window.
    function refresh() {
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!stateProc.running)
                stateProc.running = true;
            else
                refreshTimer.restart(); // still busy; try again shortly
        }
    }

    Process {
        id: stateProc
        command: ["python3", root.script, "state"]
        stdout: StdioCollector {
            id: stateOut
            onStreamFinished: root._parseState(stateOut.text)
        }
    }

    function _parseState(text) {
        try {
            const s = JSON.parse(text);
            // Only reassign the Repeater-backing arrays when they actually changed,
            // to avoid needless delegate teardown/rebuild (see crash note in git log).
            const nextMon = s.monitors ?? [];
            if (JSON.stringify(nextMon) !== JSON.stringify(root.monitors))
                root.monitors = nextMon;
            const nextProf = s.profiles ?? [];
            if (JSON.stringify(nextProf) !== JSON.stringify(root.profiles))
                root.profiles = nextProf;
            root.activeProfile = s.active_profile ?? "";
            root.daemonRunning = s.daemon_running ?? false;
            root.quickActive = s.quick ? (s.quick.active ?? false) : false;
            root.quickMode = s.quick ? (s.quick.mode ?? "") : "";
            root.quickTarget = s.quick ? (s.quick.single_target ?? "") : "";
            root.destination = s.destination ?? "";
        } catch (e) {
            console.warn("Monitors: failed to parse state:", e);
        }
    }

    // ---- action runner (serialized via `busy`) ----
    Process {
        id: actionProc
        property string label: ""
        stdout: StdioCollector {
            id: actionOut
            onStreamFinished: {
                let ok = false;
                let msg = actionProc.label;
                try {
                    const r = JSON.parse(actionOut.text);
                    ok = r.ok ?? false;
                    msg = r.msg ?? r.error ?? msg;
                } catch (e) {}
                root.busy = false;
                root.lastOk = ok;
                root.lastMessage = msg;
                root.actionFinished(ok, msg);
                root.refresh();
            }
        }
    }

    function _run(args, label) {
        if (root.busy)
            return;
        root.busy = true;
        actionProc.label = label;
        actionProc.command = ["python3", root.script].concat(args);
        actionProc.running = true;
    }

    // mode: "extend" | "mirror" | "single". target only meaningful for "single".
    function setQuick(mode, target) {
        _run(target ? ["quick", mode, target] : ["quick", mode], "Set " + mode);
    }
    function clearQuick() {
        _run(["clear"], "Back to auto");
    }
    function freeze(name) {
        _run(["freeze", name], "Save profile");
    }
    function validate() {
        _run(["validate"], "Validate");
    }
    function reapply() {
        _run(["reapply"], "Reapply");
    }
    function reload() {
        _run(["reload"], "Reload");
    }

    Component.onCompleted: refresh()

    // Re-read when monitors are plugged/unplugged.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2"].includes(event.name))
                root.refresh();
        }
    }
}
