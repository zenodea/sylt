#!/usr/bin/env python3
"""Slack's Dock badge in the right wing: the count of mentions and direct messages, or a
dot for unread channels. Read through LaunchServices, so no token or permission is needed."""
import json, os, re, subprocess, sys, threading, time

BUNDLE = "com.tinyspeck.slackmacgap"
lock = threading.Lock()
settings = {"announce": True, "showDot": True}
state = {"badge": None, "running": None}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def lsappinfo(*args):
    return subprocess.run(["/usr/bin/lsappinfo", *args], capture_output=True, text=True, timeout=3).stdout

def badge():
    """(None when Slack shows no badge, an int for mentions, "dot" for unread; whether Slack runs)."""
    found = re.search(r"ASN:0x0-0x[0-9a-f]+", lsappinfo("find", "bundleid=" + BUNDLE))
    if not found:
        return None, False
    label = re.search(r'"label"\s*=\s*"([^"]*)"', lsappinfo("info", "-only", "StatusLabel", found.group(0)))
    text = label.group(1).strip() if label else ""
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

def handle(event):
    kind = event.get("event")
    if kind in ("start", "settings"):
        for key in settings:
            if key in (event.get("settings") or {}): settings[key] = bool(event["settings"][key])
        state.update({"badge": None, "running": None})
        refresh(False)
    elif kind == "click":
        emit({"activate": {"bundle": BUNDLE}})

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
    time.sleep(2)
    try:
        refresh(True)
    except Exception as error:
        log("refresh failed: %s" % error)
