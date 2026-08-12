#!/usr/bin/env bash
#
# One kitty tab for one `vitulina up` server. Generated into the kitty session files by
# worktree-setup.py; run from the repo's worktree directory.
#
# Two things this does that a bare `vitulina up ...; exec bash -i` in the session file
# could not:
#
# 1. It does not vanish. `vitulina up` is idempotent: when the server is already running
#    for this env -- which it is whenever a task is reopened while its first window still
#    has the servers up -- it prints "<server> already running (pid N), skipping" and
#    exits 0 inside a second. The tab then fell straight through to `exec bash -i`, which
#    re-sources ~/.bashrc, which ends in `clear`, which wiped that message off the screen.
#    What was left looked exactly like a tab that had never been given a command: an empty
#    prompt with only direnv's "loading .envrc" line under it (printed by the hook at the
#    new shell's first prompt). So: say how the command ended, and hold the tab until that
#    has been read.
# 2. It loads .envrc. A tab's `bash -il -c` never reaches a prompt, so direnv's
#    PROMPT_COMMAND hook never fires and the server would otherwise start without the
#    repo's `dotenv` vars and PATH_add entries. `direnv export` applies them with no
#    prompt involved.

set -u

env_name=${1:?usage: vitulina-tab.sh <env> <server>}
server=${2:?usage: vitulina-tab.sh <env> <server>}

if [[ -f .envrc ]] && command -v direnv >/dev/null 2>&1; then
    # Failure here is not fatal: an un-allowed .envrc should still leave you with a tab.
    eval "$(direnv export bash 2>/dev/null)" || true
fi

run() {
    vitulina up --env "$env_name" "$server"
    status=$?
}

run
while true; do
    printf '\n== vitulina up %s (env %s) exited %s ==\n' "$server" "$env_name" "$status"
    printf '   [l] follow logs   [r] run again   [enter] drop to a shell\n> '
    read -r reply || reply=''
    case $reply in
        l | L) vitulina logs -f --env "$env_name" "$server" ;;
        r | R) run ;;
        *) break ;;
    esac
done
