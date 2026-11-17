# Architecture

```
┌────────────────────┐            ┌──────────────────────────────┐
│  Kindle (jailbroken)│           │  Server (any Docker host)     │
│                    │            │                              │
│  stock browser ────┼── HTTP ───▶│  kindle-ui (nginx :8124)     │
│   └ index.html SPA │            │   ├ serves the web app       │
│                    │            │   ├ /api/* ──▶ Home Assistant│
│  upstart jobs:     │            │   │  (adds Authorization)     │
│   ├ kiosk.conf     │            │   └ /weather/* ─▶ Open-Meteo │
│   ├ kiosk-sleep.conf│           │                              │
│   └ wifi-keepalive │            │  Home Assistant (:8123)      │
│                    │            │   ├ input_boolean.kindle_wake│
│  KUAL: KindleKiosk │            │   └ sensor.kindle_battery    │
└────────────────────┘            └──────────────────────────────┘
```

## Components

**The web app** (`kindle-ui/html/`) — a single-file ES5 app for the
2012-era WebKit (XMLHttpRequest, table layouts, `-webkit-` transforms).
Portrait panel is rotated 90° with a CSS transform for a landscape
dashboard. Reads entity states and calls services through the proxy.
All user configuration lives in `config.js`.

**The nginx proxy** (`server/nginx.conf.template`) — three jobs:
security (the HA token is attached server-side and never reaches the
device), TLS termination (old browsers cannot negotiate modern TLS),
and cache suppression (the stock browser reuses stale page snapshots).

**The sleep engine** (`kindle/bin/kiosk-sleep.sh`) — state machine:

- **ACTIVE**: touch events reset the idle timer.
- **LIGHT SLEEP**: presence (`input_boolean.kindle_wake`) is on — the
  device stays awake-but-idle, polling the boolean every `POLL`
  seconds. A fresh on-transition reloads the dashboard, making it
  touch-interactive within seconds of someone arriving home. This is
  the battery cost you only pay while someone is there.
- **DEEP SLEEP**: no presence and idle for `IDLE` seconds — RTC alarm
  armed for `ALARM` seconds out, SoC suspended via
  `/sys/power/state`, e-ink holds the last image at zero power. Wakes
  on power button or RTC alarm.

Battery level is pushed to HA as `sensor.kindle_battery` on every
sleep/wake cycle and periodically while awake.

## Why light sleep instead of full suspend while present

In suspend-to-RAM the WiFi chip, SoC and touch controller are all off —
nothing on the LAN can reach the device. The only stock wake sources are
the power button and the RTC alarm. Light sleep (idle, WiFi associated,
polling) is the only pure-software way to get presence-driven wake;
the polling pattern is the same one kindle-dash uses for its
force-sleep boolean, inverted.

## Alternatives considered

- **USB smart-plug wake**: Kindles wake when USB power appears; an
  HA-triggered smart plug can act as a wake hammer. Works with deep
  sleep but needs a plug that fully cuts power. Not implemented; the
  light-sleep pattern covers the same use case in software.
- **Static PNG rendering** (cryptomilk/hass-eink-dashboard,
  hass-lovelace-kindle-screensaver): best battery, but no touch
  interaction. The web-app approach was chosen because touch is a
  requirement; the UI root is swappable if a static mode is wanted
  later.
- **Native Rust/Slint app** (ferrink-home-assistant): fastest and
  cleanest, but entity sets are hard-coded and the toolchain is
  heavier. The stock-browser approach keeps the UI hot-swappable
  (plain static files) which fits the figcraft-based UI plan.
