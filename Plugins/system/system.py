#!/usr/bin/env python3
"""System load: CPU from top, memory from vm_stat, GPU from the accelerator's own counter, as sparklines."""
import json, os, re, subprocess, sys, threading, time

SAMPLES = 24
lock = threading.Lock()
settings = {"wing": "cpu", "percent": True}
series = {"cpu": [0.0] * SAMPLES, "memory": [0.0] * SAMPLES, "gpu": [0.0] * SAMPLES}
memory_text = ""
TINT = {"cpu": "cyan", "memory": "purple", "gpu": "green"}
SYMBOL = {"cpu": "cpu", "memory": "memorychip", "gpu": "gamecontroller"}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": "system: %s" % text})

def run(args, timeout=5):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""

def cpu():
    match = re.findall(r"CPU usage: ([\d.]+)% user, ([\d.]+)% sys", run(["/usr/bin/top", "-l", "2", "-n", "0", "-s", "1"], timeout=8))
    return (float(match[-1][0]) + float(match[-1][1])) / 100 if match else None

def memory():
    global memory_text
    out = run(["/usr/bin/vm_stat"])
    page = int(re.search(r"page size of (\d+)", out).group(1)) if "page size" in out else 16384
    pages = {k.strip(): int(v.strip(" .")) for k, v in (l.split(":", 1) for l in out.splitlines() if ":" in l and l.split(":", 1)[1].strip(" .").isdigit())}
    total = int(run(["/usr/sbin/sysctl", "-n", "hw.memsize"]).strip() or 0)
    if not total: return None
    used = (pages.get("Pages active", 0) + pages.get("Pages wired down", 0) + pages.get("Pages occupied by compressor", 0)) * page
    memory_text = "%.1f of %.0f GB" % (used / 1e9, total / 1e9)
    return used / total

def gpu():
    match = re.search(r'"Device Utilization %"=(\d+)', run(["/usr/sbin/ioreg", "-r", "-d", "1", "-c", "IOAccelerator"]))
    return int(match.group(1)) / 100 if match else None

def sample():
    for name, read in (("cpu", cpu), ("memory", memory), ("gpu", gpu)):
        value = read()
        if value is not None:
            series[name] = series[name][1:] + [max(0.0, min(1.0, value))]

def publish():
    chosen = [k for k in ("cpu", "memory", "gpu") if settings["wing"] in (k, "all")]
    items = []
    for name in chosen:
        items.append({"graph": [round(v, 3) for v in series[name]], "tint": TINT[name]})
        if settings["percent"]: items.append({"text": "%d%%" % round(series[name][-1] * 100)})
    emit({"wing": {"side": "right", "items": items, "spacing": 4}})
    rows = []
    for name in ("cpu", "memory", "gpu"):
        detail = memory_text if name == "memory" else None
        rows.append({"id": name, "symbol": SYMBOL[name], "title": name.upper() if name != "memory" else "Memory", "detail": detail,
                     "trailing": "%d%%" % round(series[name][-1] * 100), "graph": [round(v, 3) for v in series[name]], "tint": TINT[name]})
    emit({"section": {"rows": rows}})

def handle(event):
    kind = event.get("event")
    if kind in ("start", "settings"):
        values = event.get("settings") or {}
        settings["wing"] = str(values.get("wing", "cpu") or "cpu")
        settings["percent"] = bool(values.get("percent", True))
        publish()
    elif kind == "click":
        emit({"activate": {"bundle": "com.apple.ActivityMonitor"}})
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
    try:
        sample()
        publish()
    except Exception as error:
        log(error)
    time.sleep(2)
