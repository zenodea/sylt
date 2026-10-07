#!/usr/bin/env python3
"""Mullvad VPN in the right wing: a shield while connected, with the city, read from the mullvad CLI."""
import json, os, re, shutil, subprocess, sys, threading, time

SYMBOL = "lock.shield.fill"
lock = threading.Lock()
settings = {"announce": True, "showWhenOff": True}
state = {"connected": None, "place": None, "relay": None, "ip": None}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def binary():
    for candidate in [shutil.which("mullvad"), "/usr/local/bin/mullvad", "/opt/homebrew/bin/mullvad",
                      "/Applications/Mullvad VPN.app/Contents/Resources/mullvad"]:
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
    """The CLI prints JSON on newer versions; older ones print a sentence, which is parsed instead."""
    raw = run("status", "-j")
    if raw:
        try:
            status = json.loads(raw)
            connected = status.get("state") == "connected"
            details = status.get("details") or {}
            location = details.get("location") or {}
            place = ", ".join(x for x in [location.get("city"), location.get("country")] if x) or None
            return {"connected": connected, "place": place if connected else None,
                    "relay": location.get("hostname") if connected else None, "ip": location.get("ipv4") if connected else None}
        except ValueError:
            pass
    raw = run("status")
    if raw is None: return None
    connected = raw.lstrip().lower().startswith("connected")
    place = None
    match = re.search(r"in ([^.\n]+)", raw) or re.search(r"location: ([^.\n]+)", raw, re.IGNORECASE)
    if connected and match: place = match.group(1).strip()
    relay = re.search(r"Relay: (\S+)", raw)
    return {"connected": connected, "place": place, "relay": relay.group(1) if relay and connected else None, "ip": None}

def publish():
    if state["connected"] is None:
        emit({"wing": {"side": "right", "items": []}})
        emit({"section": {"rows": [{"id": "open", "symbol": SYMBOL, "title": "Mullvad not installed"}]}})
        return
    if state["connected"]:
        items = [{"symbol": SYMBOL, "tint": "green", "text": state["place"].split(",")[0] if state["place"] else None}]
    else:
        items = [{"symbol": "shield.slash", "tint": "dim"}] if settings["showWhenOff"] else []
    emit({"wing": {"side": "right", "items": items, "spacing": 5}})
    rows = [{"id": "open", "symbol": SYMBOL, "title": "Connected" if state["connected"] else "Disconnected",
             "detail": state["place"] or ("Traffic goes out through Mullvad" if state["connected"] else "Traffic goes out directly"),
             "trailing": state["relay"], "trailingTint": "dim"}]
    if state["ip"]:
        rows.append({"id": "open", "symbol": "globe", "title": "Public address", "detail": state["ip"]})
    buttons = [{"id": "disconnect", "title": "Disconnect"}] if state["connected"] else [{"id": "connect", "title": "Connect"}]
    emit({"section": {"rows": rows, "buttons": buttons}})

def refresh(announce):
    current = snapshot() or {"connected": None, "place": None, "relay": None, "ip": None}
    was = state["connected"]
    if current == state: return
    state.update(current)
    publish()
    if announce and settings["announce"] and was is not None and current["connected"] != was:
        text = "VPN on · %s" % current["place"] if current["connected"] and current["place"] else ("VPN on" if current["connected"] else "VPN off")
        emit({"hud": {"symbol": SYMBOL if current["connected"] else "shield.slash", "tint": "green" if current["connected"] else "dim", "text": text, "side": "right", "duration": 2}})

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
            state.update({"connected": None, "place": None, "relay": None, "ip": None})
            refresh(False)
            publish()
        elif kind == "click":
            emit({"activate": {"bundle": "net.mullvad.vpn"}})
        elif kind == "button":
            run(event.get("id", ""))
            refresh(False)
        elif kind == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
while True:
    time.sleep(2)
    try:
        refresh(True)
    except Exception as error:
        emit({"log": "mullvad: %s" % error})
