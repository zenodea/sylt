#!/usr/bin/env python3
"""Buttons for Ghostty: its quick terminal through the keybind in your config, or a new window."""
import json, os, re, subprocess, sys, threading

BUNDLE = "com.mitchellh.ghostty"
lock = threading.Lock()
settings = {"badge": False}

def emit(message):
    with lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()

def config_paths():
    return [os.path.expanduser("~/.config/ghostty/config"),
            os.path.expanduser("~/Library/Application Support/com.mitchellh.ghostty/config")]

def quick_keybind():
    """The global keybind for toggle_quick_terminal, as (modifiers, key), if there is one."""
    for path in config_paths():
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except OSError:
            continue
        for line in lines:
            match = re.match(r"\s*keybind\s*=\s*(?:global:)?(.+?)=toggle_quick_terminal\s*$", line)
            if match:
                parts = match.group(1).split("+")
                return parts[:-1], parts[-1]
    return None

KEY_CODES = {"grave_accent": 50, "space": 49, "enter": 36, "return": 36, "escape": 53, "tab": 48,
             "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
             "f10": 109, "f11": 103, "f12": 111, "backquote": 50, "semicolon": 41, "quote": 39,
             "left_bracket": 33, "right_bracket": 30, "backslash": 42, "comma": 43, "period": 47, "slash": 44}
MODIFIERS = {"cmd": "command", "super": "command", "command": "command", "ctrl": "control", "control": "control",
             "alt": "option", "opt": "option", "option": "option", "shift": "shift"}

def press(modifiers, key):
    using = ", ".join("%s down" % MODIFIERS[m.lower()] for m in modifiers if m.lower() in MODIFIERS)
    using = " using {%s}" % using if using else ""
    if key.lower() in KEY_CODES:
        action = "key code %d%s" % (KEY_CODES[key.lower()], using)
    else:
        action = 'keystroke "%s"%s' % (key.replace('"', ''), using)
    subprocess.run(["/usr/bin/osascript", "-e", 'tell application "System Events" to %s' % action], capture_output=True, timeout=5)

def quick_terminal():
    bind = quick_keybind()
    if bind:
        press(*bind)
    else:
        subprocess.run(["/usr/bin/open", "-na", "Ghostty"], capture_output=True, timeout=5)

def publish():
    emit({"wing": {"side": "right", "items": [{"symbol": "terminal"}] if settings["badge"] else []}})
    detail = "Through your keybind" if quick_keybind() else "Add keybind = global:cmd+grave_accent=toggle_quick_terminal to use the quick terminal"
    emit({"section": {"rows": [{"id": "quick", "symbol": "terminal", "title": "Quick terminal", "detail": detail}],
                      "buttons": [{"id": "window", "title": "New window"}]}})

def listen():
    for line in sys.stdin:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("event")
        if kind in ("start", "settings"):
            settings["badge"] = bool((event.get("settings") or {}).get("badge", False))
            publish()
        elif kind == "click":
            quick_terminal()
        elif kind == "button":
            subprocess.run(["/usr/bin/open", "-na", "Ghostty"], capture_output=True, timeout=5)
        elif kind == "stop":
            os._exit(0)
    os._exit(0)  # the host went away

threading.Thread(target=listen, daemon=True).start()
threading.Event().wait()
