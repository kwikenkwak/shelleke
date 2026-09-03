#!/usr/bin/env python3
"""
Backing script for the pixel "New worktree" overlay.

One task == one folder under ~/pleevi containing a jj workspace per related repo:

    ~/pleevi/<task>/pleevi_monorepo
    ~/pleevi/<task>/dashboard
    ...

Each workspace gets a bookmark named after the task on a fresh change cut from the repo's
freshly fetched <default branch>@origin, and is then made ready to run: the gitignored env
files are copied across, `direnv allow` (where the repo has an .envrc), and `pnpm install`
for the node repos — none of an untracked .env, .envrc trust, or node_modules carries over
into a new working copy. The task folder and every workspace under it also get a
`.claude/settings.local.json` pointing claude at one shared memory directory, see the note
below. Afterwards a single kitty window is opened on the task folder with one tab per thing
you need: a plain shell, claude, and one `vitulina up` tab per selected server.

A workspace that already exists is left exactly as it is — no fetch, no bookmark, no
install — and the run just reopens the kitty window and re-runs the commands. So running
this twice with the same task name is the way to get your tabs back, and running it with
an *extra* repo ticked is the way to add a repo to a task you already have: only the new
one is fetched, checked out and installed, and the repos already in the folder keep their
tabs (see keep_existing_repos, which puts them back into a selection that omits them).

Every git checkout in ~/pleevi is a candidate, whether or not it has a .vitulina.yaml —
that file only decides which servers it can offer. `controller` has none, so it gets a
workspace, `direnv allow`, and a plain tab in its directory to run cargo from.

Note on jj: the main ~/pleevi/<repo> checkouts are colocated (.jj beside .git), put there
on demand the first time a repo is picked, so git and jj both work in them. The per-task
workspaces are jj-only — jj refuses to colocate a workspace, see add_workspace() — so run
git/gh from the main checkout, not from a task folder. Tasks made before the switch are
still git worktrees and keep reopening unchanged; add_worktree() is also the fallback for a
repo that will not colocate.

Note on the vitulina env: jj and git both name a workspace/worktree after the *basename*
of its path, so `~/pleevi/<task>/dashboard` wants to register as "dashboard". vitulina
would therefore infer the repo name, not the task. We pass `--env <task>` explicitly so
every task gets its own isolated set of ports/hostnames — and `--name <task>` to jj for
the same reason, since there it is a hard conflict rather than a bad guess.

Note on SESSION_SECRET: the node dev servers refuse to boot without it, so their tabs run
`SESSION_SECRET=test vitulina up ...`. "node repo" == has a package.json, which is exactly
the set that gets `pnpm install` above (dashboard, pleevi_developer_portal). This is only
the floor: dashboard's copied .env carries the real value, and the tab applies .envrc after
this prefix, so where there is a real secret it wins.

Note on PATH: every tab starts with an `export PATH=<nvm node bin>:"$PATH"` prelude. See
node_bin_dir() — pnpm here is a lazy shell *function*, which vitulina's server processes
cannot inherit, so without this they die with "pnpm: command not found".

Note on the server tabs: they go through vitulina-tab.sh rather than running `vitulina up`
directly. Read the comment at the top of that file — it is the reason a tab whose server
was already running no longer looks like an empty terminal.

Note on claude's memory: claude keys its memory off the directory it is started in, so
without help every task folder — and every workspace inside it — would start from an empty
memory and forget what the last task learned. ensure_claude_settings() writes the setting
that redirects all of them to one shared directory, see its docstring.

Subcommands
  repos            JSON list of git checkouts in ~/pleevi that can get a worktree
  tasks            JSON list of task folders that already exist, newest first,
                   each with the servers its saved tabs run per repo
  create <json>    create the worktrees and open kitty; JSON result on stdout,
                   human-readable progress on stderr. An existing task name is
                   not an error: its repos are kept and the new ones added.
                   (--no-open writes the kitty session file but opens nothing; testing)
  open <name>      reopen an existing task's kitty window from its saved session file

create spec:
  {"name": "my-task", "repos": [{"name": "dashboard", "servers": ["ems"]}, ...]}
"""

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

PLEEVI_ROOT = Path.home() / "pleevi"
SESSION_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "pleevi-worktrees"
NAME_RE = re.compile(r"[A-Za-z0-9._-]+")


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def git(repo, *args, check=True):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, text=True, check=check,
    )


