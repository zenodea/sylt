#!/usr/bin/env python3
"""Recent text copies as rows; clicking one puts it back on the pasteboard."""
import json, os, subprocess, sys, threading, time

lock = threading.Lock()
items = []
capacity = 8
last = None
muted_until = 0

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def preview(text):
    return " ".join(text.split())[:80]

def publish():
    rows = [{"id": str(i), "title": preview(t), "symbol": "doc.on.doc"} for i, t in enumerate(items)]
    emit({"section": {"title": "Clipboard", "symbol": "doc.on.clipboard.fill", "rows": rows}} if rows else {"clearSection": True})

def listen():
    global capacity, muted_until
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("event")
        if kind in ("start", "settings"):
            try: capacity = int((event.get("settings") or {}).get("capacity") or 8)
            except (TypeError, ValueError): pass
        elif kind == "click":
            try:
                text = items[int(event["row"])]
                subprocess.run(["pbcopy"], input=text.encode(), check=False)
                muted_until = time.time() + 2
            except (ValueError, IndexError):
                pass
        elif kind == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
while True:
    time.sleep(0.7)
    if time.time() < muted_until: continue
    text = subprocess.run(["pbpaste"], capture_output=True, check=False).stdout.decode("utf-8", "replace")
    if not text.strip() or text == last: continue
    last = text
    items[:] = [text] + [t for t in items if t != text]
    del items[capacity:]
    publish()
