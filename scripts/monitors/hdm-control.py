#!/usr/bin/env python3
"""
Control bridge between the pixel-shell "Displays" overlay and hyprdynamicmonitors (HDM).

HDM has no IPC: it auto-selects the highest-scoring profile whose required monitors are
all connected (ties -> last-defined profile), renders that profile's template to
general.destination, and Hyprland reloads. This script drives HDM without ever touching
the user's own profiles or the rendered monitors.conf. It only manages ONE profile of its
own, `__gui_quick`, which it appends/removes as a marker-delimited region at the END of
config.toml, plus that profile's template file. Being last-defined with one exact match
rule per connected monitor, the quick profile wins whenever it is present -> instant
extend / mirror / single. Removing it ("Auto") hands control straight back to the user's
profiles.

Subcommands:
  state                         -> JSON snapshot for the UI (read-only)
  quick <extend|mirror|single> [target]  -> write quick region + apply
  clear                         -> remove quick region + apply
  freeze <name>                 -> HDM freeze: save current live setup as a NEW profile
  validate                      -> HDM validate
  reapply                       -> SIGUSR1 the daemon (re-apply, no config reload)
  reload                        -> SIGHUP the daemon (reload config + re-apply)

Flags:
  --config PATH   override HDM config path (used for safe testing)
  --no-apply      write config only; never signal the daemon or render (safe testing)
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tomllib

QUICK = "__gui_quick"
BEGIN = "# >>> pixel-shell :: hyprdynamicmonitors quick profile (managed, do not edit) >>>"
END = "# <<< pixel-shell :: hyprdynamicmonitors quick profile <<<"
MODES = ("extend", "mirror", "single")

HDM = shutil.which("hyprdynamicmonitors") or "hyprdynamicmonitors"


def default_config():
    base = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return os.path.join(base, "hyprdynamicmonitors", "config.toml")


def tmpl_path(config_path):
    return os.path.join(os.path.dirname(os.path.abspath(config_path)),
                        "hyprconfigs", f"{QUICK}.go.tmpl")


def expand(p):
    return os.path.expanduser(os.path.expandvars(p or ""))


def tstr(s):
    # A valid TOML basic (double-quoted) string; JSON string syntax is a subset.
    return json.dumps(s)


# ---------- reading live state ----------

def hypr_monitors():
    try:
        out = subprocess.run(["hyprctl", "monitors", "all", "-j"],
                             capture_output=True, text=True, check=True).stdout
        return json.loads(out)
    except Exception:
        return []


def daemon_pids():
    """PIDs of the running HDM daemon (`... run`, excluding our own --run-once probes)."""
    pids = []
    try:
        res = subprocess.run(["pgrep", "-af", "hyprdynamicmonitors"],
                             capture_output=True, text=True)
        for line in res.stdout.splitlines():
            parts = line.split(None, 1)
            if len(parts) != 2:
                continue
            pid, cmd = parts
            if " run" in f" {cmd}" and "--run-once" not in cmd and "--dry-run" not in cmd:
                pids.append(int(pid))
    except Exception:
        pass
    return pids


def active_profile(config_path):
    """Ask HDM (read-only, --dry-run) which profile it would select right now."""
    try:
        res = subprocess.run(
            [HDM, "--config", config_path, "--enable-json-logs-format",
             "run", "--run-once", "--dry-run"],
            capture_output=True, text=True, timeout=15)
    except Exception:
        return None
    found = None
    for line in (res.stdout + "\n" + res.stderr).splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        msg = str(obj.get("msg", ""))
        if "Using profile" in msg and obj.get("profile_name"):
            found = obj["profile_name"]  # keep last (final decision)
    return found


def load_config(config_path):
    try:
        with open(config_path, "rb") as f:
            return tomllib.load(f)
    except Exception:
        return {}


def profile_required(pdata):
    req = (((pdata.get("conditions") or {}).get("required_monitors")) or [])
    out = []
    for r in req:
        out.append({
            "description": r.get("description"),
            "name": r.get("name"),
            "tag": r.get("monitor_tag"),
        })
    return out


def cmd_state(args):
    cfg = load_config(args.config)
    profiles = cfg.get("profiles", {}) or {}
    dest = expand((cfg.get("general") or {}).get("destination", ""))

    out_profiles = []
    quick = {"active": False, "mode": None, "single_target": None}
    for name, pdata in profiles.items():
        stv = pdata.get("static_template_values") or {}
        if name == QUICK:
            quick = {"active": True, "mode": stv.get("mode"),
                     "single_target": stv.get("single_target")}
            continue  # managed profile is reported via `quick`, not the user list
        out_profiles.append({
            "name": name,
            "required": profile_required(pdata),
            "config_type": pdata.get("config_file_type"),
            "has_modes": "mode" in stv,
            "static_values": stv,
        })

    fallback = cfg.get("fallback_profile")
    state = {
        "daemon_running": bool(daemon_pids()),
        "active_profile": active_profile(args.config),
        "destination": dest,
        "destination_exists": bool(dest) and os.path.exists(dest),
        "quick": quick,
        "profiles": out_profiles,
        "has_fallback": bool(fallback),
        "monitors": [
            {
                "name": m.get("name"),
                "description": m.get("description"),
                "width": m.get("width"), "height": m.get("height"),
                "refreshRate": m.get("refreshRate"),
                "x": m.get("x"), "y": m.get("y"),
                "scale": m.get("scale"), "transform": m.get("transform"),
                "disabled": m.get("disabled"),
                "mirrorOf": m.get("mirrorOf"),
            }
            for m in hypr_monitors()
        ],
    }
    print(json.dumps(state))
    return 0


# ---------- writing the managed region ----------

TEMPLATE = """# Managed by the pixel-shell Displays overlay. Safe to delete.
# Ranges over every connected monitor, so it adapts to whatever is plugged in.
{{ if eq .mode "extend" }}{{ range .Monitors }}
monitor={{ .Name }},preferred,auto,1{{ end }}{{ end }}
{{ if eq .mode "mirror" }}{{ $p := (index .Monitors 0).Name }}{{ range $i, $m := .Monitors }}
monitor={{ $m.Name }},preferred,auto,1{{ if ne $i 0 }},mirror,{{ $p }}{{ end }}{{ end }}{{ end }}
{{ if eq .mode "single" }}{{ range .Monitors }}
monitor={{ .Name }},{{ if eq .Name $.single_target }}preferred,0x0,1{{ else }}disable{{ end }}{{ end }}{{ end }}
"""


def ensure_template(config_path):
    path = tmpl_path(config_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(TEMPLATE)
    return path


def build_region(config_path, monitors, mode, single_target):
    tp = tmpl_path(config_path)
    L = [BEGIN,
         f"[profiles.{QUICK}]",
         f"config_file = {tstr(tp)}",
         'config_file_type = "template"',
         "",
         f"[profiles.{QUICK}.static_template_values]",
         f"mode = {tstr(mode)}",
         f"single_target = {tstr(single_target)}",
         "",
         f"[profiles.{QUICK}.conditions]"]
    for i, m in enumerate(monitors):
        desc = (m.get("description") or "").strip()
        name = m.get("name") or ""
        L.append(f"[[profiles.{QUICK}.conditions.required_monitors]]")
        if desc and desc.lower() != "unknown":
            L.append(f"description = {tstr(desc)}")
        else:
            L.append(f"name = {tstr(name)}")
        L.append(f'monitor_tag = "m{i}"')
        L.append("")
    L.append(END)
    return "\n".join(L) + "\n"


def strip_region(text):
    if BEGIN not in text:
        return text
    head, _, rest = text.partition(BEGIN)
    _, _, tail = rest.partition(END)
    return head.rstrip("\n") + ("\n" if head.strip() else "") + tail.lstrip("\n")


def write_region(config_path, region):
    with open(config_path, "r") as f:
        text = f.read()
    text = strip_region(text)
    if not text.endswith("\n"):
        text += "\n"
    text = text.rstrip("\n") + "\n\n" + region
    tmp = config_path + ".pixeltmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, config_path)


def remove_region(config_path):
    with open(config_path, "r") as f:
        text = f.read()
    if BEGIN not in text:
        return False
    tmp = config_path + ".pixeltmp"
    with open(tmp, "w") as f:
        f.write(strip_region(text).rstrip("\n") + "\n")
    os.replace(tmp, config_path)
    return True


def apply(config_path, no_apply):
    """Make HDM re-render: SIGHUP the daemon if running, else a one-shot render."""
    if no_apply:
        return "skipped (--no-apply)"
    pids = daemon_pids()
    if pids:
        for pid in pids:
            try:
                os.kill(pid, 1)  # SIGHUP
            except ProcessLookupError:
                pass
        return f"sighup {pids}"
    try:
        subprocess.run([HDM, "--config", config_path, "run", "--run-once"],
                       capture_output=True, text=True, timeout=20)
        return "run-once"
    except Exception as e:
        return f"run-once failed: {e}"


def cmd_quick(args):
    if args.mode not in MODES:
        return fail(f"mode must be one of {MODES}")
    mons = hypr_monitors()
    if not mons:
        return fail("no monitors reported by hyprctl")
    target = args.target or mons[0].get("name")
    ensure_template(args.config)
    region = build_region(args.config, mons, args.mode, target)
    write_region(args.config, region)
    how = apply(args.config, args.no_apply)
    return ok(f"quick {args.mode} ({len(mons)} monitor(s))", applied=how,
              mode=args.mode, single_target=target)


def cmd_clear(args):
    removed = remove_region(args.config)
    how = apply(args.config, args.no_apply)
    return ok("cleared quick profile" if removed else "no quick profile present",
              applied=how)


def cmd_freeze(args):
    name = args.name
    if not name or not all(c.isalnum() or c in "-_" for c in name):
        return fail("invalid profile name (use letters/digits/-/_)")
    if name == QUICK:
        return fail("reserved name")
    cfg = load_config(args.config)
    if name in (cfg.get("profiles", {}) or {}):
        return fail(f"profile '{name}' already exists")
    res = subprocess.run([HDM, "--config", args.config, "freeze", "--profile-name", name],
                         capture_output=True, text=True)
    if res.returncode != 0:
        return fail((res.stderr or res.stdout).strip() or "freeze failed")
    return ok(f"froze current setup as '{name}'")


def cmd_validate(args):
    res = subprocess.run([HDM, "--config", args.config, "validate"],
                         capture_output=True, text=True)
    return ok("config valid") if res.returncode == 0 \
        else fail((res.stderr or res.stdout).strip() or "invalid config")


def cmd_signal(args):
    pids = daemon_pids()
    if not pids:
        return fail("daemon not running")
    sig = 10 if args.cmd == "reapply" else 1  # SIGUSR1 / SIGHUP
    for pid in pids:
        try:
            os.kill(pid, sig)
        except ProcessLookupError:
            pass
    return ok(f"{args.cmd} sent to {pids}")


def ok(msg, **extra):
    print(json.dumps({"ok": True, "msg": msg, **extra}))
    return 0


def fail(msg, **extra):
    print(json.dumps({"ok": False, "error": msg, **extra}))
    return 1


def main():
    p = argparse.ArgumentParser(description="pixel-shell <-> hyprdynamicmonitors bridge")
    p.add_argument("--config", default=None)
    p.add_argument("--no-apply", action="store_true")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("state")
    q = sub.add_parser("quick")
    q.add_argument("mode")
    q.add_argument("target", nargs="?", default=None)
    sub.add_parser("clear")
    fr = sub.add_parser("freeze")
    fr.add_argument("name")
    sub.add_parser("validate")
    sub.add_parser("reapply")
    sub.add_parser("reload")
    args = p.parse_args()
    args.config = args.config or default_config()

    dispatch = {
        "state": cmd_state, "quick": cmd_quick, "clear": cmd_clear,
        "freeze": cmd_freeze, "validate": cmd_validate,
        "reapply": cmd_signal, "reload": cmd_signal,
    }
    return dispatch[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