def jj_bin():
    """Absolute path to jj, or "" if it is not installed.

    Resolved rather than trusted to PATH: jj lives in ~/.cargo/bin, which .bashrc puts on
    PATH but Quickshell's own environment does not have.
    """
    found = shutil.which("jj")
    if found:
        return found
    fallback = Path.home() / ".cargo" / "bin" / "jj"
    return str(fallback) if fallback.exists() else ""


def jj(cwd, *args, check=True):
    return subprocess.run(
        [JJ, *args], cwd=str(cwd), capture_output=True, text=True, check=check,
    )


JJ = jj_bin()


# ---------------------------------------------------------------- discovery


def default_branch(repo):
    r = git(repo, "symbolic-ref", "refs/remotes/origin/HEAD", check=False)
    if r.returncode == 0:
        return r.stdout.strip().rsplit("/", 1)[-1]
    for candidate in ("main", "master"):
        if git(repo, "show-ref", "--verify", "--quiet",
               f"refs/remotes/origin/{candidate}", check=False).returncode == 0:
            return candidate
    return "main"


def servers_of(config):
    """Server names from a .vitulina.yaml, in file order."""
    try:
        data = yaml.safe_load(config.read_text()) or {}
    except Exception:
        return []
    out = []
    for server in data.get("servers") or []:
        if isinstance(server, dict) and server.get("name"):
            out.append(str(server["name"]))
    return out


def discover_repos():
    """Top-level dirs in ~/pleevi that are git checkouts.

    A .vitulina.yaml is what gives a repo servers to run, not what makes it a candidate:
    `controller` is a rust workspace with no vitulina config at all, and still wants its
    worktrees cut the same way as the rest. Repos without one simply have no servers.
    """
    if not PLEEVI_ROOT.is_dir():
        return []
    repos = []
    for path in sorted(PLEEVI_ROOT.iterdir()):
        if not path.is_dir() or not (path / ".git").exists():
            continue
        config = path / ".vitulina.yaml"
        repos.append({
            "name": path.name,
            "path": str(path),
            "servers": servers_of(config) if config.is_file() else [],
            "defaultBranch": default_branch(path),
            # Drives both `pnpm install` and the SESSION_SECRET prefix.
            "node": (path / "package.json").is_file(),
            # Already colocated, i.e. picking it needs no `jj git init` first.
            "jj": (path / ".jj").exists(),
        })
    return repos


# ---------------------------------------------------------------- create


def add_worktree(repo_path, branch, base, dest):
    """Create dest as a worktree of repo_path, reusing `branch` if it already exists.

    The pre-jj path, kept for repos that could not be put on jj (and for the tasks created
    before the switch, which keep reopening through the same session files).
    """
    exists = git(repo_path, "show-ref", "--verify", "--quiet",
                 f"refs/heads/{branch}", check=False).returncode == 0
    if exists:
        cmd = ["worktree", "add", str(dest), branch]
    else:
        cmd = ["worktree", "add", "-b", branch, str(dest), base]
    r = git(repo_path, *cmd, check=False)
    if r.returncode != 0:
        return False, (r.stderr.strip() or r.stdout.strip() or "git worktree add failed")
    return True, ("checked out existing branch " + branch if exists
                  else f"new branch {branch} from {base}")


def ensure_jj_repo(repo_path):
    """Make repo_path a colocated jj repo if it is not one already.

    Returns (ok, note-or-error). Colocating is additive: `jj git init --colocate` writes a
    .jj beside the existing .git and touches neither the git history nor the working copy,
    so doing it the first time a repo is picked is safe. Undo is `rm -rf .jj`.
    """
    if (repo_path / ".jj").exists():
        return True, None
    r = jj(repo_path, "git", "init", "--colocate", check=False)
    if r.returncode != 0:
        return False, last_line(r.stderr or r.stdout, "jj git init --colocate failed")
    return True, "now colocated with jj"


def jj_resolves(repo_path, revset):
    return jj(repo_path, "log", "-r", revset, "--no-graph", "-T", "",
              check=False).returncode == 0


