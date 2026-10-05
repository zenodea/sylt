#!/usr/bin/env python3
"""Slack's Dock badge in the right wing: the count of mentions and direct messages, or a
dot for unread channels. Read through LaunchServices, so no token or permission is needed."""
import json, os, re, subprocess, sys, threading, time

BUNDLE = "com.tinyspeck.slackmacgap"
lock = threading.Lock()
settings = {"announce": True, "showDot": True}
state = {"badge": None, "running": False}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def lsappinfo(*args):
    try:
        return subprocess.run(["/usr/bin/lsappinfo", *args], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return ""

def badge():
    """None when Slack isn't running or shows no badge; an int for mentions; "dot" for unread."""
    found = re.search(r"ASN:0x0-0x[0-9a-f]+", lsappinfo("find", "bundleid=" + BUNDLE))
    if not found:
        return None, False
    info = lsappinfo("info", "-only", "StatusLabel", found.group(0))
    label = re.search(r'"label"\s*=\s*"([^"]*)"', info)
    if not label:
        return None, True
    text = label.group(1).strip()
    if text.isdigit():
        return int(text), True
    return ("dot" if text else None), True

def publish():
    value = state["badge"]
    if isinstance(value, int) and value > 0:
        items = [{"image": "app:" + BUNDLE, "text": str(value)}]
        detail = "%d unread %s" % (value, "mention" if value == 1 else "mentions")
    elif value == "dot" and settings["showDot"]:
        items = [{"image": "app:" + BUNDLE, "dot": "red"}]
        detail = "Unread messages"
    else:
        items = []
        detail = "Nothing unread" if state["running"] else "Slack isn't running"
    emit({"wing": {"side": "right", "items": items}})
    emit({"section": {"rows": [{"id": "open", "image": "app:" + BUNDLE, "title": "Open Slack", "detail": detail}]}})

def refresh(announce):
    value, running = badge()
    previous = state["badge"]
    if value == previous and running == state["running"]:
        return
    state.update({"badge": value, "running": running})
    publish()
    grew = isinstance(value, int) and (not isinstance(previous, int) or value > previous)
    if announce and settings["announce"] and grew:
        emit({"hud": {"image": "app:" + BUNDLE, "text": "%d unread" % value, "side": "right", "duration": 2}})

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
            state.update({"badge": None, "running": False})
            refresh(False)
            publish()
        elif kind == "click":
            emit({"activate": {"bundle": BUNDLE}})
        elif kind == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
while True:
    time.sleep(2)
    refresh(True)
