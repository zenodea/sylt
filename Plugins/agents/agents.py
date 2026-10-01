#!/usr/bin/env python3
"""Claude, Codex and Pi agents: waiting ones first in the expanded list, up to three in the left wing."""
import json, os, shutil, subprocess, sys, threading, time

HERDR = next((p for p in [os.path.expanduser("~/.local/bin/herdr"), "/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"] if os.access(p, os.X_OK)), None)
GLYPH = {"claude": {"image": "app:com.anthropic.claudefordesktop"}, "codex": {"image": "app:com.openai.codex"}, "pi": {"text": "π", "tint": "indigo"}}
lock = threading.Lock()
agents = []
since = {}
cpu = {}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def from_herdr():
    out = subprocess.run([HERDR, "agent", "list"], capture_output=True, check=False).stdout
    data = json.loads(out or b"{}").get("result", {}).get("agents", [])
    return [{
        "id": a["pane_id"], "agent": a.get("agent", "").lower(), "working": a.get("agent_status") == "working",
        "title": a.get("terminal_title_stripped") or os.path.basename(a.get("cwd", "")) or a.get("agent", ""),
    } for a in data]

def from_processes():
    out = subprocess.run(["ps", "-axo", "pid=,%cpu=,comm="], capture_output=True, check=False).stdout.decode()
    found = []
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) < 3: continue
        pid, load, command = parts
        name = os.path.basename(command)
        if name not in GLYPH: continue
        cwd = subprocess.run(["lsof", "-a", "-d", "cwd", "-p", pid, "-Fn"], capture_output=True, check=False).stdout.decode()
        folder = next((l[1:] for l in cwd.splitlines() if l.startswith("n/")), "")
        found.append({"id": "pid:" + pid, "agent": name, "working": float(load) > 3, "title": os.path.basename(folder) or name})
    return found

def elapsed(seconds):
    minutes = int(seconds // 60)
    return "now" if minutes < 1 else "%dm" % minutes if minutes < 60 else "%dh" % (minutes // 60)

def publish():
    now = time.time()
    rows = [dict(GLYPH.get(a["agent"], {"symbol": "terminal.fill"}), id=a["id"], title=a["title"],
                 status="working" if a["working"] else "waiting",
                 trailing=None if a["working"] else elapsed(now - since.get(a["id"], now))) for a in agents]
    for row in rows: row.pop("tint", None)
    wing = [dict(GLYPH.get(a["agent"], {"symbol": "terminal.fill"}), status="working" if a["working"] else "waiting")
            for a in sorted(agents, key=lambda a: not a["working"])[:3]]
    emit({"wing": {"side": "left", "items": wing}})
    if rows:
        waiting = sum(1 for a in agents if not a["working"]); working = len(agents) - waiting
        emit({"section": {"title": "Agents", "symbol": "terminal.fill", "rows": rows,
                          "actions": [{"id": "counts", "title": "%d waiting · %d working" % (waiting, working)}]}})
    else:
        emit({"clearSection": True})

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("event") == "click":
            target = event.get("row", "")
            if HERDR and not target.startswith("pid:"):
                subprocess.run([HERDR, "agent", "focus", target], check=False)
                emit({"activate": {"process": "herdr"}})
            elif target.startswith("pid:"):
                emit({"activate": {"pid": int(target[4:])}})
        elif event.get("event") == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
while True:
    try:
        found = from_herdr() if HERDR else from_processes()
    except Exception:
        found = []
    found.sort(key=lambda a: (a["working"], a["id"]))
    previous = {a["id"]: a for a in agents}
    now = time.time()
    for a in found:
        before = previous.get(a["id"])
        if before is None or before["working"] != a["working"]:
            since[a["id"]] = now
            if before is not None and before["working"] and not a["working"]:
                emit({"hud": {"symbol": "checkmark.circle.fill", "tint": "green", "text": a["title"], "side": "left", "duration": 2.5}})
    for gone in set(previous) - {a["id"] for a in found}: since.pop(gone, None)
    if found != agents:
        agents = found
        publish()
    time.sleep(2)
