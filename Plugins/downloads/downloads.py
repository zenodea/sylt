#!/usr/bin/env python3
"""Watches ~/Downloads for browsers' partial files and reports each download starting and landing."""
import json, os, sys, time

PARTIAL = {"download", "crdownload", "part", "partial", "tmp"}
FOLDER = os.path.expanduser("~/Downloads")

def emit(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()

def partials():
    names = os.listdir(FOLDER)
    return names, {os.path.splitext(n)[0] for n in names if os.path.splitext(n)[1].lstrip(".").lower() in PARTIAL}

import threading
sys.stdin.readline()
threading.Thread(target=lambda: (sys.stdin.read(), os._exit(0)), daemon=True).start()
_, active = partials()
while True:
    time.sleep(2)
    names, current = partials()
    for name in current - active:
        emit({"hud": {"symbol": "arrow.down.circle.fill", "tint": "blue", "text": name, "duration": 2.2}})
    for name in active - current:
        if any(n.startswith(name) for n in names):
            emit({"hud": {"symbol": "checkmark.circle.fill", "tint": "green", "text": name, "duration": 2.2}})
    active = current
