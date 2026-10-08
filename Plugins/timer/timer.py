#!/usr/bin/env python3
"""Presets in the expanded view; a draining ring with the time left in the left wing while one runs."""
import json, os, sys, threading, time

lock = threading.Lock()
state = {"end": None, "duration": 0, "presets": [5, 15, 25, 60]}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def label(minutes):
    return "%d h" % (minutes // 60) if minutes >= 60 and minutes % 60 == 0 else "%d min" % minutes

def clock(seconds):
    seconds = int(seconds + 0.999)
    return "%d:%02d:%02d" % (seconds // 3600, seconds // 60 % 60, seconds % 60) if seconds >= 3600 else "%d:%02d" % (seconds // 60, seconds % 60)

def idle():
    emit({"wing": {"side": "left", "items": []}})
    emit({"section": {"buttons": [{"id": str(m), "title": label(m)} for m in state["presets"]]}})

def running():
    remaining = max(0, state["end"] - time.time())
    fraction = remaining / state["duration"] if state["duration"] else 0
    emit({"wing": {"side": "left", "items": [{"ring": fraction, "text": clock(remaining)}]}})
    emit({"section": {"rows": [{"id": "running", "symbol": "timer", "title": clock(remaining), "buttons": [{"id": "cancel", "title": "Cancel"}]}]}})

def apply_settings(settings):
    try:
        presets = [int(p) for p in str(settings.get("presets", "")).replace(";", ",").split(",") if p.strip()]
    except ValueError:
        log("presets must be minutes separated by commas")
        return
    if presets: state["presets"] = presets

def finish():
    minutes = state["duration"] // 60
    state["end"] = None
    emit({"sound": "Hero"})
    emit({"hud": {"symbol": "timer", "tint": "orange", "text": "%d min timer done" % minutes, "duration": 3}})
    idle()

def handle(event):
    kind = event.get("event")
    if kind in ("start", "settings"):
        apply_settings(event.get("settings") or {})
        if state["end"] is None: idle()
    elif kind == "button":
        if event.get("id") == "cancel":
            state["end"] = None
            idle()
        else:
            state["duration"] = int(event["id"]) * 60
            state["end"] = time.time() + state["duration"]
            running()

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
    time.sleep(1)
    if state["end"] is None: continue
    try:
        finish() if time.time() >= state["end"] else running()
    except Exception as error:
        log("tick failed: %s" % error)
