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
 * without touching the working copies.
 *
 * This is the surface where the ledger metaphor is most literal: everything
 * above Create is the entry being written, everything below it is the record of
 * what has already been written.
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
    readonly property var repoNames: Object.keys(root.sel)
    readonly property int serverCount: root.repoNames.reduce((n, r) => n + root.sel[r].length, 0)
    /// A selected repo with nothing to start (the controller, or one whose
    /// servers you left unticked) gets a plain tab in its worktree instead.
    readonly property int plainRepoTabs: root.repoNames.filter(r => root.sel[r].length === 0).length
    readonly property bool canCreate: root.nameValid && root.repoNames.length > 0 && !Worktrees.busy

    /// Selected repos carrying a package.json: they get `pnpm install` after
    /// checkout and a SESSION_SECRET in front of their vitulina command.
    readonly property var nodeRepos: root.repoNames.filter(r => {
        const found = Worktrees.repos.find(x => x.name === r);
        return found ? (found.node ?? false) : false;
    })

    /// What the new changes are cut from — usually main@origin for every repo,
    /// but say so honestly if the discovered repos disagree.
    readonly property string baseLabel: {
        const bases = Array.from(new Set(Worktrees.repos.map(r => r.defaultBranch)));
        return bases.length === 1 ? "from " + bases[0] + "@origin" : "from origin default";
    }

    /// Repos that still need `jj git init --colocate` before they can hand out
    /// workspaces. Called out up front; additive, and undone with `rm -rf .jj`.
    readonly property var toColocate: root.repoNames.filter(r => {
        const found = Worktrees.repos.find(x => x.name === r);
        return found ? !(found.jj ?? false) : false;
    })

    function toggleRepo(repo: string): void {
        const next = Object.assign({}, root.sel);
        if (next[repo] !== undefined)
            delete next[repo];
        else
            next[repo] = [];
        root.sel = next;
    }

    function toggleServer(repo: string, server: string): void {
        const next = Object.assign({}, root.sel);
        const servers = (next[repo] ?? []).slice();
        const at = servers.indexOf(server);
        if (at >= 0)
            servers.splice(at, 1);
        else
            servers.push(server);
        next[repo] = servers;
        root.sel = next;
    }

    function submit(): void {
        if (!root.canCreate)
            return;
        Worktrees.create(root.name, root.repoNames.map(r => ({
                    name: r,
                    servers: root.sel[r]
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
                text: "New worktree"
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
                    selected: root.sel[modelData.name] !== undefined
                    pickedServers: root.sel[modelData.name] ?? []
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
            PaperKV {
                Layout.fillWidth: true
                key: "Setup"
                value: "jj workspace, copy .env, direnv allow" + (root.nodeRepos.length > 0 ? ", pnpm i (" + root.nodeRepos.join(", ") + ")" : "")
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
                label: Worktrees.busy ? "Working…" : "Create"
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
            meta: Worktrees.tasks.length + " task" + (Worktrees.tasks.length === 1 ? "" : "s")
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
                        // Reopen only — no fetch, no install.
                        onActivated: Worktrees.open(modelData.name)
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
