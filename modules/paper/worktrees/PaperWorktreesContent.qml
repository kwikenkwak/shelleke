pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * Body of the "New worktree" dialog: name the task, tick the repos it touches,
 * pick which vitulina servers get their own kitty tab. Below the Create button,
 * the tasks that already exist — click one to get its terminal and tabs back
 * without touching the working copies, or press its `plus` to load it into the
 * entry above and give it another repo.
 *
 * This is the surface where the ledger metaphor is most literal: everything
 * above Create is the entry being written, everything below it is the record of
 * what has already been written — and an existing name is how you *amend* an
 * entry: whenever the name matches a task that is already there, the sheet turns
 * from "new task" into "add repos to that task". Its current repos are then
 * ticked and locked (they come along regardless — see keep_existing_repos in
 * worktree-setup.py) and only the newly ticked ones are cut, installed and
 * added; nothing already in the folder is touched.
 *
 * A task's working copies are jj workspaces on a bookmark named after the task.
 * Repos are colocated on demand to make that possible, which is why `toColocate`
 * is spelled out before you press CREATE — it is the one step that writes to a
 * main ~/pleevi checkout. Both paths run scripts/worktrees/worktree-setup.py via
 * services/Worktrees.qml; this file never shells out itself.
 */
PaperPanel {
    id: root

    signal closeRequested

    readonly property real pad: PaperTheme.pad.dialog
    readonly property real gap: PaperTheme.pick(14, 10, 11)

    kind: "sheet"
    floating: true
    ticks: true
    implicitWidth: PaperTheme.size.worktrees
    implicitHeight: Math.min(column.implicitHeight + 2 * root.pad, PaperTheme.size.worktreesMax)

    // { repoName: [serverName, …] } — replaced wholesale so bindings re-evaluate.
    property var sel: ({})

    readonly property string name: nameField.text.trim()
    readonly property bool nameValid: /^[A-Za-z0-9._-]+$/.test(root.name)

    /// The existing task this name refers to, or null for a genuinely new one.
    /// Typing the name of a task that is already there — which is what the
    /// reopen list's `plus` does for you — is how a repo gets added to it.
    readonly property var currentTask: Worktrees.tasks.find(t => t.name === root.name) ?? null
    readonly property bool extending: root.currentTask !== null
    /// The repos that task already holds. Kept whatever the ticks say, so their
    /// rows are ticked and refuse to be unticked; a folder whose main ~/pleevi
    /// checkout has since gone is left out here exactly as the script leaves it
    /// out of the tabs.
    readonly property var lockedRepos: (root.currentTask?.repos ?? []).filter(r => Worktrees.repos.some(x => x.name === r))
    /// { repo: [server, …] } as that task's saved tabs run them.
    readonly property var taskServers: root.currentTask?.servers ?? ({})

    /// Every repo this run writes a tab for: what is ticked plus what the task
    /// already has, and of those the ones that still need checking out.
    readonly property var pickedRepos: {
        const out = root.lockedRepos.slice();
        for (const repo of Object.keys(root.sel))
            if (out.indexOf(repo) < 0)
                out.push(repo);
        return out;
    }
    readonly property var newRepos: root.pickedRepos.filter(r => root.lockedRepos.indexOf(r) < 0)

    readonly property int serverCount: root.pickedRepos.reduce((n, r) => n + root.serversFor(r).length, 0)
    /// A selected repo with nothing to start (the controller, or one whose
    /// servers you left unticked) gets a plain tab in its worktree instead.
    readonly property int plainRepoTabs: root.pickedRepos.filter(r => root.serversFor(r).length === 0).length
    readonly property bool canCreate: root.nameValid && root.pickedRepos.length > 0 && !Worktrees.busy

    /// Repos to be checked out that carry a package.json: they get `pnpm install`
    /// after checkout and a SESSION_SECRET in front of their vitulina command.
    /// Only the new ones — an existing workspace already has its node_modules.
    readonly property var nodeRepos: root.newRepos.filter(r => {
        const found = Worktrees.repos.find(x => x.name === r);
        return found ? (found.node ?? false) : false;
    })

    /// What is on the line for one repo's servers: the ticks once it has been
    /// touched, otherwise the tabs the task already runs for it.
    function serversFor(repo: string): var {
        return root.sel[repo] ?? root.taskServers[repo] ?? [];
    }

    /// What the new changes are cut from — usually main@origin for every repo,
    /// but say so honestly if the discovered repos disagree.
    readonly property string baseLabel: {
        const bases = Array.from(new Set(Worktrees.repos.map(r => r.defaultBranch)));
        return bases.length === 1 ? "from " + bases[0] + "@origin" : "from origin default";
    }

    /// Repos that still need `jj git init --colocate` before they can hand out
    /// workspaces. Called out up front; additive, and undone with `rm -rf .jj`.
    /// Only the new ones: a repo already in the task was colocated when it
    /// joined it.
    readonly property var toColocate: root.newRepos.filter(r => {
        const found = Worktrees.repos.find(x => x.name === r);
        return found ? !(found.jj ?? false) : false;
    })

    /// The Setup line, which is about the repos being checked out — so when a
    /// task is only being reopened it has to say that rather than list steps
    /// nothing will run.
    readonly property string setupLabel: {
        if (root.extending && root.newRepos.length === 0)
            return "nothing to add — reopens the tabs";
        const steps = "jj workspace, copy .env, direnv allow" + (root.nodeRepos.length > 0 ? ", pnpm i (" + root.nodeRepos.join(", ") + ")" : "");
        return root.extending ? steps + " — " + root.newRepos.join(", ") + " only" : steps;
    }

    function toggleRepo(repo: string): void {
        // A repo the task already holds cannot be dropped from here: unticking
        // it would neither remove the working copy nor stop it getting its tab
        // back, so the row stays ticked and the click does nothing.
        if (root.lockedRepos.indexOf(repo) >= 0)
            return;
        const next = Object.assign({}, root.sel);
        if (next[repo] !== undefined)
            delete next[repo];
        else
            next[repo] = [];
        root.sel = next;
    }

    function toggleServer(repo: string, server: string): void {
        const next = Object.assign({}, root.sel);
        // Seeded from serversFor, not from `sel`: the first chip clicked on a
        // repo the task already has must edit that repo's saved tabs rather
        // than start from none of them.
        const servers = root.serversFor(repo).slice();
        const at = servers.indexOf(server);
        if (at >= 0)
            servers.splice(at, 1);
        else
            servers.push(server);
        next[repo] = servers;
        root.sel = next;
    }

    /// Put an existing task in the entry above so repos can be added to it. Its
    /// own repos need no ticks — they follow from the name, via lockedRepos.
    function loadTask(task: string): void {
        nameField.text = task;
        root.sel = ({});
        nameField.focusInput();
    }

    function submit(): void {
        if (!root.canCreate)
            return;
        Worktrees.create(root.name, root.pickedRepos.map(r => ({
                    name: r,
                    servers: root.serversFor(r)
                })));
    }

    Component.onCompleted: {
        Worktrees.refresh();
        nameField.focusInput();
    }

    Connections {
        target: Worktrees
        function onFinished(ok: bool, message: string): void {
            // Kitty appearing is the confirmation, so get out of the way —
            // unless something needs reading (a failure, a reused worktree, an
            // unreachable remote), in which case stay open with the log.
            if (ok && Worktrees.lastWarnings.length === 0)
                root.closeRequested();
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap

        // ---- masthead ----
        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.spacing.small

            PaperTitle {
                Layout.fillWidth: true
                // The masthead is the honest place to say which of the two
                // things this sheet is currently doing.
                text: root.extending ? "Add to " + root.name : "New worktree"
                elide: Text.ElideRight
            }
            PaperButton {
                label: "Esc"
                onClicked: root.closeRequested()
            }
        }
        PaperRule {
            Layout.fillWidth: true
            // Broadsheet's masthead sits on an Oxford rule; the other two get
            // the plain hairline this degrades to.
            weight: "oxford"
        }

        // ---- task name ----
        PaperField {
            id: nameField
            Layout.fillWidth: true
            label: "Task name"
            placeholder: "my-task"
            invalid: nameField.text.length > 0 && !root.nameValid
            invalidMessage: "letters, digits, . _ - only"
            // Hairline and broadsheet print the rule as a standing footnote;
            // ledger only shows it when the entry is actually wrong.
            hint: PaperTheme.isLedger ? "" : "letters, digits, . _ - only"
            onAccepted: root.submit()
        }

        // Says why the rows below went ticked by themselves. Only an existing
        // name does this, so it is also the confirmation that the name matched.
        PaperText {
            Layout.fillWidth: true
            visible: root.extending
            text: "existing task — its " + root.lockedRepos.length + " repo" + (root.lockedRepos.length === 1 ? "" : "s") + " stay as they are; tick the ones to add"
            role: "meta"
            tone: "accent"
            footnote: true
            wrapMode: Text.WordWrap
        }

        // ---- repos ----
        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Repos"
            meta: root.baseLabel
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.pick(0, PaperTheme.gap.tile, PaperTheme.gap.tile)

            Repeater {
                model: Worktrees.repos

                delegate: WtRepoRow {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    repo: modelData.name
                    servers: modelData.servers
                    separator: index < Worktrees.repos.length - 1
                    locked: root.lockedRepos.indexOf(modelData.name) >= 0
                    selected: root.sel[modelData.name] !== undefined || locked
                    pickedServers: root.serversFor(modelData.name)
                    onToggled: root.toggleRepo(modelData.name)
                    onServerToggled: server => root.toggleServer(modelData.name, server)
                }
            }
        }
        PaperEmpty {
            Layout.fillWidth: true
            visible: Worktrees.repos.length === 0
            text: "No git repos found in ~/pleevi"
        }

        // Colocating is the only step that writes to a main ~/pleevi checkout,
        // so it is announced rather than done quietly.
        PaperText {
            Layout.fillWidth: true
            visible: root.toColocate.length > 0
            text: root.toColocate.join(", ") + " need jj git init --colocate first"
            role: "meta"
            tone: "ink4"
            footnote: true
            wrapMode: Text.WordWrap
        }

        // ---- summary ----
        PaperRule {
            Layout.fillWidth: true
            // Broadsheet closes the entry block with a double rule.
            weight: "double"
        }
        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Summary"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PaperKV {
                Layout.fillWidth: true
                key: "Path"
                value: "~/pleevi/" + (root.nameValid ? root.name : "…")
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Bookmark"
                value: root.nameValid ? root.name : "…"
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Env"
                value: "vitulina up --env " + (root.nameValid ? root.name : "…")
            }
            // The two lines that only an amended entry has: what is being added
            // to the task, and what it keeps untouched.
            PaperKV {
                Layout.fillWidth: true
                visible: root.extending
                key: "Adding"
                value: root.newRepos.length > 0 ? root.newRepos.join(", ") : "—"
            }
            PaperKV {
                Layout.fillWidth: true
                visible: root.extending
                key: "Keeping"
                value: root.lockedRepos.length > 0 ? root.lockedRepos.join(", ") : "—"
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Setup"
                value: root.setupLabel
            }
            PaperKV {
                Layout.fillWidth: true
                key: "Tabs"
                value: (2 + root.serverCount + root.plainRepoTabs) + " — shell, claude" + (root.serverCount > 0 ? ", " + root.serverCount + " vitulina" : "") + (root.plainRepoTabs > 0 ? ", " + root.plainRepoTabs + " repo" : "")
            }
        }

        // ---- actions ----
        RowLayout {
            Layout.fillWidth: true
            spacing: PaperTheme.pick(PaperTheme.spacing.huge, PaperTheme.gap.chip, PaperTheme.gap.chip)

            PaperButton {
                // Full width where a button is a box; natural width in hairline,
                // where the underline has to land under the word.
                Layout.fillWidth: !PaperTheme.isHairline
                Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                // The single committing action on this surface.
                primary: true
                // Ledger puts a `plus` on the verb; the others keep it plain.
                icon: PaperTheme.isLedger ? "plus" : ""
                // Three verbs for the one action, because the same press does
                // three different things depending on what the name matched.
                label: Worktrees.busy ? "Working…" : !root.extending ? "Create" : root.newRepos.length > 0 ? "Add" : "Reopen"
                enabled: root.canCreate
                onClicked: root.submit()
            }
            PaperButton {
                Layout.preferredWidth: PaperTheme.pick(-1, 90, 88)
                Layout.preferredHeight: PaperTheme.pick(24, 30, 32)
                label: "Cancel"
                onClicked: root.closeRequested()
            }
            Item {
                Layout.fillWidth: PaperTheme.isHairline
            }
        }

        // ---- reopen ----
        PaperRule {
            Layout.fillWidth: true
        }
        PaperSectionHeader {
            Layout.fillWidth: true
            label: "Reopen"
            // The count, plus what the row's second button is for — the only
            // place the sheet can say so without a legend.
            meta: Worktrees.tasks.length + " task" + (Worktrees.tasks.length === 1 ? "" : "s") + " · + adds repos"
        }
        PaperEmpty {
            Layout.fillWidth: true
            visible: Worktrees.tasks.length === 0
            text: "No task folders in ~/pleevi yet"
        }
        Flickable {
            id: taskFlick
            Layout.fillWidth: true
            // fillHeight + a maximum equal to the preferred height: the list can
            // give space back when the sheet hits its 900 px cap, but it never
            // grows past 150 px.
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(taskColumn.implicitHeight, 150)
            Layout.maximumHeight: Math.min(taskColumn.implicitHeight, 150)
            visible: Worktrees.tasks.length > 0
            clip: true
            contentWidth: width
            contentHeight: taskColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: taskColumn
                width: taskFlick.width
                spacing: PaperTheme.pick(0, 0, PaperTheme.spacing.hair)

                Repeater {
                    model: Worktrees.tasks

                    delegate: WtTaskRow {
                        required property var modelData

                        Layout.fillWidth: true
                        task: modelData.name
                        repos: modelData.repos
                        tabCount: (modelData.tabs ?? []).length
                        enabled: !Worktrees.busy
                        // The row this sheet is currently amending.
                        loaded: root.extending && modelData.name === root.name
                        // Reopen only — no fetch, no install.
                        onActivated: Worktrees.open(modelData.name)
                        // The `plus` instead loads it above, where the repos it
                        // does not have yet can be ticked and added.
                        onExtendRequested: root.loadTask(modelData.name)
                    }
                }
            }
        }

        // ---- log ----
        // Hairline is the only variant that gives the log a section head; the
        // other two let the well's own tone announce it.
        PaperSectionHeader {
            Layout.fillWidth: true
            visible: PaperTheme.isHairline && logBox.visible
            label: "Log"
        }
        PaperPanel {
            id: logBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(logText.implicitHeight + 2 * PaperTheme.spacing.small, PaperTheme.pick(118, 104, 120))
            Layout.maximumHeight: Layout.preferredHeight
            visible: Worktrees.log.length > 0 || Worktrees.lastError.length > 0
            kind: "well"
            // On failure the frame turns alert; the sheet itself never changes
            // colour, and the failing lines carry the alert ink themselves.
            frameTone: Worktrees.lastOk ? "" : "alert"

            Flickable {
                id: logFlick
                anchors.fill: parent
                anchors.margins: PaperTheme.spacing.small
                clip: true
                contentWidth: width
                contentHeight: logText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                PaperText {
                    id: logText
                    width: logFlick.width
                    text: (Worktrees.lastError.length > 0 && !Worktrees.lastOk) ? (Worktrees.log.length > 0 ? Worktrees.log + "\n" + Worktrees.lastError : Worktrees.lastError) : Worktrees.log
                    role: "meta"
                    mono: true
                    tone: Worktrees.lastOk ? "ink3" : "alert"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.5
                }
            }
        }
    }
}
