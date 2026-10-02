#!/usr/bin/env python3
"""Recent text copies as rows; clicking one puts it back on the pasteboard.
The host watches the pasteboard and skips password managers; this only keeps the list."""
import json, os, subprocess, sys

items = []
capacity = 8

def emit(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()

def preview(text):
    return " ".join(text.split())[:80]

def publish():
    rows = [{"id": str(i), "title": preview(t), "symbol": "doc.on.doc"} for i, t in enumerate(items)]
    emit({"section": {"title": "Clipboard", "symbol": "doc.on.clipboard.fill", "rows": rows}} if rows else {"clearSection": True})

for line in sys.stdin:
    try:
        event = json.loads(line)
    except ValueError:
        continue
    kind = event.get("event")
    if kind in ("start", "settings"):
        try: capacity = int((event.get("settings") or {}).get("capacity") or 8)
        except (TypeError, ValueError): pass
    elif kind == "clipboard":
        text = event.get("text") or ""
        items = [text] + [t for t in items if t != text]
        del items[capacity:]
        publish()
    elif kind == "click":
        try:
            subprocess.run(["pbcopy"], input=items[int(event["row"])].encode(), check=False)
        except (ValueError, IndexError):
            pass
    elif kind == "stop":
        break
os._exit(0)
