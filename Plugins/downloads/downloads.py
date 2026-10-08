#!/usr/bin/env python3
"""Watches ~/Downloads for browsers' partial files and reports each download starting and landing."""
import json, os, sys, threading, time

PARTIAL = {"download", "crdownload", "part", "partial", "tmp"}
FOLDER = os.path.expanduser("~/Downloads")
lock = threading.Lock()

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def partials():
    names = os.listdir(FOLDER)
    return names, {os.path.splitext(n)[0] for n in names if os.path.splitext(n)[1].lstrip(".").lower() in PARTIAL}

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("event") == "stop": os._exit(0)
    os._exit(0)

threading.Thread(target=listen, daemon=True).start()
active = set()
while True:
    try:
        names, current = partials()
        for name in current - active:
            emit({"hud": {"symbol": "arrow.down.circle.fill", "tint": "blue", "text": name, "duration": 2.2}})
        for name in active - current:
            if any(n.startswith(name) for n in names):
                emit({"hud": {"symbol": "checkmark.circle.fill", "tint": "green", "text": name, "duration": 2.2}})
        active = current
    except OSError as error:
        log("cannot read %s: %s" % (FOLDER, error))
    time.sleep(2)