def add_workspace(repo_path, task, base, dest):
    """Create dest as a jj workspace of repo_path — the jj answer to a git worktree.

    Note the mandatory `--name task`: jj, like git, names a workspace after the *basename*
    of its path, so every task's `~/pleevi/<task>/dashboard` would try to register as
    "dashboard" and the second task would be rejected outright. Same reasoning as the
    `--env <task>` we pass vitulina.

    The bookmark named after the task is what keeps this feeling like the branch-per-task
    it replaces: a jj bookmark follows its commit through rewrites, and the working copy is
    a commit that gets amended in place, so the bookmark tracks the work rather than being
    stranded at the first empty change.

    A colocated jj repo cannot contain colocated workspaces — jj refuses with "Cannot
    create a colocated jj repo inside a Git worktree" — so dest gets a .jj and no .git.
    Run git/gh from the main ~/pleevi/<repo> checkout, which stays colocated.
    """
    # An existing bookmark means this task was created before and its folder went away;
    # resume that line of work rather than cutting a second one from trunk.
    resume = jj_resolves(repo_path, task)
    start = task if resume else base
    if not jj_resolves(repo_path, start):
        # Checked up front because `jj workspace add` creates the directory *before* it
        # resolves -r, and would leave a workspace parented on the root commit behind.
        return False, f"revision {start} does not exist"

    r = jj(repo_path, "workspace", "add", "--name", task, "-r", start, str(dest),
           check=False)
    if r.returncode != 0 and "already exists" in (r.stderr + r.stdout):
        # Registered but its directory is gone: a task folder deleted by hand never told
        # jj about it. Drop the stale entry and take the name back.
        jj(repo_path, "workspace", "forget", task, check=False)
        r = jj(repo_path, "workspace", "add", "--name", task, "-r", start, str(dest),
               check=False)
    if r.returncode != 0:
        return False, last_line(r.stderr or r.stdout, "jj workspace add failed")

    if resume:
        # workspace add parents the new working copy *on* start; step onto the bookmarked
        # change itself so the old work is what you are editing.
        edited = jj(dest, "edit", task, check=False)
        if edited.returncode != 0:
            return True, f"jj workspace on {task} (left a new change on top of it)"
        return True, f"jj workspace resuming bookmark {task}"

    marked = jj(dest, "bookmark", "set", task, "-r", "@", check=False)
    if marked.returncode != 0:
        return True, (f"jj workspace from {base}, but bookmark {task} was not set: "
                      + last_line(marked.stderr or marked.stdout, "see jj bookmark set"))
    return True, f"new jj workspace + bookmark {task} from {base}"


def session_path(name):
    return SESSION_DIR / f"{name}.conf"


def session_tab_titles(session):
    """The tab titles recorded in a kitty session file, in order."""
    try:
        lines = session.read_text().splitlines()
    except OSError:
        return []
    return [line[len("new_tab "):].strip() for line in lines if line.startswith("new_tab ")]


def session_selection(name):
    """{repo: [server, …]} as recorded in a task's saved tabs.

    The inverse of the tab list `create` writes: a task's server picks live nowhere else,
    so this is how both the overlay (to show a task's repos already ticked before adding
    one) and keep_existing_repos recover them. A repo with a plain tab maps to [].
    """
    selection = {}
    for title in session_tab_titles(session_path(name)):
        if title in ("shell", "claude"):
            continue
        repo_name, _, server = title.partition(" ")
        servers = selection.setdefault(repo_name, [])
        if server and server not in servers:
            servers.append(server)
    return selection


def is_checkout(path):
    """Whether path is a working copy of something: a git worktree or a jj workspace.

    A jj workspace has only a .jj — jj cannot colocate one, see add_workspace() — so
    testing for .git alone would make every jj-era task folder look empty.
    """
    return (path / ".git").exists() or (path / ".jj").exists()


def discover_tasks():
    """Task folders under ~/pleevi: a plain directory holding at least one checkout.

    Repo checkouts themselves are skipped (they have their own .git/.jj), which also keeps
    their nested .claude/worktrees out of the list. Newest first, so the thing you were
    last working on is at the top.
    """
    if not PLEEVI_ROOT.is_dir():
        return []
    tasks = []
    for path in sorted(PLEEVI_ROOT.iterdir()):
        if not path.is_dir() or path.name.startswith(".") or is_checkout(path):
            continue
        repos = [p.name for p in sorted(path.iterdir()) if p.is_dir() and is_checkout(p)]
        if not repos:
            continue
        session = session_path(path.name)
        stamps = [path.stat().st_mtime]
        if session.is_file():
            stamps.append(session.stat().st_mtime)
        tasks.append({
            "name": path.name,
            "path": str(path),
            "repos": repos,
            # Which servers each of those repos runs, so adding a repo to this task can
            # show — and keep — the picks it was created with.
            "servers": session_selection(path.name),
            "tabs": session_tab_titles(session),
            "hasSession": session.is_file(),
            "mtime": max(stamps),
        })
    return sorted(tasks, key=lambda t: t["mtime"], reverse=True)


