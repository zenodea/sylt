#!/usr/bin/env python3
"""Recent text copies as rows; clicking one puts it back on the pasteboard.
The host watches the pasteboard and skips password managers; this only keeps the list."""
import json, subprocess, sys, threading

items = []
capacity = 8
copied = {"index": None}

def emit(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()

def log(text):
    emit({"log": text})

def preview(text):
    return " ".join(text.split())[:80]

def publish():
    rows = [{"id": str(i), "title": preview(t), "symbol": "checkmark.circle.fill" if i == copied["index"] else "doc.on.doc",
             "trailing": "copied" if i == copied["index"] else None} for i, t in enumerate(items)]
    emit({"section": {"title": "Clipboard", "symbol": "doc.on.clipboard.fill", "rows": rows}} if rows else {"clearSection": True})

def handle(event):
    global items, capacity
    kind = event.get("event")
    if kind in ("start", "settings"):
        capacity = int((event.get("settings") or {}).get("capacity") or 8)
    elif kind == "clipboard":
        text = event.get("text") or ""
        items = [text] + [t for t in items if t != text]
        del items[capacity:]
        publish()
    elif kind == "click" and event.get("row"):
        index = int(event["row"])
        subprocess.run(["pbcopy"], input=items[index].encode(), check=False, timeout=5)
        copied["index"] = index
        publish()
        threading.Timer(1.5, lambda: (copied.update(index=None), publish())).start()

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
