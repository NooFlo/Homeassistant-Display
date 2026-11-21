# Native mode: framework-less kiosk ("TRMNL with a touchscreen")

Native mode replaces the Amazon GUI on the e-ink screen with our own
render loop while keeping the parts of the firmware that matter
(`powerd`, `wifid`, `appmgrd` for battery, WiFi and suspend plumbing).
This is the recommended mode on the Paperwhite 11 (EY21) — see
[EY21.md](EY21.md) for its install guide.

## Architecture

```
┌─────────────── Home Assistant ───────────────┐
│  entity state  ◀── service calls (POST)       │
└──────┬───────────────────▲───────────────────┘
       │ REST (token)      │
┌──────▼───────────────────┴───────────────────┐
│  kindle-renderer (Docker)                    │
│   HA state → PNG + TSV region map, every 30s │
└──────┬───────────────────▲───────────────────┘
       │ HTTP (no-store)   │ POST /api/services/*
┌──────▼───────────────────┴───────────────────┐
│  Kindle: kiosk-native.sh + wait_tap + FBInk  │
│   fetch → paint → wait tap → POST → refresh   │
│   idle → presence poll / RTC deep sleep       │
└──────────────────────────────────────────────┘
```

The key design decision: **all UI lives on the server**. The renderer
(`renderer/renderer.py`) produces two artifacts:

- `generated/dashboard.png` — the dashboard image, painted by FBInk
- `generated/dashboard.map` — a TSV binding each tappable rectangle to
  a Home Assistant service call:

  ```
  x  y  w  h  domain  service  entity_id  payload-json-fragment
  ```

The on-device loop is deliberately dumb: paint the PNG, decode a tap,
look up the region, POST its service call, re-fetch. Changing the
dashboard — layout, entities, styling — changes only the renderer. This
is what keeps the figcraft-designed UI in the pipeline: a figcraft
build renders to PNG and emits an equivalent map; the Kindle side never
changes.

## Components

| File | Role |
|---|---|
| `renderer/renderer.py` | HA state → PNG + map (Pillow). All UI logic lives here. |
| `renderer/config.json` | The rendered dashboard: entities, panel size. |
| `kindle/native/bin/kiosk-native.sh` | The engine: fetch, paint, tap→service, presence light sleep, RTC deep sleep, battery push. |
| `kindle/native/src/wait_tap.c` | Evdev decoder: prints the next tap's X Y (multi-touch and single-touch panels). |
| `kindle/native/Makefile` | Cross-build via `zig cc` → static armv7 musl binary. |
| `kindle/native/kual/KindleNative/` | KUAL entries: start (stops `lab126_gui`, restores on exit) / stop. |

## Building and installing

```sh
make -C kindle/native                        # builds kindle/native/bin/wait_tap
KINDLE_IP=<ip> KUAL_ONLY=1 bash scripts/install-kindle.sh
```

FBInk must be installed on the device (KUAL extension provides the
binary; set `FBINK_BIN` in `kindle/kiosk.env` otherwise). Start it via
**KUAL → KindleNative → Start Native Kiosk**.

## Safety model

- No boot, rootfs or firmware changes — everything is in `/mnt/us`.
- `lab126_gui` is **frozen** (`SIGSTOP`), not killed: no watchdog
  restarts of the GUI while the native loop owns the screen, and
  `Stop Native Kiosk` simply continues it.
- `powerd` keeps running, which is why suspend, RTC wake, battery
  reads and the screensaver suppression (`lipc`) all still work.
- Escape hatches: `touch /mnt/us/DISABLE_SLEEP` (stay awake while
  debugging), Stop Native Kiosk (reader back), one `rm -rf` to
  uninstall.

## Known limitations / TODO

- Taps wake the loop only while awake — the touch controller is
  unpowered in suspend; wake is power button / presence / RTC only
  (same physics as the browser mode).
- Raw evdev coordinates are assumed to match framebuffer coordinates
  (true on single-orientation E Ink panels). A calibration step can be
  added if a model needs it.
- The reference renderer is a compact Pillow layout; the figcraft UI
  replaces `render()` while keeping the PNG + map outputs.
