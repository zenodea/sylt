#!/usr/bin/env python3
"""Workspaces in the left wing, the focused one bright; rows with each workspace's apps in the expanded view."""
import json, os, shutil, subprocess, sys, threading, time

lock = threading.Lock()
settings = {"announce": False, "showEmpty": False}
state = {"focused": None, "workspaces": []}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def binary():
    for candidate in [shutil.which("aerospace"), "/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace",
                      os.path.expanduser("~/.nix-profile/bin/aerospace")]:
        if candidate and os.access(candidate, os.X_OK): return candidate
    return None

def run(*args):
    tool = binary()
    if not tool: return None
    try:
        return subprocess.run([tool, *args], capture_output=True, text=True, timeout=3).stdout.splitlines()
    except (OSError, subprocess.SubprocessError):
        return None

def snapshot():
    focused = run("list-workspaces", "--focused")
    if focused is None: return None
    focused = focused[0].strip() if focused else None
    names = run("list-workspaces", "--all" if settings["showEmpty"] else "--monitor", *([] if settings["showEmpty"] else ["all", "--empty", "no"])) or []
    names = [n.strip() for n in names if n.strip()]
    if focused and focused not in names: names.append(focused)
    names.sort(key=lambda n: (not n.isdigit(), int(n) if n.isdigit() else n))
    return {"focused": focused, "workspaces": names}

def apps(workspace):
    lines = run("list-windows", "--workspace", workspace, "--format", "%{app-name}") or []
    seen = []
    for name in (l.strip() for l in lines):
        if name and name not in seen: seen.append(name)
    return seen

def publish():
    if state["focused"] is None and not state["workspaces"]:
        emit({"wing": {"side": "left", "items": []}})
        emit({"section": {"rows": [{"id": "missing", "symbol": "square.grid.3x3", "title": "AeroSpace not running"}]}})
        return
    items = [{"text": n, "tint": "white" if n == state["focused"] else "dim"} for n in state["workspaces"]]
    emit({"wing": {"side": "left", "items": items, "spacing": 6}})
    rows = []
    for n in state["workspaces"]:
        names = apps(n)
        rows.append({"id": n, "title": "Workspace %s" % n, "detail": ", ".join(names) if names else "Empty",
                     "highlighted": n == state["focused"], "trailing": "current" if n == state["focused"] else None})
    emit({"section": {"rows": rows}})

def focused_now():
    lines = run("list-workspaces", "--focused")
    if lines is None: return None
    return lines[0].strip() if lines else None

def refresh(announce_change):
    current = snapshot()
    if current is None:
        current = {"focused": None, "workspaces": []}
    changed = current != state
    switched = announce_change and current["focused"] != state["focused"] and current["focused"] is not None
    state.update(current)
    if changed: publish()
    if switched and settings["announce"]:
        emit({"hud": {"symbol": "square.grid.3x3.fill", "text": "Workspace %s" % current["focused"], "side": "left", "duration": 1.2}})

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("event")
        if kind in ("start", "settings"):
            for key in settings:
                if key in (event.get("settings") or {}): settings[key] = bool(event["settings"][key])
            state.update({"focused": None, "workspaces": []})
            refresh(False)
        elif kind == "click":
            run("workspace", event.get("row", ""))
            refresh(False)
        elif kind == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
last_full = 0
while True:
    time.sleep(0.25)
    if focused_now() != state["focused"] or time.time() - last_full > 2:
        last_full = time.time()
        refresh(True)
