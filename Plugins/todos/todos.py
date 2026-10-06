#!/usr/bin/env python3
"""Open reminders in the left wing as a count, listed in the expanded view, ticked off with a click."""
import json, os, subprocess, sys, threading, time

lock = threading.Lock()
settings = {"list": "", "dueOnly": False, "limit": 6}
state = {"items": None}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def osascript(script):
    try:
        done = subprocess.run(["/usr/bin/osascript", "-e", script], capture_output=True, text=True, timeout=20)
        return done.stdout if done.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None

def fetch():
    source = 'list "%s"' % settings["list"].replace('"', '') if settings["list"] else "default list's container"
    scope = 'reminders of list "%s"' % settings["list"].replace('"', '') if settings["list"] else "reminders"
    script = '''
    tell application "Reminders"
        set out to ""
        repeat with r in (%s whose completed is false)
            set d to ""
            try
                set dd to due date of r
                if dd is not missing value then set d to (short date string of dd) & " " & (time string of dd)
            end try
            set out to out & (id of r) & tab & (name of r) & tab & d & linefeed
        end repeat
        return out
    end tell''' % scope
    raw = osascript(script)
    if raw is None: return None
    items = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0]:
            due = parts[2] if len(parts) > 2 else ""
            if settings["dueOnly"] and not due: continue
            items.append({"id": parts[0], "title": parts[1], "due": due})
    return items

def publish():
    items = state["items"]
    if items is None:
        emit({"wing": {"side": "left", "items": []}})
        emit({"section": {"rows": [{"id": "open", "symbol": "checklist", "title": "Reminders not available", "detail": "Allow Sylt to control Reminders"}]}})
        return
    count = len(items)
    emit({"wing": {"side": "left", "items": [{"symbol": "checklist", "text": str(count)}] if count else []}})
    rows = [{"id": i["id"], "symbol": "circle", "title": i["title"], "detail": i["due"] or None} for i in items[: int(settings["limit"]) or 6]]
    if not rows:
        rows = [{"id": "open", "symbol": "checkmark.circle", "title": "All done"}]
    emit({"section": {"rows": rows, "buttons": [{"id": "open", "title": "Open Reminders"}]}})

def refresh():
    items = fetch()
    if items != state["items"]:
        state["items"] = items
        publish()

def complete(identifier):
    osascript('tell application "Reminders" to set completed of reminder id "%s" to true' % identifier.replace('"', ''))
    emit({"sound": "Pop"})
    refresh()

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("event")
        if kind in ("start", "settings"):
            values = event.get("settings") or {}
            settings["list"] = str(values.get("list", "") or "")
            settings["dueOnly"] = bool(values.get("dueOnly", False))
            try: settings["limit"] = int(values.get("limit", 6) or 6)
            except (TypeError, ValueError): pass
            state["items"] = None
            refresh()
        elif kind == "click":
            row = event.get("row", "")
            if row == "open": emit({"open": "x-apple-reminderkit://"})
            else: complete(row)
        elif kind == "button":
            emit({"activate": {"bundle": "com.apple.reminders"}})
        elif kind == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
while True:
    time.sleep(30)
    refresh()