def node_bin_dir():
    """The directory holding the real pnpm/node binaries, or "" if it cannot be found.

    ~/.lazy-nvim.sh (sourced from .bashrc) exposes pnpm/node/npm as lazy *shell functions*
    that only fix up PATH once called interactively. Shell functions are not inherited by
    child processes, and Quickshell's own PATH has no node entry at all — so `vitulina up`
    would hand its servers an environment where `sh -c "pnpm run dev"` dies with
    "pnpm: command not found". Everything a tab spawns therefore needs the real directory
    on PATH, which means resolving it here rather than relying on the lazy function.
    """
    nvm_dir = Path(os.environ.get("NVM_DIR") or Path.home() / ".config" / "nvm")
    versions = nvm_dir / "versions" / "node"
    if not versions.is_dir():
        return ""

    def usable(path):
        return (path / "bin" / "pnpm").exists()

    alias = nvm_dir / "alias" / "default"
    if alias.is_file():
        want = alias.read_text().strip().lstrip("v")
        if want:
            for path in sorted(versions.glob(f"v{want}*")):
                if usable(path):
                    return str(path / "bin")

    installed = sorted(
        (p for p in versions.glob("v*") if usable(p)),
        key=lambda p: [int(n) for n in re.findall(r"\d+", p.name)[:3]],
    )
    return str(installed[-1] / "bin") if installed else ""


def path_prelude(node_bin):
    """Shell prelude putting node/pnpm within reach of anything a tab starts."""
    return f'export PATH={shlex.quote(node_bin)}:"$PATH"; ' if node_bin else ""


def user_shell(command, cwd, **kwargs):
    """Run `command` through a login+interactive bash so PATH matches a real terminal.

    ~/.bash_profile contributes bun, ~/.bashrc contributes node/pnpm and ~/.local/bin, and
    neither is on Quickshell's own PATH — so direnv/pnpm are only findable this way.
    """
    return subprocess.run(
        ["bash", "-lic", command], cwd=str(cwd), text=True,
        stdin=subprocess.DEVNULL, capture_output=True, **kwargs,
    )


def last_line(text, fallback):
    lines = [line for line in (text or "").strip().splitlines() if line.strip()]
    return lines[-1].strip() if lines else fallback


DOTENV_RE = re.compile(r"^\s*dotenv(?:_if_exists)?\s*(.*)$")


def env_file_names(repo_path):
    """Env files a fresh working copy needs but that git will never hand it.

    `.env` is gitignored in dashboard and pleevi_monorepo, so a new workspace starts without
    the vars their servers read — direnv says "`.env` at .env not found", carries on with the
    rest of the .envrc, and the tools come up misconfigured rather than failing loudly.

    On top of the conventional `.env`, anything the .envrc names with `dotenv` counts, so a
    repo that starts keeping its vars somewhere else is handled without editing this list.
    Tracked files are excluded by the caller: those arrive by themselves (controller's
    local.env is committed).
    """
    names = {".env"}
    envrc = repo_path / ".envrc"
    if envrc.is_file():
        try:
            lines = envrc.read_text().splitlines()
        except OSError:
            lines = []
        for line in lines:
            match = DOTENV_RE.match(line)
            if not match:
                continue
            # A bare `dotenv` means .env; anything else names its file.
            args = shlex.split(match.group(1), comments=True)
            names.add(args[0] if args else ".env")
    return names


def env_files_to_copy(repo_path):
    """Which of env_file_names() actually exist in the main checkout and are untracked."""
    out = []
    for name in sorted(env_file_names(repo_path)):
        if os.path.isabs(name) or ".." in Path(name).parts:
            continue  # a dotenv line pointing outside the repo is not ours to copy
        if not (repo_path / name).is_file():
            continue
        if git(repo_path, "ls-files", "--error-unmatch", "--", name,
               check=False).returncode == 0:
            continue  # tracked, so the new working copy already has it
        out.append(name)
    return out


def copy_env_files(repo_path, dest):
    """Carry the untracked env files into a fresh working copy. Returns the names copied.

    Never clobbers: a file already in dest is left alone, so a hand-edited per-task .env
    survives anything that reruns this.
    """
    copied = []
    for name in env_files_to_copy(repo_path):
        target = dest / name
        if target.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo_path / name, target)
        copied.append(name)
    return copied


CLAUDE_SETTINGS_REL = Path(".claude") / "settings.local.json"
CLAUDE_MEMORY_DIR = "~/.claude/memory/pleevi"


