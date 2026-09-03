pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Body of the "New worktree" dialog: name the task, tick the repos it touches, and pick
 * which vitulina servers get their own kitty tab. Below that, the tasks that already exist
 * — click one to get its terminal and tabs back without touching the working copies, or
 * press its "+" to load it above and give it another repo.
 * Both paths run scripts/worktrees/worktree-setup.py (see services/Worktrees.qml).
 *
 * An existing name is not an error, it is the way to ADD to a task: whenever the name
 * matches a task that is already there, its repos show up ticked and locked (they come
 * along regardless — see keep_existing_repos in worktree-setup.py) and only the newly
 * ticked ones are fetched, checked out and installed.
 *
 * A task's working copies are jj workspaces on a bookmark named after the task. Repos are
 * colocated on demand to make that possible, which is why `toColocate` is spelled out
 * before you press CREATE.
 */
PixPanel {
    id: root
    borderWidth: PixTheme.popupBorderWidth

    signal closeRequested

    readonly property int pad: 14
    readonly property int gap: 10
    implicitWidth: 440
    implicitHeight: Math.min(column.implicitHeight + 2 * pad, 900)

    // { repoName: [serverName, ...] } — replaced wholesale so bindings re-evaluate.
    property var sel: ({})

    readonly property string name: nameField.text.trim()
    readonly property bool nameValid: /^[A-Za-z0-9._-]+$/.test(root.name)

    // The existing task this name refers to, or null for a genuinely new one. Typing the
    // name of a task that is already there — which is what the reopen list's "+" does for
    // you — is how a repo gets added to it.
    readonly property var currentTask: Worktrees.tasks.find(t => t.name === root.name) ?? null
    readonly property bool extending: root.currentTask !== null
    // The repos that task already holds: kept whatever the ticks say, so their rows are
    // ticked and refuse to be unticked. A folder whose main ~/pleevi checkout has since
    // gone is left out here exactly as the script leaves it out of the tabs.
    readonly property var lockedRepos: (root.currentTask?.repos ?? []).filter(r => Worktrees.repos.some(x => x.name === r))
    // { repo: [server, …] } as that task's saved tabs run them.
    readonly property var taskServers: root.currentTask?.servers ?? ({})

    // Every repo this run writes a tab for: what is ticked plus what the task already has,
    // and of those the ones that still need checking out.
    readonly property var pickedRepos: {
        const out = root.lockedRepos.slice();
        for (const repo of Object.keys(root.sel))
            if (out.indexOf(repo) < 0)
                out.push(repo);
        return out;
    }
    readonly property var newRepos: root.pickedRepos.filter(r => root.lockedRepos.indexOf(r) < 0)

    readonly property int serverCount: root.pickedRepos.reduce((n, r) => n + root.serversFor(r).length, 0)
    // A selected repo with nothing to start (controller, or one whose servers you left
    // unticked) gets a plain tab in its worktree instead — see worktree-setup.py.
    readonly property int plainRepoTabs: root.pickedRepos.filter(r => root.serversFor(r).length === 0).length
    readonly property bool canCreate: root.nameValid && root.pickedRepos.length > 0 && !Worktrees.busy

    // Repos to be checked out that carry a package.json: they get `pnpm install` after
    // checkout and a SESSION_SECRET in front of their vitulina command. Only the new ones —
    // an existing workspace already has its node_modules.
    readonly property var nodeRepos: root.newRepos.filter(r => {
        const found = Worktrees.repos.find(x => x.name === r);
        return found ? (found.node ?? false) : false;
    })

    // What is on the line for one repo's servers: the ticks once it has been touched,
    // otherwise the tabs the task already runs for it.
    function serversFor(repo) {
        return root.sel[repo] ?? root.taskServers[repo] ?? [];
    }

    // What the new changes are cut from — usually main@origin for every repo, but say so
    // honestly if the discovered repos disagree.
    readonly property string baseLabel: {
        const bases = Array.from(new Set(Worktrees.repos.map(r => r.defaultBranch)));
        return bases.length === 1 ? "from " + bases[0] + "@origin" : "from origin default";
    }

    // Repos that still need `jj git init --colocate` before they can hand out workspaces.
    // Called out up front because it is the one thing here that touches a main checkout.
    // Only the new ones: a repo already in the task was colocated when it joined it.
    readonly property var toColocate: root.newRepos.filter(r => {
        const found = Worktrees.repos.find(x => x.name === r);
        return found ? !(found.jj ?? false) : false;
    })

    // The SETUP line is about the repos being checked out, so when a task is only being
    // reopened it has to say that rather than list steps nothing will run.
    readonly property string setupLabel: {
        if (root.extending && root.newRepos.length === 0)
            return "nothing to add — reopens the tabs";
        const steps = "jj workspace, copy .env, direnv allow"
            + (root.nodeRepos.length > 0 ? ", pnpm i (" + root.nodeRepos.join(", ") + ")" : "");
        return root.extending ? steps + " — " + root.newRepos.join(", ") + " only" : steps;
    }

    function toggleRepo(repo) {
        // A repo the task already holds cannot be dropped from here: unticking it would
        // neither remove the working copy nor stop it getting its tab back.
        if (root.lockedRepos.indexOf(repo) >= 0)
            return;
        const next = Object.assign({}, root.sel);
        if (next[repo] !== undefined)
            delete next[repo];
        else
            next[repo] = [];
        root.sel = next;
    }

    function toggleServer(repo, server) {
        const next = Object.assign({}, root.sel);
        // Seeded from serversFor, not from `sel`: the first chip clicked on a repo the task
        // already has must edit that repo's saved tabs rather than start from none of them.
        const servers = root.serversFor(repo).slice();
        const at = servers.indexOf(server);
        if (at >= 0)
            servers.splice(at, 1);
        else
            servers.push(server);
        next[repo] = servers;
        root.sel = next;
    }

    // Put an existing task in the form so repos can be added to it. Its own repos need no
    // ticks — they follow from the name, via lockedRepos.
    function loadTask(task) {
        nameField.text = task;
        root.sel = ({});
        nameField.focusInput();
    }

    function submit() {
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
        function onFinished(ok, message) {
            // Kitty appearing is the confirmation, so get out of the way — unless
            // something needs reading (a failure, a reused worktree, an unreachable
            // remote), in which case stay open with the log.
            if (ok && Worktrees.lastWarnings.length === 0)
                root.closeRequested();
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.gap

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PixTitle {
                Layout.fillWidth: true
                // Says which of the two things this dialog is currently doing.
                text: root.extending ? "ADD TO " + root.name.toUpperCase() : "NEW WORKTREE"
                font.pixelSize: PixTheme.font.pixelSize.title
                elide: Text.ElideRight
            }
            PixButton {
                id: closeBtn
                implicitWidth: 34
                implicitHeight: 30
                onClicked: root.closeRequested()
                PixText {
                    anchors.centerIn: parent
                    text: "ESC"
                    font.pixelSize: PixTheme.font.pixelSize.smallest
                    color: closeBtn.contentColor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        // ---- NAME ----
        PixText {
            text: "TASK NAME"
            font.bold: true
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
        PixField {
            id: nameField
            Layout.fillWidth: true
            placeholder: "my-task"
            onAccepted: root.submit()
        }
        PixText {
            Layout.fillWidth: true
            visible: nameField.text.length > 0 && !root.nameValid
            text: "letters, digits, . _ - only"
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
        // Says why the rows below went ticked by themselves — and confirms the name matched.
        PixText {
            Layout.fillWidth: true
            visible: root.extending
            text: "existing task — its " + root.lockedRepos.length + " repo"
                + (root.lockedRepos.length === 1 ? "" : "s")
                + " stay as they are; tick the ones to add"
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }

        // ---- REPOS ----
        RowLayout {
            Layout.fillWidth: true
            PixText {
                Layout.fillWidth: true
                text: "REPOS"
                font.bold: true
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                text: root.baseLabel
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
        }
        Repeater {
            model: Worktrees.repos
            delegate: RepoRow {
                required property var modelData
                Layout.fillWidth: true
                repo: modelData.name
                servers: modelData.servers
                locked: root.lockedRepos.indexOf(modelData.name) >= 0
                selected: root.sel[modelData.name] !== undefined || locked
                pickedServers: root.serversFor(modelData.name)
                onToggled: root.toggleRepo(modelData.name)
                onServerToggled: server => root.toggleServer(modelData.name, server)
            }
        }
        PixText {
            Layout.fillWidth: true
            visible: Worktrees.repos.length === 0
            text: "No git repos found in ~/pleevi"
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }

        // Colocating is the only step that writes to a main ~/pleevi checkout, so it is
        // announced rather than done quietly. Additive and undone with `rm -rf .jj`.
        PixText {
            Layout.fillWidth: true
            visible: root.toColocate.length > 0
            text: "jj git init --colocate first: " + root.toColocate.join(", ")
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        // ---- SUMMARY ----
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 3

            PixText {
                text: "PATH"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                text: "~/pleevi/" + (root.nameValid ? root.name : "…")
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideMiddle
            }
            PixText {
                text: "BOOKMARK"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                text: root.nameValid ? root.name : "…"
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
            }
            PixText {
                text: "ENV"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                text: "vitulina up --env " + (root.nameValid ? root.name : "…")
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
            }
            // The two rows only an existing task has: what is being added to it, and what it
            // keeps untouched.
            PixText {
                visible: root.extending
                text: "ADDING"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                visible: root.extending
                text: root.newRepos.length > 0 ? root.newRepos.join(", ") : "—"
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
            }
            PixText {
                visible: root.extending
                text: "KEEPING"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                visible: root.extending
                text: root.lockedRepos.length > 0 ? root.lockedRepos.join(", ") : "—"
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
            }
            PixText {
                text: "SETUP"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                text: root.setupLabel
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }
            PixText {
                text: "TABS"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            PixText {
                Layout.fillWidth: true
                text: (2 + root.serverCount + root.plainRepoTabs) + ": shell, claude"
                    + (root.serverCount > 0 ? ", " + root.serverCount + " vitulina" : "")
                    + (root.plainRepoTabs > 0 ? ", " + root.plainRepoTabs + " repo" : "")
                font.pixelSize: PixTheme.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        // ---- ACTIONS ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PixButton {
                id: createBtn
                Layout.fillWidth: true
                implicitHeight: 34
                interactive: root.canCreate
                fillOnHover: root.canCreate
                onClicked: root.submit()
                PixText {
                    anchors.centerIn: parent
                    // Three verbs for the one action: the same press does three different
                    // things depending on what the name matched.
                    text: Worktrees.busy ? "WORKING…"
                        : !root.extending ? "CREATE"
                        : root.newRepos.length > 0 ? "ADD" : "REOPEN"
                    font.bold: true
                    font.pixelSize: PixTheme.font.pixelSize.normal
                    color: root.canCreate || Worktrees.busy
                        ? createBtn.contentColor : PixTheme.colors.grey2
                }
            }
            PixButton {
                id: cancelBtn
                implicitHeight: 34
                implicitWidth: 84
                onClicked: root.closeRequested()
                PixText {
                    anchors.centerIn: parent
                    text: "CANCEL"
                    font.pixelSize: PixTheme.font.pixelSize.normal
                    color: cancelBtn.contentColor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: PixTheme.borderWidth
            color: PixTheme.colors.line
        }

        // ---- REOPEN ----
        RowLayout {
            Layout.fillWidth: true
            PixText {
                Layout.fillWidth: true
                text: "REOPEN"
                font.bold: true
                color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
            // The count, plus what the row's second button is for — the only place the
            // dialog can say so without a legend.
            PixText {
                text: Worktrees.tasks.length + " task" + (Worktrees.tasks.length === 1 ? "" : "s") + " · + ADDS REPOS"
                color: PixTheme.colors.grey2
                font.pixelSize: PixTheme.font.pixelSize.smaller
            }
        }
        PixText {
            Layout.fillWidth: true
            visible: Worktrees.tasks.length === 0
            text: "No task folders in ~/pleevi yet"
            color: PixTheme.colors.grey2
            font.pixelSize: PixTheme.font.pixelSize.smaller
        }
        Flickable {
            id: taskFlick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(taskColumn.implicitHeight, 150)
            visible: Worktrees.tasks.length > 0
            clip: true
            contentWidth: width
            contentHeight: taskColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: taskColumn
                width: taskFlick.width
                spacing: 6

                Repeater {
                    model: Worktrees.tasks
                    delegate: TaskRow {
                        required property var modelData
                        Layout.fillWidth: true
                        task: modelData.name
                        repos: modelData.repos
                        tabCount: (modelData.tabs ?? []).length
                        interactive: !Worktrees.busy
                        // The task this dialog is currently adding to.
                        loaded: root.extending && modelData.name === root.name
                        // Reopen only — no fetch, no install; see worktree-setup.py.
                        onActivated: Worktrees.open(modelData.name)
                        // The "+" instead loads it above, where the repos it does not have
                        // yet can be ticked and added.
                        onExtendRequested: root.loadTask(modelData.name)
                    }
                }
            }
        }

        // ---- LOG ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(logText.implicitHeight + 12, 120)
            visible: Worktrees.log.length > 0 || Worktrees.lastError.length > 0
            radius: 0
            antialiasing: false
            color: "transparent"
            border.width: PixTheme.borderWidth
            border.color: Worktrees.lastOk ? PixTheme.colors.line : PixTheme.colors.fg

            Flickable {
                id: logFlick
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                contentWidth: width
                contentHeight: logText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                PixText {
                    id: logText
                    width: logFlick.width
                    text: Worktrees.lastError.length > 0 && !Worktrees.lastOk
                        ? (Worktrees.log.length > 0
                            ? Worktrees.log + "\n" + Worktrees.lastError
                            : Worktrees.lastError)
                        : Worktrees.log
                    wrapMode: Text.WordWrap
                    color: Worktrees.lastOk ? PixTheme.colors.grey : PixTheme.colors.fg
                    font.pixelSize: PixTheme.font.pixelSize.smaller
                }
            }
        }
    }
}
