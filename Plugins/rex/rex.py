#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOT = os.path.join(HERE, "snapshot.lua")
REX = next((p for p in [
    shutil.which("rex"),
    os.path.expanduser("~/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"),
    "/Applications/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex",
    "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex",
] if p and os.access(p, os.X_OK)), None)
BUNDLE = "com.superlogical.rex"
GLYPH = {"claude-code": {"image": "app:com.anthropic.claudefordesktop"}, "codex": {"image": "app:com.openai.codex"}}
STATUS = {"working": "working", "blocked": "waiting", "error": "waiting", "done": "done", "idle": "waiting"}
RANK = {"working": 0, "blocked": 1, "error": 1, "done": 2, "idle": 3}
NEEDS = {"permission": "Needs approval", "question": "Has a question", "auth": "Needs sign-in"}
lock = threading.Lock()
panes = []
app_client = None
since = {}
settings = {"shown": 3}
store = None

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def rex(*args):
    return subprocess.run([REX, "--autostart=false", *args], capture_output=True, check=False, timeout=10)

def glyph(pane):
    return GLYPH.get(pane["app"], {"symbol": "terminal.fill"})

def from_rex():
    global app_client
    result = rex("do", SNAPSHOT, "--json")
    if result.returncode != 0: return []
    data = json.loads(result.stdout or b"{}")
    app_client = data.get("app")
    return [pane(p) for p in data.get("panes") or []]

def pane(p):
    state = p.get("state") if p.get("state") in RANK else "idle"
    label = p.get("label") if p.get("label") != "shell" else None
    return {
        "id": p["block_id"], "session": p["session_id"], "window": p.get("window_id"), "app": p.get("app") or "", "state": state,
        "title": label or p.get("title") or p.get("window") or p.get("session") or "",
        "detail": (state == "blocked" and NEEDS.get(p.get("kind"))) or p.get("msg") or p.get("session"),
    }

def elapsed(seconds):
    minutes = int(seconds // 60)
    return "now" if minutes < 1 else "%dm" % minutes if minutes < 60 else "%dh" % (minutes // 60)

def trailing(pane, now):
    if pane["state"] == "error": return "failed"
    changed = since.get(pane["id"])
    return None if pane["state"] == "working" or changed is None else elapsed(now - changed)

def count(*states):
    return str(sum(1 for p in panes if p["state"] in states))

def publish():
    now = time.time()
    rows = [dict(glyph(p), id=p["id"], title=p["title"], detail=p["detail"], status=STATUS[p["state"]],
                 highlighted=p["state"] in ("blocked", "error"), trailingTint="red" if p["state"] == "error" else None,
                 trailing=trailing(p, now)) for p in panes]
    emit({"wing": {"side": "left", "items": [dict(glyph(p), status=STATUS[p["state"]]) for p in panes[:settings["shown"]]], "spacing": 3}})
    if not rows:
        emit({"clearSection": True})
        return
    emit({"section": {"title": "Rex", "symbol": "terminal.fill", "rows": rows,
                      "items": [{"dot": "green", "text": count("working")}, {"dot": "orange", "text": count("blocked", "error")}, {"dot": "blue", "text": count("done")}]}})

def hud(pane, text, duration, symbol, tint):
    emit({"hud": dict(glyph(pane), text=text, side="left", duration=duration, trailingSymbol=symbol, trailingTint=tint)})

def announce(before, pane):
    if before == "working" and pane["state"] == "done":
        hud(pane, pane["title"], 2.5, "checkmark.circle.fill", "green")
    elif pane["state"] == "blocked":
        hud(pane, pane["detail"] or pane["title"], 3, "hand.raised.fill", "orange")
    elif pane["state"] == "error":
        hud(pane, pane["title"], 3, "xmark.circle.fill", "red")

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
    global panes
    found = from_rex() if REX else []
    previous = {p["id"]: p for p in panes}
    now = time.time()
    changed = False
    for p in found:
        before = previous.get(p["id"])
        if before is not None and before["state"] != p["state"]:
            since[p["id"]] = now
            changed = True
            announce(before["state"], p)
    ids = {p["id"] for p in found}
    for gone in (set(since) if found else set(previous)) - ids:
        if since.pop(gone, None) is not None: changed = True
    if changed and store: save_since()
    found.sort(key=lambda p: (RANK[p["state"]], -since.get(p["id"], 0), p["id"]))
    if found != panes or changed:
        panes = found
        publish()

def focus(target):
    pane = next((p for p in panes if p["id"] == target), None)
    if pane is None: return
    if app_client:
        args = ["session_id=" + pane["session"]] + (["window_id=" + pane["window"]] if pane["window"] else [])
        rex("-C", app_client, "do", "session.select", *args)
    rex("focus", "-s", pane["session"], pane["id"])
    emit({"activate": {"bundle": BUNDLE}})

def apply_settings(values):
    try: settings["shown"] = max(0, int(values.get("shown", 3) or 0))
    except (TypeError, ValueError): pass

def handle(event):
    kind = event.get("event")
    if kind in ("start", "settings"):
        apply_settings(event.get("settings") or {})
        if kind == "start": load_since(event.get("dataDir"))
        else: publish()
    elif kind == "click" and event.get("row") and REX:
        focus(event["row"])

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
if not REX: log("rex not found")
while True:
    try:
        refresh()
    except Exception as error:
        log("refresh failed: %s" % error)
    time.sleep(2)
