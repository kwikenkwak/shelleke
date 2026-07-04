#!/usr/bin/env python3
"""
Control bridge between the pixel-shell "Displays" overlay and hyprdynamicmonitors (HDM).

HDM has no IPC: it auto-selects the highest-scoring profile whose required monitors are
all connected (ties -> last-defined profile wins), renders that profile's template to
general.destination, and Hyprland reloads.

This script both drives the fast quick-layout feature AND provides full management of the
user's real profiles + a few global settings. Since no TOML *writer* library is available
(only read-only tomllib), all mutations are performed as **surgical text edits on the
relevant `[profiles.NAME]` / `[section]` block only** — the rest of config.toml (comments,
ordering, formatting) is preserved. This mirrors how HDM's own freeze/TUI edit the file.

Subcommands
  state                       JSON snapshot for the UI (read-only)
  quick <extend|mirror|single> [target]   write managed quick profile + apply
  clear                       remove managed quick profile + apply
  save-profile <json>         create or edit a user profile (metadata block)
  apply-current <name>        write current live monitor layout into a profile's template
  set-enabled <name> <0|1>    disable (comment out) / enable a profile
  remove <name> [--delete-template]   delete a profile block (UI confirms first)
  move <name> <up|down>       reorder a profile (priority; last wins ties)
  set-scoring <json>          set [scoring] weights
  set-notifications <json>    set [notifications]
  freeze <name>               HDM freeze (kept for parity)
  validate | reapply | reload

Flags: --config PATH (test override), --no-apply (write only; safe testing)
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tomllib

QUICK = "__gui_quick"
BEGIN = "# >>> pixel-shell :: hyprdynamicmonitors quick profile (managed, do not edit) >>>"
END = "# <<< pixel-shell :: hyprdynamicmonitors quick profile <<<"
OFF = "#HDMGUI-OFF# "  # prefix marking a disabled (commented) profile
TUI_START = "# <<<<< TUI AUTO START"
TUI_END = "# <<<<< TUI AUTO END"
MODES = ("extend", "mirror", "single")

HDM = shutil.which("hyprdynamicmonitors") or "hyprdynamicmonitors"
HEADER_RE = re.compile(r'^(' + re.escape(OFF) + r')?\s*(\[\[?)\s*([^\]]+?)\s*(\]\]?)\s*$')


# ---------- paths / io ----------

def default_config():
    base = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return os.path.join(base, "hyprdynamicmonitors", "config.toml")


def config_dir(cfg):
    return os.path.dirname(os.path.abspath(cfg))


def hyprconfigs_dir(cfg):
    return os.path.join(config_dir(cfg), "hyprconfigs")


def quick_tmpl_path(cfg):
    return os.path.join(hyprconfigs_dir(cfg), f"{QUICK}.go.tmpl")


def expand(p):
    return os.path.expanduser(os.path.expandvars(p or ""))


def tstr(s):
    return json.dumps(s)  # valid TOML basic string


def read_text(path):
    with open(path, "r") as f:
        return f.read()


def write_text(path, text):
    tmp = path + ".pixeltmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


# ---------- live state ----------

def hypr_monitors():
    try:
        out = subprocess.run(["hyprctl", "monitors", "all", "-j"],
                             capture_output=True, text=True, check=True).stdout
        return json.loads(out)
    except Exception:
        return []


def daemon_pids():
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


def active_profile(cfg):
    try:
        res = subprocess.run(
            [HDM, "--config", cfg, "--enable-json-logs-format",
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
        if "Using profile" in str(obj.get("msg", "")) and obj.get("profile_name"):
            found = obj["profile_name"]
    return found


# ---------- TOML block engine (surgical, comment-preserving) ----------

def profile_of(path):
    """Return the profile name a section path belongs to, or None for non-profile."""
    parts = path.split(".")
    if parts[0] == "profiles" and len(parts) >= 2:
        return parts[1]
    return None


def list_profile_spans(lines):
    """Ordered list of {name, start, end, disabled} line spans, one per profile."""
    headers = []  # (idx, path, disabled)
    for i, ln in enumerate(lines):
        m = HEADER_RE.match(ln)
        if m:
            headers.append((i, m.group(3).strip(), m.group(1) is not None))
    spans = []
    cur = None
    for k, (idx, path, disabled) in enumerate(headers):
        name = profile_of(path)
        if name is not None:
            if cur is None or cur["name"] != name:
                if cur is not None:
                    cur["end"] = idx
                    spans.append(cur)
                cur = {"name": name, "start": idx, "end": None, "disabled": disabled}
        else:
            if cur is not None:
                cur["end"] = idx
                spans.append(cur)
                cur = None
    if cur is not None:
        cur["end"] = len(lines)
        spans.append(cur)
    # trim trailing blank lines out of each span (keep them as separators)
    for sp in spans:
        e = sp["end"]
        while e - 1 > sp["start"] and lines[e - 1].strip() == "":
            e -= 1
        sp["end"] = e
    return spans


def find_span(lines, name):
    for sp in list_profile_spans(lines):
        if sp["name"] == name:
            return sp
    return None


def parse_block(lines, sp):
    """tomllib-parse a single profile span (stripping the OFF marker), return its dict."""
    raw = []
    for ln in lines[sp["start"]:sp["end"]]:
        raw.append(ln[len(OFF):] if ln.startswith(OFF) else ln)
    try:
        data = tomllib.loads("".join(raw))
        return (((data.get("profiles") or {}).get(sp["name"])) or {})
    except Exception:
        return {}


def find_section_span(lines, path):
    """(start, end) for a top-level table like [scoring]; None if absent."""
    start = None
    for i, ln in enumerate(lines):
        m = HEADER_RE.match(ln)
        if not m:
            continue
        if start is None:
            if m.group(3).strip() == path:
                start = i
            continue
        # first header after start closes the section
        return (start, i)
    if start is not None:
        e = len(lines)
        while e - 1 > start and lines[e - 1].strip() == "":
            e -= 1
        return (start, e)
    return None


# ---------- rendering ----------

def render_profile_block(spec, config_file):
    name = spec["name"]
    L = [f"[profiles.{name}]",
         f"config_file = {tstr(config_file)}",
         f'config_file_type = {tstr(spec.get("config_file_type") or "template")}']
    power = spec.get("power") or ""
    lid = spec.get("lid") or ""
    L.append(f"[profiles.{name}.conditions]")
    if power in ("AC", "BAT"):
        L.append(f"power_state = {tstr(power)}")
    if lid in ("Opened", "Closed"):
        L.append(f"lid_state = {tstr(lid)}")
    L.append("")
    for r in spec.get("required", []):
        by = "description" if r.get("by") == "description" else "name"
        val = r.get("value", "")
        L.append(f"[[profiles.{name}.conditions.required_monitors]]")
        L.append(f"{by} = {tstr(val)}")
        if r.get("regex"):
            L.append(f"match_{by}_using_regex = true")
        if r.get("tag"):
            L.append(f"monitor_tag = {tstr(r['tag'])}")
        L.append("")
    static = spec.get("static") or {}
    if static:
        L.append(f"[profiles.{name}.static_template_values]")
        for k, v in static.items():
            L.append(f"{k} = {tstr(str(v))}")
        L.append("")
    return "\n".join(L).rstrip("\n") + "\n"


def monitor_line(m):
    name = m.get("name") or ""
    desc = (m.get("description") or "").strip()
    ident = f"desc:{desc}" if desc and desc.lower() != "unknown" else name
    if m.get("disabled"):
        return f"monitor={ident},disable"
    w, h = m.get("width", 0), m.get("height", 0)
    rr = m.get("refreshRate", 0) or 0
    x, y = m.get("x", 0), m.get("y", 0)
    scale = m.get("scale", 1) or 1
    tr = m.get("transform", 0) or 0
    vrr = 1 if m.get("vrr") else 0
    mirror = m.get("mirrorOf")
    line = f"monitor={ident},{w}x{h}@{rr:.5f},{x}x{y},{scale:.8f},transform,{tr},vrr,{vrr}"
    if mirror and mirror != "none":
        line += f",mirror,{mirror}"
    return line


def current_monitor_lines():
    return [monitor_line(m) for m in hypr_monitors()]


def write_tui_template(path, monitor_lines):
    """Replace content between the TUI markers (create the file/markers if absent)."""
    header = ("# Managed via the pixel-shell Displays overlay (apply current layout).\n"
              "# Edit freely outside the markers.\n")
    body = TUI_START + "\n" + "\n".join(monitor_lines) + "\n" + TUI_END + "\n"
    if os.path.exists(path):
        text = read_text(path)
        if TUI_START in text and TUI_END in text:
            pre, _, rest = text.partition(TUI_START)
            _, _, post = rest.partition(TUI_END)
            text = pre + body.rstrip("\n") + post
        else:
            text = text.rstrip("\n") + "\n\n" + body
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        text = header + body
    write_text(path, text)


# ---------- state ----------

def cmd_state(args):
    cfg = args.config
    text = read_text(cfg) if os.path.exists(cfg) else ""
    lines = text.splitlines(keepends=True)
    # globals via tomllib on the active file (commented profiles are ignored)
    try:
        top = tomllib.loads(text)
    except Exception:
        top = {}
    general = top.get("general") or {}
    scoring = top.get("scoring") or {}
    notifications = top.get("notifications") or {}

    profiles = []
    quick = {"active": False, "mode": None, "single_target": None}
    for order, sp in enumerate(list_profile_spans(lines)):
        d = parse_block(lines, sp)
        stv = d.get("static_template_values") or {}
        if sp["name"] == QUICK:
            quick = {"active": not sp["disabled"], "mode": stv.get("mode"),
                     "single_target": stv.get("single_target")}
            continue
        conds = d.get("conditions") or {}
        req = []
        for r in (conds.get("required_monitors") or []):
            by = "description" if "description" in r else "name"
            req.append({"by": by, "value": r.get(by, ""),
                        "regex": bool(r.get(f"match_{by}_using_regex", False)),
                        "tag": r.get("monitor_tag", "")})
        profiles.append({
            "name": sp["name"], "enabled": not sp["disabled"], "order": order,
            "config_file": d.get("config_file"), "config_file_type": d.get("config_file_type"),
            "power": conds.get("power_state", ""), "lid": conds.get("lid_state", ""),
            "required": req, "static": stv, "has_modes": "mode" in stv,
        })

    dest = expand(general.get("destination", ""))
    print(json.dumps({
        "daemon_running": bool(daemon_pids()),
        "active_profile": active_profile(cfg),
        "destination": dest,
        "destination_exists": bool(dest) and os.path.exists(dest),
        "quick": quick,
        "profiles": profiles,
        "has_fallback": bool(top.get("fallback_profile")),
        "scoring": {
            "name_match": scoring.get("name_match", 10),
            "description_match": scoring.get("description_match", 5),
            "power_state_match": scoring.get("power_state_match", 3),
            "lid_state_match": scoring.get("lid_state_match", 2),
        },
        "notifications": {
            "disabled": bool(notifications.get("disabled", False)),
            "timeout_ms": notifications.get("timeout_ms", 10000),
        },
        "general": {
            "debounce_time_ms": general.get("debounce_time_ms"),
            "pre_apply_exec": general.get("pre_apply_exec", ""),
            "post_apply_exec": general.get("post_apply_exec", ""),
        },
        "monitors": [
            {"name": m.get("name"), "description": m.get("description"),
             "width": m.get("width"), "height": m.get("height"),
             "refreshRate": m.get("refreshRate"), "x": m.get("x"), "y": m.get("y"),
             "scale": m.get("scale"), "transform": m.get("transform"),
             "disabled": m.get("disabled"), "mirrorOf": m.get("mirrorOf"),
             "vrr": m.get("vrr")}
            for m in hypr_monitors()
        ],
    }))
    return 0


# ---------- quick profile (unchanged behaviour) ----------

QUICK_TEMPLATE = """# Managed by the pixel-shell Displays overlay. Safe to delete.
# Ranges over every connected monitor, so it adapts to whatever is plugged in.
{{ if eq .mode "extend" }}{{ range .Monitors }}
monitor={{ .Name }},preferred,auto,1{{ end }}{{ end }}
{{ if eq .mode "mirror" }}{{ $p := (index .Monitors 0).Name }}{{ range $i, $m := .Monitors }}
monitor={{ $m.Name }},preferred,auto,1{{ if ne $i 0 }},mirror,{{ $p }}{{ end }}{{ end }}{{ end }}
{{ if eq .mode "single" }}{{ range .Monitors }}
monitor={{ .Name }},{{ if eq .Name $.single_target }}preferred,0x0,1{{ else }}disable{{ end }}{{ end }}{{ end }}
"""


def ensure_quick_template(cfg):
    path = quick_tmpl_path(cfg)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    write_text(path, QUICK_TEMPLATE)
    return path


def build_quick_region(cfg, monitors, mode, target):
    tp = quick_tmpl_path(cfg)
    L = [BEGIN, f"[profiles.{QUICK}]", f"config_file = {tstr(tp)}",
         'config_file_type = "template"', "",
         f"[profiles.{QUICK}.static_template_values]",
         f"mode = {tstr(mode)}", f"single_target = {tstr(target)}", "",
         f"[profiles.{QUICK}.conditions]"]
    for i, m in enumerate(monitors):
        desc = (m.get("description") or "").strip()
        L.append(f"[[profiles.{QUICK}.conditions.required_monitors]]")
        if desc and desc.lower() != "unknown":
            L.append(f"description = {tstr(desc)}")
        else:
            L.append(f"name = {tstr(m.get('name') or '')}")
        L.append(f'monitor_tag = "m{i}"')
        L.append("")
    L.append(END)
    return "\n".join(L) + "\n"


def strip_quick_region(text):
    if BEGIN not in text:
        return text
    head, _, rest = text.partition(BEGIN)
    _, _, tail = rest.partition(END)
    return head.rstrip("\n") + ("\n" if head.strip() else "") + tail.lstrip("\n")


def cmd_quick(args):
    if args.mode not in MODES:
        return fail(f"mode must be one of {MODES}")
    mons = hypr_monitors()
    if not mons:
        return fail("no monitors reported by hyprctl")
    target = args.target or mons[0].get("name")
    ensure_quick_template(cfg=args.config)
    region = build_quick_region(args.config, mons, args.mode, target)
    text = strip_quick_region(read_text(args.config))
    text = text.rstrip("\n") + "\n\n" + region
    write_text(args.config, text)
    return ok(f"quick {args.mode} ({len(mons)} monitor(s))",
              applied=apply(args.config, args.no_apply), mode=args.mode, single_target=target)


def cmd_clear(args):
    if not os.path.exists(args.config):
        return fail("config not found")
    text = read_text(args.config)
    had = BEGIN in text
    write_text(args.config, strip_quick_region(text).rstrip("\n") + "\n")
    return ok("back to auto" if had else "no quick profile present",
              applied=apply(args.config, args.no_apply))


# ---------- profile management ----------

def guard_name(name):
    if not name or not all(c.isalnum() or c in "-_" for c in name):
        return "invalid profile name (letters, digits, - and _ only)"
    if name == QUICK:
        return "that name is reserved by the quick-layout feature"
    return None


def cmd_save_profile(args):
    try:
        spec = json.loads(args.spec)
    except Exception as e:
        return fail(f"bad spec json: {e}")
    name = spec.get("name", "")
    err = guard_name(name)
    if err:
        return fail(err)
    req = spec.get("required") or []
    if not req or not any((r.get("value") or "").strip() for r in req):
        return fail("a profile needs at least one required monitor")

    text = read_text(args.config) if os.path.exists(args.config) else ""
    lines = text.splitlines(keepends=True)
    existing = find_span(lines, name)

    if spec.get("new"):
        if existing:
            return fail(f"profile '{name}' already exists")
        config_file = os.path.join(hyprconfigs_dir(args.config), f"{name}.go.tmpl")
        if spec.get("from_current"):
            write_tui_template(config_file, current_monitor_lines())
        else:
            write_tui_template(config_file, [])
        block = render_profile_block(spec, config_file)
        new_text = text.rstrip("\n") + "\n\n" + block if text.strip() else block
        write_text(args.config, new_text)
    else:
        if not existing:
            return fail(f"profile '{name}' not found")
        prev = parse_block(lines, existing)
        config_file = prev.get("config_file") or os.path.join(
            hyprconfigs_dir(args.config), f"{name}.go.tmpl")
        block = render_profile_block(spec, config_file)
        if existing["disabled"]:  # keep it disabled after editing
            block = "".join(OFF + ln if ln.strip() else ln
                            for ln in block.splitlines(keepends=True))
        new_lines = lines[:existing["start"]] + [block] + lines[existing["end"]:]
        write_text(args.config, "".join(new_lines))
    return ok(f"saved profile '{name}'", applied=apply(args.config, args.no_apply))


def cmd_apply_current(args):
    text = read_text(args.config)
    lines = text.splitlines(keepends=True)
    sp = find_span(lines, args.name)
    if not sp:
        return fail(f"profile '{args.name}' not found")
    d = parse_block(lines, sp)
    cf = expand(d.get("config_file") or "")
    if not cf:
        return fail("profile has no config_file")
    write_tui_template(cf, current_monitor_lines())
    return ok(f"applied current layout to '{args.name}'",
              applied=apply(args.config, args.no_apply))


def cmd_set_enabled(args):
    err = guard_name(args.name)
    if err:
        return fail(err)
    text = read_text(args.config)
    lines = text.splitlines(keepends=True)
    sp = find_span(lines, args.name)
    if not sp:
        return fail(f"profile '{args.name}' not found")
    want_enabled = args.value in ("1", "true", "on")
    block = lines[sp["start"]:sp["end"]]
    if want_enabled:
        block = [ln[len(OFF):] if ln.startswith(OFF) else ln for ln in block]
    else:
        block = [ln if (ln.startswith(OFF) or ln.strip() == "") else OFF + ln for ln in block]
    new_lines = lines[:sp["start"]] + block + lines[sp["end"]:]
    write_text(args.config, "".join(new_lines))
    return ok(f"{'enabled' if want_enabled else 'disabled'} '{args.name}'",
              applied=apply(args.config, args.no_apply))


def cmd_remove(args):
    err = guard_name(args.name)
    if err:
        return fail(err)
    text = read_text(args.config)
    lines = text.splitlines(keepends=True)
    sp = find_span(lines, args.name)
    if not sp:
        return fail(f"profile '{args.name}' not found")
    d = parse_block(lines, sp)
    # drop the span plus any immediately-trailing blank separator lines
    end = sp["end"]
    while end < len(lines) and lines[end].strip() == "":
        end += 1
    new_lines = lines[:sp["start"]] + lines[end:]
    write_text(args.config, "".join(new_lines).rstrip("\n") + "\n")
    if args.delete_template:
        cf = expand(d.get("config_file") or "")
        # only delete inside the hyprconfigs dir, never outside
        if cf and os.path.isfile(cf) and os.path.dirname(cf) == hyprconfigs_dir(args.config):
            try:
                os.remove(cf)
            except OSError:
                pass
    return ok(f"removed profile '{args.name}'", applied=apply(args.config, args.no_apply))


def cmd_move(args):
    text = read_text(args.config)
    lines = text.splitlines(keepends=True)
    spans = [s for s in list_profile_spans(lines) if s["name"] != QUICK]
    idx = next((i for i, s in enumerate(spans) if s["name"] == args.name), None)
    if idx is None:
        return fail(f"profile '{args.name}' not found")
    j = idx - 1 if args.direction == "up" else idx + 1
    if j < 0 or j >= len(spans):
        return ok(f"'{args.name}' already at the {'top' if args.direction == 'up' else 'bottom'}",
                  applied="skipped")
    a, b = (spans[idx], spans[j]) if idx < j else (spans[j], spans[idx])
    between = lines[a["end"]:b["start"]]
    swapped = lines[b["start"]:b["end"]] + between + lines[a["start"]:a["end"]]
    new_lines = lines[:a["start"]] + swapped + lines[b["end"]:]
    write_text(args.config, "".join(new_lines))
    return ok(f"moved '{args.name}' {args.direction}", applied=apply(args.config, args.no_apply))


def replace_or_append_table(text, path, kv):
    lines = text.splitlines(keepends=True)
    block = f"[{path}]\n" + "".join(f"{k} = {v}\n" for k, v in kv.items())
    span = find_section_span(lines, path)
    if span:
        new_lines = lines[:span[0]] + [block] + lines[span[1]:]
        return "".join(new_lines)
    return text.rstrip("\n") + "\n\n" + block


def cmd_set_scoring(args):
    try:
        s = json.loads(args.spec)
    except Exception as e:
        return fail(f"bad json: {e}")
    kv = {k: int(s[k]) for k in
          ("name_match", "description_match", "power_state_match", "lid_state_match") if k in s}
    write_text(args.config, replace_or_append_table(read_text(args.config), "scoring", kv))
    return ok("updated scoring", applied=apply(args.config, args.no_apply))


def cmd_set_notifications(args):
    try:
        s = json.loads(args.spec)
    except Exception as e:
        return fail(f"bad json: {e}")
    kv = {}
    if "disabled" in s:
        kv["disabled"] = "true" if s["disabled"] else "false"
    if "timeout_ms" in s:
        kv["timeout_ms"] = int(s["timeout_ms"])
    write_text(args.config, replace_or_append_table(read_text(args.config), "notifications", kv))
    return ok("updated notifications", applied=apply(args.config, args.no_apply))


# ---------- HDM passthrough ----------

def cmd_freeze(args):
    err = guard_name(args.name)
    if err:
        return fail(err)
    cfg = load_top(args.config)
    if args.name in (cfg.get("profiles", {}) or {}):
        return fail(f"profile '{args.name}' already exists")
    res = subprocess.run([HDM, "--config", args.config, "freeze", "--profile-name", args.name],
                         capture_output=True, text=True)
    return ok(f"froze current setup as '{args.name}'") if res.returncode == 0 \
        else fail((res.stderr or res.stdout).strip() or "freeze failed")


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
    return ok(f"{args.cmd} sent")


# ---------- apply / output ----------

def apply(cfg, no_apply):
    if no_apply:
        return "skipped (--no-apply)"
    pids = daemon_pids()
    if pids:
        for pid in pids:
            try:
                os.kill(pid, 1)  # SIGHUP
            except ProcessLookupError:
                pass
        return "sighup"
    try:
        subprocess.run([HDM, "--config", cfg, "run", "--run-once"],
                       capture_output=True, text=True, timeout=20)
        return "run-once"
    except Exception as e:
        return f"run-once failed: {e}"


def load_top(cfg):
    try:
        with open(cfg, "rb") as f:
            return tomllib.load(f)
    except Exception:
        return {}


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
    q = sub.add_parser("quick"); q.add_argument("mode"); q.add_argument("target", nargs="?")
    sub.add_parser("clear")
    sp = sub.add_parser("save-profile"); sp.add_argument("spec")
    ac = sub.add_parser("apply-current"); ac.add_argument("name")
    se = sub.add_parser("set-enabled"); se.add_argument("name"); se.add_argument("value")
    rm = sub.add_parser("remove"); rm.add_argument("name"); rm.add_argument("--delete-template", action="store_true")
    mv = sub.add_parser("move"); mv.add_argument("name"); mv.add_argument("direction", choices=["up", "down"])
    ss = sub.add_parser("set-scoring"); ss.add_argument("spec")
    sn = sub.add_parser("set-notifications"); sn.add_argument("spec")
    fr = sub.add_parser("freeze"); fr.add_argument("name")
    sub.add_parser("validate")
    sub.add_parser("reapply")
    sub.add_parser("reload")
    args = p.parse_args()
    args.config = args.config or default_config()

    table = {
        "state": cmd_state, "quick": cmd_quick, "clear": cmd_clear,
        "save-profile": cmd_save_profile, "apply-current": cmd_apply_current,
        "set-enabled": cmd_set_enabled, "remove": cmd_remove, "move": cmd_move,
        "set-scoring": cmd_set_scoring, "set-notifications": cmd_set_notifications,
        "freeze": cmd_freeze, "validate": cmd_validate,
        "reapply": cmd_signal, "reload": cmd_signal,
    }
    return table[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