def ensure_claude_settings(path):
    """Point claude at the shared pleevi memory directory from `path`.

    Returns (ok, note-or-None), where a None note means it was already pointed there.

    Claude's memory lives in ~/.claude/projects/<sanitized-cwd>/memory by default, so a new
    task folder starts out knowing nothing and everything it learns dies with the task.
    `autoMemoryDirectory` overrides that, and is read from the *local* settings of the git
    root — or of the directory itself when it is not a checkout, which is exactly the case
    for a task folder (it holds checkouts but is not one) and for a jj workspace (jj cannot
    colocate one, so there is no .git in it either). Writing the file in both places is
    therefore what covers the claude tab and any claude started inside a workspace.

    Left untracked-but-ignored: every repo gitignores .claude/settings.local.json except
    vitulina, whose main checkout carries the same rule in .git/info/exclude — which the
    workspaces inherit, since that is the git repo backing them.

    Never overwrites: a value already set by hand wins, and so does a file we cannot parse.
    """
    target = path / CLAUDE_SETTINGS_REL
    settings = {}
    if target.is_file():
        try:
            settings = json.loads(target.read_text())
        except (OSError, json.JSONDecodeError) as e:
            return False, f"{CLAUDE_SETTINGS_REL} left alone ({e})"
        if not isinstance(settings, dict):
            return False, f"{CLAUDE_SETTINGS_REL} left alone (not a JSON object)"
        if "autoMemoryDirectory" in settings:
            return True, None
    settings["autoMemoryDirectory"] = CLAUDE_MEMORY_DIR
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(settings, indent=2) + "\n")
    except OSError as e:
        return False, f"could not write {CLAUDE_SETTINGS_REL}: {e}"
    return True, f"claude memory -> {CLAUDE_MEMORY_DIR}"


def apply_claude_settings(path, label, warnings):
    """ensure_claude_settings for one directory, reported through the usual channels."""
    ok, note = ensure_claude_settings(path)
    if note is None:
        return
    if ok:
        log(f"{label}: {note}")
    else:
        warnings.append(f"{label}: {note}")


def direnv_allow(dest):
    """Trust the worktree's .envrc. Returns None when skipped, "" on success, else why not."""
    if not (dest / ".envrc").is_file():
        return None
    result = user_shell("direnv allow", dest)
    if result.returncode != 0:
        return last_line(result.stderr or result.stdout, "direnv allow failed")
    return ""


def start_install(dest, prelude):
    """Kick off `pnpm install` without waiting, so repos install concurrently."""
    return subprocess.Popen(
        ["bash", "-lic", f"{prelude}pnpm install"], cwd=str(dest), text=True,
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )


def prepare(fresh, warnings, node_bin):
    """Make fresh working copies runnable: carry the env files over, trust .envrc, install."""
    for repo, dest in fresh:
        # First, because everything after this reads the environment it sets up.
        try:
            copied = copy_env_files(Path(repo["path"]), dest)
        except OSError as e:
            copied = []
            warnings.append(f"{repo['name']}: could not copy env files: {e}")
        if copied:
            log(f"{repo['name']}: copied " + ", ".join(copied))

        trusted = direnv_allow(dest)
        if trusted is None:
            log(f"{repo['name']}: no .envrc, nothing to allow")
        elif trusted:
            warnings.append(f"{repo['name']}: direnv allow failed: {trusted}")
        else:
            log(f"{repo['name']}: direnv allowed")

    prelude = path_prelude(node_bin)
    installs = [(repo, start_install(dest, prelude)) for repo, dest in fresh if repo["node"]]
    if not installs:
        return
    log("installing deps: " + ", ".join(repo["name"] for repo, _ in installs) + "...")
    for repo, proc in installs:
        try:
            output, _ = proc.communicate(timeout=900)
        except subprocess.TimeoutExpired:
            proc.kill()
            output, _ = proc.communicate()
            warnings.append(f"{repo['name']}: pnpm install timed out")
            continue
        if proc.returncode != 0:
            warnings.append(f"{repo['name']}: pnpm install failed: "
                            + last_line(output, "see the terminal"))
        else:
            log(f"{repo['name']}: deps installed")


