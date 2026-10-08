# Sylt

A dynamic island for the MacBook notch. It turns the dead space at the top of the screen into a small, quiet display for the things you glance at: what's playing, your coding agents, the next meeting, a timer, volume and brightness, battery, Bluetooth, network, and more. It lives above every window, full-screen apps included, and it stays on the lock screen.

Website: https://zenodea.github.io/sylt/

## What it does

**Closed** the island hugs the notch and shows only live state in two wings:

- Left: running agents (working first, idle faded), a countdown to the next meeting, a running timer, AeroSpace workspaces with the current one bright, open reminders.
- Right: mic and camera dots, the active Focus, headphone charge, the weather, Slack's unread count, the time, album art with live audio bars.

Each wing is sized to its own content. An empty side adds nothing.

**Overlays** grow out of the notch for a moment and fade back. A one-sided overlay never touches the other wing:

| Overlay | Shows |
| --- | --- |
| Volume, brightness, mute | Icon and level bar on the right only. Mute draws a slash through the speaker. Brightness only for changes made through the keys or the island, never for auto-brightness. |
| Track change | The wings stay put, the new cover flips in, a title row slides out underneath. |
| Battery | Percent and a message at 80, 60, 40, 20, 15, 10, 5 and 0 percent, and on charger changes. |
| Bluetooth | A rune that draws itself in on connect, the device name and a gauge filled to its exact charge. Low-battery warnings at 20 and 10 percent. |
| Network | Wi-Fi arcs lighting up, a cable clicking in, or a slashed Wi-Fi when you go offline. |
| Calendar | The next event five minutes before it starts and again at start. |
| Keyboard | Caps Lock on or off, keyboard layout changes. |
| Focus | The Focus mode you switched to. |
| Mic and camera | When either starts or stops being used. |
| Thermals | When the Mac gets hot enough to throttle, and when it cools. |
| Notifications | Notification Center banners mirrored as a card. Experimental. |
| Unlock | A padlock that springs open with a greeting when you unlock. |
| Plugins | Whatever a plugin asks for: a timer ending, a download landing, an agent finishing. |

**Expanded** (click or swipe down) shows what's relevant, two sections to a page. Swipe sideways to turn the page; the Layout pane in Settings decides which sections share a page.

- Media card with artwork, transport, a seek bar, the source app and an output volume slider with the device name.
- Next event with a Join button for Zoom, Meet, Teams and Webex links.
- Every plugin's section: timer presets, agents waiting first with how long they've waited, the file shelf, clipboard history, the weather, AeroSpace workspaces with their apps.

**Locked** the island shows a padlock and the time, and stays visible over the login window.

**Layout** is yours to arrange. Settings has a Layout pane with the island drawn at the top and three columns under it: left wing, right wing, hidden. Drag any built-in badge or plugin between them, or onto another tile to set the order, and the island above follows. Anything you don't touch keeps its default place.

**The pointer** is taken in when it enters the island: it disappears, and moving the mouse leans the island instead. A firm push in one direction lets it out through the rim on that side, and it keeps moving in the same motion. Settings has an Effects pane for all of it:

- Hold it until pushed, and how hard the push has to be. Off, the pointer dips in and comes straight back out with the next movement.
- A glow on the rim where the pointer would come out, growing with the push.
- What happens when it leaves: a ripple running around the rim from that point, a ring of light, a reflection sweeping across the island as if it were dark glass, or nothing. The ripple's strength is adjustable.
- A haptic tap on release.

The pointer is kept off the top edge of the screen while held, so the menu bar stays put.

## Install

Requires macOS 14 or later on a Mac with a notch. Build from source:

```sh
git clone https://github.com/zenodea/sylt.git
cd sylt
make open
```

`make open` builds a release binary, wraps it in `build/Sylt.app` and launches it. Settings are in the island's context menu. Turn on "Open at login" there.

### Permissions

Each is asked for the first time its plugin needs it, and each plugin can be switched off in Settings:

- Accessibility: to take over the volume and brightness keys, to mirror notifications, and to raise an agent's terminal window.
- Calendar: for the next event.
- Bluetooth: for device connections and battery.
- Automation (Spotify, Music): for artwork and transport.

## How it works

- The island is a transparent panel over the notch, drawn with SwiftUI. It is moved into its own WindowServer space pinned at the lock-screen level through the private SkyLight framework, which is what keeps it above full-screen apps and the login window.
- The panel only takes the mouse while the cursor is over the island, so the rest of the strip stays click-through.
- Built-in sources are Swift `Monitor`s with a `HUDKind` for their overlay. Everything else is a plugin: a program in any language that prints JSON, rendered by the island with the same badges, overlays and sections. Fifteen ship in the app: weather, downloads, timer, clipboard, file shelf, agents, AeroSpace workspaces, Slack, a clock, todos from Reminders, a Ghostty quick terminal, Tailscale, Mullvad VPN, network traffic and system load.
- MediaRemote withholds metadata from third-party apps on recent macOS, so now-playing data comes from a small adapter hosted in Apple's own `perl`, with AppleScript for Spotify and Music and a session-store lookup for Firefox.

