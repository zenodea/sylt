#!/usr/bin/env python3
"""Temperature in the right wing, conditions and the day's range when expanded."""
import json, sys, urllib.request

SYMBOLS = {0: "sun.max.fill", 1: "cloud.sun.fill", 2: "cloud.sun.fill", 3: "cloud.fill", 45: "cloud.fog.fill", 48: "cloud.fog.fill"}
SUMMARY = {0: "Clear", 1: "Partly cloudy", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Fog"}

def describe(code):
    if code in SYMBOLS: return SYMBOLS[code], SUMMARY[code]
    if 51 <= code <= 57: return "cloud.drizzle.fill", "Drizzle"
    if 61 <= code <= 67 or 80 <= code <= 82: return "cloud.rain.fill", "Rain"
    if 71 <= code <= 77 or code in (85, 86): return "cloud.snow.fill", "Snow"
    if 95 <= code <= 99: return "cloud.bolt.rain.fill", "Thunderstorm"
    return "cloud.fill", "Cloudy"

def emit(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()

def fetch(url):
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.load(response)

start = json.loads(sys.stdin.readline() or "{}")
units = (start.get("settings") or {}).get("units", "celsius")
try:
    place = fetch("https://ipinfo.io/json")
    lat, lon = place["loc"].split(",")
    forecast = fetch(
        "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,weather_code"
        "&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1&temperature_unit=%s" % (lat, lon, units)
    )
except Exception:
    sys.exit(0)

current = forecast["current"]
symbol, summary = describe(int(current["weather_code"]))
temperature = round(current["temperature_2m"])
high = round(forecast["daily"]["temperature_2m_max"][0])
low = round(forecast["daily"]["temperature_2m_min"][0])
emit({"wing": {"side": "right", "items": [{"symbol": symbol, "text": "%d°" % temperature}]}})
emit({"section": {"rows": [{
    "id": "weather", "symbol": symbol, "title": "%d°  %s" % (temperature, summary),
    "detail": place.get("city", ""), "trailing": "H %d°  L %d°" % (high, low),
}]}})
