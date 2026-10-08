#!/usr/bin/env python3
"""Network traffic: bytes in and out per second from netstat, as two sparklines in the right wing."""
import json, os, subprocess, sys, threading, time

SAMPLES = 24
lock = threading.Lock()
settings = {"interface": "", "rateAbove": 50.0}
state = {"last": None, "down": [0.0] * SAMPLES, "up": [0.0] * SAMPLES, "iface": None}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": "traffic: %s" % text})

def counters():
    """Total bytes in and out per interface, from the kernel's own table."""
    try:
        out = subprocess.run(["/usr/sbin/netstat", "-ib"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    totals = {}
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 10 or not parts[0].startswith(("en", "utun", "bridge")) or not parts[6].isdigit(): continue
        if parts[0] not in totals: totals[parts[0]] = (int(parts[6]), int(parts[9]))
    return totals

def rate(value):
    if value >= 1_000_000: return "%.1f MB/s" % (value / 1_000_000)
    if value >= 1_000: return "%.0f kB/s" % (value / 1_000)
    return "%d B/s" % value

def normalise(series):
    top = max(max(series), 1.0)
    return [round(v / top, 3) for v in series]

def sample():
    now = time.time()
    totals = counters()
    last = state["last"]
    state["last"] = (now, totals)
    if not last or not totals: return None
    elapsed = max(0.1, now - last[0])
    wanted = settings["interface"].strip()
    candidates = [wanted] if wanted and wanted in totals else list(totals)
    best, down, up = None, 0.0, 0.0
    for name in candidates:
        before = last[1].get(name)
        if not before: continue
        d, u = (totals[name][0] - before[0]) / elapsed, (totals[name][1] - before[1]) / elapsed
        if best is None or d + u > down + up: best, down, up = name, max(0.0, d), max(0.0, u)
    state["iface"] = best
    state["down"] = state["down"][1:] + [down]
    state["up"] = state["up"][1:] + [up]
    return down, up

def publish(down, up):
    threshold = settings["rateAbove"] * 1000
    items = [{"graph": normalise(state["down"]), "tint": "cyan"}, {"graph": normalise(state["up"]), "tint": "orange"}]
    if max(down, up) >= threshold:
        items.append({"text": rate(max(down, up))})
    emit({"wing": {"side": "right", "items": items, "spacing": 4}})
    emit({"section": {"title": "Network traffic" + (" · " + state["iface"] if state["iface"] else ""), "symbol": "arrow.up.arrow.down", "rows": [
        {"id": "down", "symbol": "arrow.down", "title": "Down", "trailing": rate(down), "graph": normalise(state["down"]), "tint": "cyan"},
        {"id": "up", "symbol": "arrow.up", "title": "Up", "trailing": rate(up), "graph": normalise(state["up"]), "tint": "orange"},
    ]}})

def handle(event):
    kind = event.get("event")
    if kind in ("start", "settings"):
        values = event.get("settings") or {}
        settings["interface"] = str(values.get("interface", "") or "")
        try: settings["rateAbove"] = float(values.get("rateAbove", 50) or 0)
        except (TypeError, ValueError): pass
        state["last"] = None
        counters() and sample()
        publish(0.0, 0.0)
    elif kind == "stop":
        os._exit(0)

def listen():
    for line in sys.stdin:
        try:
            handle(json.loads(line))
        except ValueError:
            continue
        except Exception as error:
            log(error)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
while True:
    time.sleep(1)
    try:
        rates = sample()
        if rates: publish(*rates)
    except Exception as error:
        log(error)