## Writing a plugin

A plugin is a folder with a `plugin.json` and a program. Drop it in `~/Library/Application Support/Sylt/Plugins` and it starts; Settings has a button for the folder. The fifteen shipped plugins in `Plugins/` are the reference.

```json
{
  "protocol": 1,
  "id": "coffee",
  "name": "Coffee",
  "description": "Cups so far today.",
  "symbol": "cup.and.saucer.fill",
  "run": "coffee.sh",
  "settings": [{ "key": "goal", "title": "Daily goal", "type": "number", "default": 3 }]
}
```

The program prints one JSON object per line. Each line replaces one thing:

```sh
#!/bin/sh
read start                               # {"event":"start","settings":{...},"dataDir":"..."}
echo '{"wing": {"side": "right", "items": [{"symbol": "cup.and.saucer.fill", "text": "2"}]}}'
echo '{"hud": {"symbol": "cup.and.saucer.fill", "tint": "orange", "text": "Coffee logged"}}'
echo '{"section": {"title": "Coffee", "rows": [{"id": "log", "title": "Log a cup"}], "buttons": [{"id": "reset", "title": "Reset"}]}}'
while read event; do                     # {"event":"click","row":"log"} {"event":"button","id":"reset"} ...
  case "$event" in *'"click"'*) echo '{"wing": {"side": "right", "items": [{"symbol": "cup.and.saucer.fill", "text": "3"}]}}';; esac
done
```

What a plugin can print:

| Line | Effect |
| --- | --- |
| `{"wing": {"side": "left" or "right", "items": [...]}}` | Replaces the plugin's badge in that wing. An item mixes `symbol`, `image` (`app:bundle.id`, `icon:/path`, `file:/path`), `text`, `tint`, `dot`, `ring` (0 to 1), `graph` (a list of values from 0 to 1, drawn as a small bar graph) and `status` (`working` or `waiting`). Empty items clear it. |
| `{"hud": {...}}` | Shows an overlay now: `symbol`/`image`, `tint`, `text` or `level` (0 to 1), `side` (`both`, `left`, `right`), `duration`, `sound`, and a `trailingSymbol` with `trailingTint` that pops in after the text. |
| `{"section": {...}}` | Replaces the plugin's expanded section: `title`, `symbol`, `rows`, `files` (paths, draggable), `buttons`, `actions`. A row has `id`, `symbol`/`image`, `title`, `detail`, `trailing`, `trailingTint`, `status`, `progress`, `buttons`, `highlighted`, `large`, and `graph` with `tint` for a wider graph on the right. A wing can set `spacing` between its items. |
| `{"clearSection": true}` | Removes the section. |
| `{"sound": "Hero"}` | Plays a system sound. |
| `{"activate": {"process": "herdr", "window": "title"}}` | Brings an app forward, by process name, `pid` or `bundle`, and raises the window whose title contains `window`. |
| `{"open": "/path or https://..."}` | Opens a file or URL. |

What the host writes to the plugin's stdin: `start` with `settings` and `dataDir`, `settings` when they change, `click` with a row `id`, `button` with an `id` (and its row), `action` with an `id`, `drop` with `files` when the manifest has `"accepts": ["files"]`, `clipboard` with `text` on every copy when it has `"accepts": ["clipboard"]` (password managers are skipped for you), `remove` with a file path, and `stop`.

Manifests can set `"interval": seconds` to be run once per interval instead of staying running, `"accepts": ["files"]` to receive drops, `"side": "left"` for the wing the badge takes until the user moves it, `"enabledByDefault": false`, and `settings` of type `bool`, `text`, `number` or `choice` (with `options`), which Settings turns into a form. Tints are `white`, `dim`, `green`, `orange`, `red`, `yellow`, `blue`, `indigo`, `purple`, `pink`, `cyan` or a `#hex`.

Plugins run as you, with your permissions. Scripts without an executable bit run through the interpreter their extension implies: `.py`, `.sh`, `.rb`, `.js`, `.swift`.

## Development

```sh
make build   # debug build
make test    # unit tests
make open    # release bundle, relaunch
```

Sources are grouped by concern under `Sources/Sylt`: `Island` (state, layout, modes, animation), `Monitors` (one folder per domain), `Plugins` (the protocol, process host and registry), `Views` (wings, overlays, expanded sections, badges, plugin renderers), `Settings` and `System`. Shipped plugins live in `Plugins/`, tests in `Tests/SyltTests`. Run a debug build against the repo's plugins with `ISLAND_PLUGINS=Plugins .build/debug/Sylt`.

Private APIs can change between macOS releases. The SkyLight calls and the Focus store are the two places most likely to need attention after an update.
