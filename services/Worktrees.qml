pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Backing service for the pixel "New worktree" overlay: a thin bridge to
 * scripts/worktrees/worktree-setup.py.
 *
 * `repos` is the list of git checkouts under ~/pleevi, each with its vitulina server names
 * (empty for repos without a .vitulina.yaml) and whether it is colocated with jj yet.
 * `create()` makes one folder per task with a jj workspace per selected repo and opens kitty
 * with the requested tabs; the script's stderr streams into `log` so the overlay can show
 * progress while it runs.
 *
 * `create()` on the name of a task that already exists is how a repo is *added* to it: the
 * script keeps everything already in the folder and only sets up what is new. `tasks` gives
 * each task the repos it holds and the servers its saved tabs run, which is what lets the
 * overlay show that selection before adding to it.
 */
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/worktrees/worktree-setup.py")

    property var repos: []
    // Task folders that already exist, newest first — each one reopenable by name.
    property var tasks: []
    property bool busy: false
    property string log: ""
    property bool lastOk: true
    property string lastError: ""
    property var lastResult: null
    // Things the run wants to report but that are not failures (a worktree that already
    // existed, a fetch that could not reach the remote). Kept apart from `log`, which
    // also carries plain progress, so the dialog can tell "nothing to see" from "read me".
    property var lastWarnings: []
    signal finished(bool ok, string message)

    function refresh() {
        if (!reposProc.running)
            reposProc.running = true;
        if (!tasksProc.running)
            tasksProc.running = true;
    }

    function _run(args) {
        if (root.busy)
            return;
        root.log = "";
        root.lastError = "";
        root.lastResult = null;
        root.lastWarnings = [];
        root.lastOk = true;
        createProc.command = ["python3", root.script].concat(args);
        root.busy = true;
        createProc.running = true;
    }

    /**
     * selection: [{ name: "dashboard", servers: ["ems"] }, ...]
     *
     * An existing task name adds to it rather than failing — the repos already in the folder
     * are kept and left alone whether or not the selection names them.
     */
    function create(name, selection) {
        root._run(["create", JSON.stringify({
            name: name,
            repos: selection
        })]);
    }

    /** Reopen an existing task's terminal — same tabs, same commands, no setup rerun. */
    function open(name) {
        root._run(["open", name]);
    }

    Process {
        id: reposProc
        command: ["python3", root.script, "repos"]
        stdout: StdioCollector {
            id: reposOut
            onStreamFinished: {
                try {
                    root.repos = JSON.parse(reposOut.text).repos ?? [];
                } catch (e) {
                    root.repos = [];
                }
            }
        }
    }

    Process {
        id: tasksProc
        command: ["python3", root.script, "tasks"]
        stdout: StdioCollector {
            id: tasksOut
            onStreamFinished: {
                try {
                    root.tasks = JSON.parse(tasksOut.text).tasks ?? [];
                } catch (e) {
                    root.tasks = [];
                }
            }
        }
    }

    Process {
        id: createProc
        stdout: StdioCollector {
            id: createOut
            onStreamFinished: root._parseResult(createOut.text)
        }
        stderr: SplitParser {
            onRead: line => root.log += (root.log.length > 0 ? "\n" : "") + line
        }
        onExited: (code, status) => {
            root.busy = false;
            if (root.lastResult === null) {
                // Script died before printing its JSON result (traceback, missing python).
                root.lastOk = false;
                root.lastError = "Setup script failed (exit " + code + ")";
                root.finished(false, root.lastError);
            }
        }
    }

    function _parseResult(text) {
        let result = null;
        try {
            result = JSON.parse(text);
        } catch (e) {
            return; // onExited reports the failure
        }
        root.lastResult = result;
        root.lastOk = result.ok ?? false;
        root.lastError = result.error ?? "";
        root.lastWarnings = result.warnings ?? [];
        for (const warning of root.lastWarnings)
            root.log += (root.log.length > 0 ? "\n" : "") + warning;
        // A run changes both lists — a new task folder, a repo now colocated with jj, a task
        // that grew a repo — and the dialog stays open whenever there is a warning to read,
        // so it must not be left showing the state from before the run.
        if (root.lastOk)
            root.refresh();
        root.finished(root.lastOk, root.lastOk ? (result.path ?? "") : root.lastError);
    }
}