def kitty_session(tabs, prelude=""):
    """A kitty session file: one tab per entry of `tabs` = [(title, cwd, command)].

    Every tab — the bare shell included — runs through the prelude, so whatever you start
    from any of them (vitulina, claude, a hand-typed pnpm) sees the same PATH.
    """
    lines = ["# generated by worktree-setup.py -- safe to delete"]
    for title, cwd, command in tabs:
        lines.append(f"new_tab {title}")
        lines.append(f"cd {cwd}")
        if command is None and not prelude:
            lines.append("launch")
        else:
            # Login+interactive so ~/.bash_profile and ~/.bashrc are both sourced
            # (bun and ~/.local/bin land on PATH there), then keep the tab alive as a
            # shell so a crashed server can be restarted in place.
            inner = (f"{prelude}exec bash -i" if command is None
                     else f"{prelude}{command}; exec bash -i")
            lines.append("launch bash -il -c " + shlex.quote(inner))
        # The tab whose window was focused last becomes active; keep that the shell.
        if title == "shell":
            lines.append("focus")
    return "\n".join(lines) + "\n"


def save_session(name, tabs, prelude=""):
    SESSION_DIR.mkdir(parents=True, exist_ok=True)
    session = session_path(name)
    session.write_text(kitty_session(tabs, prelude))
    return session


LAUNCH_PREFIX = "launch bash -il -c "
TAB_SCRIPT = Path(__file__).resolve().parent / "vitulina-tab.sh"


def server_command(task, repo, server):
    """The line that runs one server's tab. Single source of truth for both create and
    reopen, so a saved session never keeps running yesterday's rules.

    The actual `vitulina up` lives in vitulina-tab.sh — see the comment at the top of it
    for why a tab cannot just run the command and hand over to a shell.
    """
    prefix = "SESSION_SECRET=test " if repo["node"] else ""
    return (f"{prefix}{shlex.quote(str(TAB_SCRIPT))} "
            f"{shlex.quote(task)} {shlex.quote(server)}")


def rebuild_session(name, root, session):
    """Re-derive a saved session's tabs from its tab titles, or None if that is not possible.

    A task's server selection lives only in its session file, so reopening cannot rebuild it
    from scratch — but it can regenerate every *command* from the titles ("<repo> <server>"),
    which is what makes an old task pick up rules added since it was created (the
    SESSION_SECRET prefix, the PATH prelude) instead of reopening broken.
    """
    titles = session_tab_titles(session)
    if not titles:
        return None
    known = {r["name"]: r for r in discover_repos()}
    tabs = []
    for title in titles:
        if title == "shell":
            tabs.append(("shell", root, None))
        elif title == "claude":
            tabs.append(("claude", root, "claude"))
        else:
            repo_name, _, server = title.partition(" ")
            repo = known.get(repo_name)
            if not repo:
                return None  # unrecognisable tab: leave the file as it is
            if not server:
                tabs.append((repo_name, root / repo_name, None))
            else:
                tabs.append((title, root / repo_name, server_command(name, repo, server)))
    return tabs


def upgrade_session(session, prelude):
    """Last resort when rebuild_session cannot re-derive the tabs: patch the PATH prelude
    onto the existing launch lines so at least pnpm resolves."""
    if not prelude:
        return
    try:
        text = session.read_text()
        if prelude in text:
            return
        out = []
        for line in text.splitlines():
            if line.startswith(LAUNCH_PREFIX):
                inner = shlex.split(line[len(LAUNCH_PREFIX):])[0]
                out.append(LAUNCH_PREFIX + shlex.quote(prelude + inner))
            elif line.strip() == "launch":
                out.append(LAUNCH_PREFIX + shlex.quote(prelude + "exec bash -i"))
            else:
                out.append(line)
        session.write_text("\n".join(out) + "\n")
        log("added the node PATH prelude to this task's saved tabs")
    except (OSError, ValueError, IndexError):
        pass  # a session we cannot parse still launches, just without the prelude


