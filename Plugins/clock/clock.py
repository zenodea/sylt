#!/usr/bin/env python3
"""The time as a wing item, refreshed on the minute (or the second), and the date in the expanded view."""
import json, os, sys, threading, time

lock = threading.Lock()
settings = {"seconds": False, "twentyFour": True, "date": True}
last = {"text": None, "date": None}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def publish():
    now = time.localtime()
    if settings["twentyFour"]:
        text = time.strftime("%H:%M:%S" if settings["seconds"] else "%H:%M", now)
    else:
        text = time.strftime("%I:%M:%S %p" if settings["seconds"] else "%I:%M %p", now).lstrip("0")
    if text != last["text"]:
        last["text"] = text
        emit({"wing": {"side": "right", "items": [{"text": text}]}})
    date = time.strftime("%A, %-d %B", now) if settings["date"] else ""
    if date != last["date"]:
        last["date"] = date
        if date:
            emit({"section": {"rows": [{"id": "today", "symbol": "calendar", "title": date, "detail": time.strftime("Week %V", now)}]}})
        else:
            emit({"clearSection": True})

def handle(event):
    if event.get("event") in ("start", "settings"):
        for key in settings:
            if key in (event.get("settings") or {}): settings[key] = bool(event["settings"][key])
        last.update({"text": None, "date": None})
        publish()

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
    time.sleep(1 if settings["seconds"] else 5)
    try:
        publish()
    except Exception as error:
        log("refresh failed: %s" % error)
