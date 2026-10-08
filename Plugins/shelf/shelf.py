#!/usr/bin/env python3
"""Files dropped on the island, kept until removed."""
import json, os, sys

files = []
store = None

def emit(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()

def log(text):
    emit({"log": text})

def publish():
    if files:
        emit({"section": {"title": "Shelf", "symbol": "tray.full.fill", "files": files, "actions": [{"id": "clear", "title": "Clear"}]}})
    else:
        emit({"clearSection": True})

def save():
    with open(store, "w") as handle: json.dump(files, handle)

def handle(event):
    global files, store
    kind = event.get("event")
    if kind == "start":
        store = os.path.join(event.get("dataDir") or ".", "shelf.json")
        try:
            with open(store) as handle: files = [f for f in json.load(handle) if os.path.exists(f)]
        except (OSError, ValueError):
            files = []
        publish()
    elif kind == "drop":
        for path in event.get("files") or []:
            if path not in files: files.append(path)
        save(); publish()
    elif kind == "remove":
        files = [f for f in files if f != event.get("row")]
        save(); publish()
    elif kind == "action" and event.get("id") == "clear":
        files = []
        save(); publish()

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("event") == "stop": return
        try:
            handle(event)
        except Exception as error:
            log("%s failed: %s" % (event.get("event"), error))

listen()