def launch_kitty(name, root, session, open_kitty=True):
    """Open one kitty window on the task folder from its saved session file."""
    if not open_kitty:
        log(f"--no-open: session file is {session}")
        return
    kitty = shutil.which("kitty") or "/usr/bin/kitty"
    log(f"opening kitty with {len(session_tab_titles(session))} tabs...")
    subprocess.Popen(
        [kitty, "--title", f"pleevi:{name}", "--directory", str(root),
         "--session", str(session)],
        cwd=str(root), start_new_session=True,
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def open_task(name, open_kitty=True):
    """Reopen an existing task: same window, same tabs, same commands. Sets nothing up."""
    name = str(name).strip()
    if not NAME_RE.fullmatch(name):
        return {"ok": False, "error": "Invalid name: use letters, digits, . _ - only"}

    root = PLEEVI_ROOT / name
    if not root.is_dir():
        return {"ok": False, "error": f"No task folder at {root}"}

    warnings = []
    # Backfills the tasks made before this existed, and repairs one whose file was lost.
    apply_claude_settings(root, name, warnings)
    for path in sorted(root.iterdir()):
        if path.is_dir() and is_checkout(path):
            apply_claude_settings(path, path.name, warnings)

    session = session_path(name)
    if session.is_file():
        log(f"reopening {name} from its saved tabs...")
        prelude = path_prelude(node_bin_dir())
        tabs = rebuild_session(name, root, session)
        if tabs:
            session = save_session(name, tabs, prelude)
        else:
            upgrade_session(session, prelude)
    else:
        # Created outside this tool, or the cache was cleared: we cannot know which
        # servers were wanted, so give it the two tabs that are always right.
        warnings.append("No saved tabs for this task — opened a shell and claude only")
        session = save_session(name, [("shell", root, None), ("claude", root, "claude")],
                               path_prelude(node_bin_dir()))

    launch_kitty(name, root, session, open_kitty=open_kitty)
    return {
        "ok": True,
        "path": str(root),
        "env": name,
        "tabs": session_tab_titles(session),
        "warnings": warnings,
    }


def keep_existing_repos(task, root, selected, known, warnings):
    """Every repo already checked out in the task folder, then `selected`.

    Adding a repo to an existing task is `create` with the extra repo ticked — but a run's
    tabs are built from its selection alone, so a selection naming only the new repo would
    reopen the task with everything else missing from the window. Their server picks come
    from session_selection(), the only record of them.

    Kept first, and in the order the saved session lists them, so a task that grows a repo
    keeps its tabs where they were and the new one lands at the end.

    A repo whose main ~/pleevi checkout has since disappeared is reported and skipped: the
    working copy is still fine, but with nothing to look its servers or node-ness up in,
    there is no honest tab to write for it.
    """
    picked = {entry["name"] for entry in selected}
    saved = session_selection(task)
    kept, lost = [], []
    for path in sorted(root.iterdir()):
        if not path.is_dir() or not is_checkout(path) or path.name in picked:
            continue
        if path.name not in known:
            lost.append(path.name)
            continue
        kept.append({"name": path.name, "servers": saved.get(path.name, [])})
    if kept:
        log(f"{task} already exists: keeping " + ", ".join(e["name"] for e in kept))
    for name in lost:
        warnings.append(f"{name}: no longer a repo in ~/pleevi — left out of the tabs")

    # Whatever order the caller listed them in, the tabs come out in the order they are
    # already open in — a repo joining a task should appear at the end of the window, not
    # shuffle the tabs someone has been reaching for all week. A repo the session does not
    # know (the new one, or a folder put there by hand) keeps its relative place at the end,
    # since sort() is stable.
    position = {name: index for index, name in enumerate(saved)}
    merged = kept + selected
    merged.sort(key=lambda entry: position.get(entry["name"], len(position)))
    return merged


def create(spec, open_kitty=True):
    name = str(spec.get("name", "")).strip()
    if not NAME_RE.fullmatch(name):
        return {"ok": False, "error": "Invalid name: use letters, digits, . _ - only"}

    selected = [r for r in spec.get("repos") or [] if r.get("name")]
    if not selected:
        return {"ok": False, "error": "Select at least one repo"}

    known = {r["name"]: r for r in discover_repos()}
    unknown = [r["name"] for r in selected if r["name"] not in known]
    if unknown:
        return {"ok": False, "error": "Unknown repo(s): " + ", ".join(unknown)}

    root = PLEEVI_ROOT / name
    done, warnings = [], []

    # An existing folder means this is a task getting another repo rather than a new task.
    existed = root.is_dir()
    if existed:
        selected = keep_existing_repos(name, root, selected, known, warnings)
    root.mkdir(parents=True, exist_ok=True)

    # The claude tab opens here, on the task folder rather than on any one repo.
    apply_claude_settings(root, name, warnings)
    if not JJ:
        warnings.append("jj not found — falling back to git worktrees")

    for entry in selected:
        repo = known[entry["name"]]
        repo_path = Path(repo["path"])
        dest = root / repo["name"]

        if dest.exists():
            # Plain reopen: the working copy is already set up, so touch nothing and just
            # let it get its tabs back. Not a warning — a normal way to use the tool.
            log(f"{repo['name']}: already there, reopening")
            done.append((repo, dest, entry.get("servers") or [], False))
            continue

        # Every repo gets put on jj the first time it is picked; a repo that will not
        # colocate falls back to a git worktree rather than failing the whole task.
        on_jj = False
        if JJ:
            ok, note = ensure_jj_repo(repo_path)
            if not ok:
                warnings.append(f"{repo['name']}: {note}, using a git worktree")
            else:
                on_jj = True
                if note:
                    log(f"{repo['name']}: {note}")

        log(f"fetching {repo['name']}...")
        if on_jj:
            fetched = jj(repo_path, "git", "fetch", "--remote", "origin", check=False)
        else:
            fetched = git(repo_path, "fetch", "origin", repo["defaultBranch"], check=False)
        if fetched.returncode != 0:
            warnings.append(f"{repo['name']}: fetch failed, using the local "
                            f"{repo['defaultBranch']} ref from origin")

        if on_jj:
            log(f"adding jj workspace {repo['name']}...")
            ok, detail = add_workspace(repo_path, name,
                                       f"{repo['defaultBranch']}@origin", dest)
        else:
            log(f"adding worktree {repo['name']}...")
            ok, detail = add_worktree(repo_path, name,
                                      f"origin/{repo['defaultBranch']}", dest)
        if not ok:
            warnings.append(f"{repo['name']}: {detail}")
            continue
        log(f"{repo['name']}: {detail}")
        done.append((repo, dest, entry.get("servers") or [], True))

    if not done:
        return {"ok": False, "error": "No worktree could be created", "warnings": warnings,
                "path": str(root)}

    for repo, dest, _, _ in done:
        apply_claude_settings(dest, repo["name"], warnings)

    node_bin = node_bin_dir()
    if not node_bin:
        warnings.append("No nvm node dir found — pnpm may be missing inside the tabs")

    prepare([(repo, dest) for repo, dest, _, fresh in done if fresh], warnings, node_bin)

    tabs = [("shell", root, None), ("claude", root, "claude")]
    for repo, dest, servers, _ in done:
        if not servers:
            # Nothing to start — either the repo has no vitulina config (controller is
            # built with cargo, not served) or none of its servers were picked. A shell
            # sitting in the worktree is then the useful tab.
            tabs.append((repo["name"], dest, None))
            continue
        for server in servers:
            tabs.append((f"{repo['name']} {server}", dest,
                         server_command(name, repo, server)))

    session = save_session(name, tabs, path_prelude(node_bin))
    launch_kitty(name, root, session, open_kitty=open_kitty)

    return {
        "ok": True,
        "path": str(root),
        "branch": name,
        "env": name,
        # True when repos were added to a task that was already there, so the caller can
        # say "added" rather than "created".
        "existed": existed,
        "repos": [r["name"] for r, _, _, _ in done],
        "created": [r["name"] for r, _, _, fresh in done if fresh],
        "reopened": [r["name"] for r, _, _, fresh in done if not fresh],
        "tabs": [t[0] for t in tabs],
        "warnings": warnings,
    }


# ---------------------------------------------------------------- cli


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("repos")
    sub.add_parser("tasks")
    create_parser = sub.add_parser("create")
    create_parser.add_argument("spec", help="JSON spec, see module docstring")
    create_parser.add_argument("--no-open", action="store_true",
                               help="write the kitty session file but do not open kitty")
    open_parser = sub.add_parser("open")
    open_parser.add_argument("name", help="existing task folder name")
    open_parser.add_argument("--no-open", action="store_true",
                             help="resolve the session file but do not open kitty")
    args = parser.parse_args()

    if args.cmd == "repos":
        print(json.dumps({"root": str(PLEEVI_ROOT), "repos": discover_repos()}))
        return 0
    if args.cmd == "tasks":
        print(json.dumps({"root": str(PLEEVI_ROOT), "tasks": discover_tasks()}))
        return 0

    if args.cmd == "create":
        try:
            spec = json.loads(args.spec)
        except json.JSONDecodeError as e:
            print(json.dumps({"ok": False, "error": f"Bad spec: {e}"}))
            return 1

    # Always answer with JSON, including on an unexpected failure: the overlay reads the
    # result off stdout and would otherwise only see an exit code.
    try:
        if args.cmd == "create":
            result = create(spec, open_kitty=not args.no_open)
        else:
            result = open_task(args.name, open_kitty=not args.no_open)
    except Exception as e:  # noqa: BLE001 - reported to the UI, not swallowed
        result = {"ok": False, "error": f"{type(e).__name__}: {e}"}
    print(json.dumps(result))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
