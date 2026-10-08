#!/usr/bin/env python3
"""Claude, Codex and Pi agents in three groups: working, then done, then waiting, newest change first in each."""
import json, os, subprocess, sys, threading, time

HERDR = next((p for p in [os.path.expanduser("~/.local/bin/herdr"), "/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"] if os.access(p, os.X_OK)), None)
HERE = os.path.dirname(os.path.abspath(__file__))
GLYPH = {"claude": {"image": "app:com.anthropic.claudefordesktop"}, "codex": {"image": "app:com.openai.codex"}, "pi": {"image": "file:" + os.path.join(HERE, "pi.svg")}}
RANK = {"working": 0, "done": 1, "waiting": 2}
lock = threading.Lock()
agents = []
since = {}
store = None

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def glyph(agent):
    return GLYPH.get(agent, {"symbol": "terminal.fill"})

def from_herdr():
    out = subprocess.run([HERDR, "agent", "list"], capture_output=True, check=False, timeout=10).stdout
    data = json.loads(out or b"{}").get("result", {}).get("agents", [])
    return [{
        "id": a["pane_id"], "agent": a.get("agent", "").lower(),
        "status": a.get("agent_status") if a.get("agent_status") in RANK else "waiting",
        "title": a.get("terminal_title_stripped") or os.path.basename(a.get("cwd", "")) or a.get("agent", ""),
        "focused": bool(a.get("focused")),
    } for a in data]

def from_processes():
    out = subprocess.run(["ps", "-axo", "pid=,%cpu=,comm="], capture_output=True, check=False, timeout=10).stdout.decode()
    found = []
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) < 3: continue
        pid, load, command = parts
        name = os.path.basename(command)
        if name not in GLYPH: continue
        cwd = subprocess.run(["lsof", "-a", "-d", "cwd", "-p", pid, "-Fn"], capture_output=True, check=False, timeout=10).stdout.decode()
        folder = next((l[1:] for l in cwd.splitlines() if l.startswith("n/")), "")
        found.append({"id": "pid:" + pid, "agent": name, "status": "working" if float(load) > 3 else "waiting", "title": os.path.basename(folder) or name, "focused": False})
    return found

def elapsed(seconds):
    minutes = int(seconds // 60)
    return "now" if minutes < 1 else "%dm" % minutes if minutes < 60 else "%dh" % (minutes // 60)

def publish():
    now = time.time()
    rows = []
    for a in agents:
        changed = since.get(a["id"])
        rows.append(dict(glyph(a["agent"]), id=a["id"], title=a["title"], status=a["status"], highlighted=a["focused"],
                         trailing=None if a["status"] == "working" or changed is None else elapsed(now - changed)))
    emit({"wing": {"side": "left", "items": [dict(glyph(a["agent"]), status=a["status"]) for a in agents[:3]], "spacing": 3}})
    if not rows:
        emit({"clearSection": True})
        return
    counts = {k: sum(1 for a in agents if a["status"] == k) for k in RANK}
    emit({"section": {"title": "🐑 Herdr" if HERDR else "Agents", "symbol": None if HERDR else "terminal.fill", "rows": rows,
                      "items": [{"dot": "green", "text": str(counts["working"])}, {"dot": "blue", "text": str(counts["done"])}, {"dot": "orange", "text": str(counts["waiting"])}]}})

def load_since(data_dir):
    global store
    store = os.path.join(data_dir or ".", "since.json")
    try:
        with open(store) as handle: since.update({k: float(v) for k, v in json.load(handle).items()})
    except (OSError, ValueError):
        pass

def save_since():
    try:
        with open(store, "w") as handle: json.dump(since, handle)
    except OSError as error:
        log("could not save since.json: %s" % error)

def refresh():
    global agents
    found = from_herdr() if HERDR else from_processes()
    previous = {a["id"]: a for a in agents}
    now = time.time()
    changed = False
    for a in found:
        before = previous.get(a["id"])
        if before is not None and before["status"] != a["status"]:
            since[a["id"]] = now
            changed = True
            if before["status"] == "working":
                emit({"hud": dict(glyph(a["agent"]), text=a["title"], side="left", duration=2.5, trailingSymbol="checkmark.circle.fill", trailingTint="green")})
    for gone in set(previous) - {a["id"] for a in found}:
        if since.pop(gone, None) is not None: changed = True
    if changed and store: save_since()
    found.sort(key=lambda a: (RANK[a["status"]], -since.get(a["id"], 0), a["id"]))
    if found != agents or changed:
        agents = found
        publish()

def handle(event):
    kind = event.get("event")
    if kind == "start":
        load_since(event.get("dataDir"))
    elif kind == "click":
        target = event.get("row", "")
        if target.startswith("pid:"):
            emit({"activate": {"pid": int(target[4:])}})
        elif HERDR:
            subprocess.run([HERDR, "agent", "focus", target], check=False, timeout=10)
            title = next((a["title"] for a in agents if a["id"] == target), None)
            emit({"activate": {"process": "herdr", "window": title}})

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("event") == "stop": os._exit(0)
        try:
            handle(event)
        except Exception as error:
            log("%s failed: %s" % (event.get("event"), error))
    os._exit(0)

threading.Thread(target=listen, daemon=True).start()
while True:
    try:
        refresh()
    except Exception as error:
        log("refresh failed: %s" % error)
    time.sleep(2)
