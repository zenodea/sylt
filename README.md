# Control Island

A dynamic island for the MacBook notch. It turns the dead space at the top of the screen into a small, quiet display for the things you glance at: what's playing, your coding agents, the next meeting, a timer, volume and brightness, battery, Bluetooth, network, and more. It lives above every window, full-screen apps included, and it stays on the lock screen.

Website: https://zenodea.github.io/controlisland/

## What it does

**Closed** the island hugs the notch and shows only live state in two wings:

- Left: running agents (working first, idle faded), a countdown to the next meeting, a running timer.
- Right: mic and camera dots, the active Focus, headphone charge, the weather, album art with live audio bars.

Each wing is sized to its own content. An empty side adds nothing.

**Overlays** grow out of the notch for a moment and fade back. A one-sided overlay never touches the other wing:

| Overlay | Shows |
| --- | --- |
| Volume, brightness, mute | Icon and level bar on the right only. Mute draws a slash through the speaker. |
| Track change | The wings stay put, the new cover flips in, a title row slides out underneath. |
| Battery | Percent and a message at 80, 60, 40, 20, 15, 10, 5 and 0 percent, and on charger changes. |
| Bluetooth | A rune that draws itself in on connect, the device name and a gauge filled to its exact charge. Low-battery warnings at 20 and 10 percent. |
| Network | Wi-Fi arcs lighting up, a cable clicking in, or a slashed Wi-Fi when you go offline. |
| Calendar | The next event five minutes before it starts and again at start. |
| Timer | A chime and overlay when a countdown ends. |
| Keyboard | Caps Lock on or off, keyboard layout changes. |
| Focus | The Focus mode you switched to. |
| Mic and camera | When either starts or stops being used. |
| Downloads | A browser download starting and landing. |
| Thermals | When the Mac gets hot enough to throttle, and when it cools. |
| Agents | An agent finishing, with a green tick. |
| Notifications | Notification Center banners mirrored as a card. Experimental. |
| Unlock | A padlock that springs open with a greeting when you unlock. |

**Expanded** (click or swipe down) stacks what's relevant:

- Media card with artwork, transport, a seek bar, the source app and an output volume slider with the device name.
- Next event with a Join button for Zoom, Meet, Teams and Webex links.
- Timer presets: 5, 15, 25 and 60 minutes.
- Agents from Herdr, or found by process when Herdr isn't installed, waiting ones first with how long they've waited. Click one to raise its terminal.
- A file shelf: drop files on the island to hold them, drag them out later.
- Clipboard history, one click to copy again.
- Weather with the day's range.

**Locked** the island shows a padlock and the time, and stays visible over the login window.

## Install

Requires macOS 14 or later on a Mac with a notch. Build from source:

```sh
git clone https://github.com/zenodea/controlisland.git
cd controlisland
make open
```

`make open` builds a release binary, wraps it in `build/ControlIsland.app` and launches it. Settings are in the island's context menu. Turn on "Open at login" there.

### Permissions

Each is asked for the first time its plugin needs it, and each plugin can be switched off in Settings:

- Accessibility: to take over the volume and brightness keys, to mirror notifications, and to raise an agent's terminal window.
- Calendar: for the next event.
- Bluetooth: for device connections and battery.
- Automation (Spotify, Music): for artwork and transport.

## How it works

- The island is a transparent panel over the notch, drawn with SwiftUI. It is moved into its own WindowServer space pinned at the lock-screen level through the private SkyLight framework, which is what keeps it above full-screen apps and the login window.
- The panel only takes the mouse while the cursor is over the island, so the rest of the strip stays click-through.
- Every data source is a plugin: a `Monitor` that publishes changes, a `HUDKind` for its overlay, and views for its wing badge and expanded section. Preferences, Settings and the island state pick them up from `Plugin.allCases`.
- MediaRemote withholds metadata from third-party apps on recent macOS, so now-playing data comes from a small adapter hosted in Apple's own `perl`, with AppleScript for Spotify and Music and a session-store lookup for Firefox.

## Development

```sh
make build   # debug build
make test    # unit tests
make open    # release bundle, relaunch
```

Sources are grouped by concern under `Sources/ControlIsland`: `Island` (state, layout, modes, animation), `Monitors` (one folder per domain), `Views` (wings, overlays, expanded sections, badges), `Settings` and `System`. Tests live in `Tests/ControlIslandTests`.

Private APIs can change between macOS releases. The SkyLight calls and the Focus store are the two places most likely to need attention after an update.
