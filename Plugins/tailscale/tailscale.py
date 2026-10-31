#!/usr/bin/env python3
import json, os, plistlib, shutil, subprocess, sys, threading, time

# The standalone and App Store builds have different bundle ids.
def bundle_id():
    for folder in ("/Applications", os.path.expanduser("~/Applications")):
        try:
            with open(os.path.join(folder, "Tailscale.app/Contents/Info.plist"), "rb") as handle:
                return plistlib.load(handle)["CFBundleIdentifier"]
        except (OSError, KeyError, plistlib.InvalidFileException):
            continue
    return "io.tailscale.ipn.macos"

SYMBOL = "point.3.filled.connected.trianglepath.dotted"
BUNDLE = bundle_id()
ICON = {"image": "app:" + BUNDLE}
lock = threading.Lock()
settings = {"announce": True, "showWhenOff": False}
UNKNOWN = {"up": None, "exit": None, "ip": None, "peers": [], "online": 0}
state = dict(UNKNOWN)

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def binary():
    for candidate in [shutil.which("tailscale"), "/Applications/Tailscale.app/Contents/MacOS/Tailscale", "/usr/local/bin/tailscale", "/opt/homebrew/bin/tailscale"]:
        if candidate and os.access(candidate, os.X_OK): return candidate
    return None

def run(*args):
    tool = binary()
    if not tool: return None
    try:
        done = subprocess.run([tool, *args], capture_output=True, text=True, timeout=8)
        return done.stdout if done.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None

def snapshot():
    raw = run("status", "--json")
    if raw is None: return None
    try:
        status = json.loads(raw)
    except ValueError:
        return None
    up = status.get("BackendState") == "Running"
    peers = list((status.get("Peer") or {}).values())
    exit_node = next((p for p in peers if p.get("ExitNode")), None)
    place = None
    if exit_node:
        location = exit_node.get("Location") or {}
        place = ", ".join(x for x in [location.get("City"), location.get("Country")] if x) or exit_node.get("HostName")
    ips = status.get("TailscaleIPs") or []
    return {
        "up": up,
        "exit": place,
        "ip": next((ip for ip in ips if "." in ip), ips[0] if ips else None),
        "online": sum(1 for p in peers if p.get("Online")),
        "peers": sorted(((p.get("HostName") or "?", bool(p.get("Online")), p.get("OS") or "") for p in peers), key=lambda p: (not p[1], p[0].lower()))[:8],
    }

def publish():
    if state["up"] is None:
        emit({"wing": {"side": "right", "items": []}})
        emit({"section": {"rows": [dict(ICON, id="open", title="Tailscale not running")], "buttons": [{"id": "up", "title": "Connect"}]}})
        return
    if state["up"]:
        items = [{"symbol": SYMBOL, "tint": "green", "text": state["exit"] or None}]
    else:
        items = [{"symbol": SYMBOL, "tint": "dim"}] if settings["showWhenOff"] else []
    emit({"wing": {"side": "right", "items": items, "spacing": 5}})
    rows = [dict(ICON, id="open", title="This Mac", detail=state["ip"] or "No address", trailing="up" if state["up"] else "down",
             trailingTint="green" if state["up"] else "dim")]
    if state["exit"]:
        rows.append({"id": "exit", "symbol": "arrow.up.right.square", "title": "Exit node", "detail": state["exit"], "trailing": "stop", "trailingTint": "orange"})
    for name, online, system in state["peers"]:
        rows.append({"id": "peer:" + name, "symbol": "desktopcomputer" if system in ("macOS", "windows", "linux") else "iphone", "title": name,
                     "detail": system, "status": "working" if online else None, "trailing": "online" if online else "offline", "trailingTint": "green" if online else "dim"})
    buttons = [{"id": "down", "title": "Disconnect"}] if state["up"] else [{"id": "up", "title": "Connect"}]
    emit({"section": {"title": "Tailscale · %d online" % state["online"] if state["up"] else "Tailscale", "symbol": SYMBOL, "rows": rows, "buttons": buttons}})

def refresh(announce):
    current = snapshot() or UNKNOWN
    if current == state: return False
    was_up, was_exit = state["up"], state["exit"]
    state.update(current)
    publish()
    if not announce or not settings["announce"]: return True
    if current["up"] != was_up and was_up is not None:
        emit({"hud": dict(ICON, text="Tailscale on" if current["up"] else "Tailscale off", side="right", duration=2)})
    elif current["up"] and current["exit"] != was_exit:
        emit({"hud": {"symbol": "arrow.up.right.square", "tint": "white", "text": "Exit node · %s" % current["exit"] if current["exit"] else "Exit node off", "side": "right", "duration": 2}})
    return True

def handle(event):
    kind = event.get("event")
    if kind in ("start", "settings"):
        values = event.get("settings") or {}
        settings.update({key: bool(values[key]) for key in settings if key in values})
        state.update(UNKNOWN)
        if not refresh(False): publish()
    elif kind == "click":
        if event.get("row") == "exit": run("set", "--exit-node=")
        else: emit({"activate": {"bundle": BUNDLE}})
        refresh(False)
    elif kind == "button":
        run(event.get("id", ""))
        refresh(False)

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
    time.sleep(3)
    try:
        refresh(True)
    except Exception as error:
        log("refresh failed: %s" % error)
