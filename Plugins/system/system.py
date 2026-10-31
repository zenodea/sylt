#!/usr/bin/env python3
import ctypes, ctypes.util, json, os, re, subprocess, sys, threading, time

SAMPLES = 24
METRICS = ("cpu", "memory", "gpu")
TITLE = {"cpu": "CPU", "memory": "Memory", "gpu": "GPU"}
TINT = {"cpu": "cyan", "memory": "purple", "gpu": "green"}
SYMBOL = {"cpu": "cpu", "memory": "memorychip", "gpu": "gamecontroller"}
lock = threading.Lock()
settings = {"wing": "cpu", "percent": True}
series = {name: [0.0] * SAMPLES for name in METRICS}
memory_text = ""

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def log(text):
    emit({"log": text})

def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""

libc = ctypes.CDLL(ctypes.util.find_library("c"))
libc.mach_host_self.restype = ctypes.c_uint32

HOST_CPU_LOAD_INFO = 3
TOTAL_MEMORY = int(run(["/usr/sbin/sysctl", "-n", "hw.memsize"]).strip() or 0)

class CPUTicks(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint32) for name in ("user", "system", "idle", "nice")]

last_ticks = None

def cpu():
    global last_ticks
    info, count = CPUTicks(), ctypes.c_uint32(len(CPUTicks._fields_))
    if libc.host_statistics(libc.mach_host_self(), HOST_CPU_LOAD_INFO, ctypes.byref(info), ctypes.byref(count)) != 0: return None
    ticks = (info.user + info.system + info.nice, info.idle)
    previous, last_ticks = last_ticks, ticks
    if previous is None: return None
    busy, idle = ticks[0] - previous[0], ticks[1] - previous[1]
    return busy / (busy + idle) if busy + idle else None

def memory():
    global memory_text
    if not TOTAL_MEMORY: return None
    out = run(["/usr/bin/vm_stat"])
    match = re.search(r"page size of (\d+)", out)
    page = int(match.group(1)) if match else 16384
    pages = {}
    for line in out.splitlines():
        key, _, value = line.partition(":")
        value = value.strip(" .")
        if value.isdigit(): pages[key.strip()] = int(value)
    used = (pages.get("Pages active", 0) + pages.get("Pages wired down", 0) + pages.get("Pages occupied by compressor", 0)) * page
    memory_text = "%.1f of %.0f GB" % (used / 1e9, TOTAL_MEMORY / 1e9)
    return used / TOTAL_MEMORY

def gpu():
    match = re.search(r'"Device Utilization %"=(\d+)', run(["/usr/sbin/ioreg", "-r", "-d", "1", "-c", "IOAccelerator"]))
    return int(match.group(1)) / 100 if match else None

def sample():
    for name, read in zip(METRICS, (cpu, memory, gpu)):
        value = read()
        if value is not None:
            series[name] = series[name][1:] + [max(0.0, min(1.0, value))]

def graph(name):
    return [round(v, 3) for v in series[name]]

def percent(name):
    return "%d%%" % round(series[name][-1] * 100)

def publish():
    items = []
    for name in METRICS:
        if settings["wing"] not in (name, "all"): continue
        items.append({"graph": graph(name), "tint": TINT[name]})
        if settings["percent"]: items.append({"text": percent(name)})
    emit({"wing": {"side": "right", "items": items, "spacing": 4}})
    rows = [{"id": name, "symbol": SYMBOL[name], "title": TITLE[name], "detail": memory_text if name == "memory" else None,
             "trailing": percent(name), "graph": graph(name), "tint": TINT[name]} for name in METRICS]
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
    try:
        sample()
        publish()
    except Exception as error:
        log("sample failed: %s" % error)
    time.sleep(2)
