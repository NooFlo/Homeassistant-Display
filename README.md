# Homeassistant-Display

Turn a jailbroken Kindle into a wall-mountable, battery-friendly,
**touch-interactive** e-ink dashboard for [Home Assistant](https://www.home-assistant.io/).

Old Kindles make surprisingly good smart-home panels: the e-ink screen is
readable in any light, and because e-ink holds an image at zero power the
device can spend most of its life asleep and still *look* on.

## What this gives you

- **Interactive dashboard** in the Kindle's stock browser: rooms with
  lights, climate, locks and read-only sensors, weather, a clock and a
  battery indicator — e-ink styled (pure black on white, big touch
  targets), configurable entirely from `kindle-ui/html/config.js`.
- **Presence-driven wake**: while someone is home the device stays in
  light sleep and polls a Home Assistant boolean
  (`input_boolean.kindle_wake`). A presence automation that flips it on
  makes the dashboard live and touch-interactive within seconds —
  without touching the Kindle.
- **Deep sleep when nobody's around**: after idle time without
  presence the SoC suspends with an RTC wake alarm armed; the e-ink
  keeps showing the last image at zero power. Weeks of battery life.
- **Battery reporting** into HA as `sensor.kindle_battery`.
- **No credentials on the device**: an nginx proxy injects the HA token
  server-side; the Kindle only ever speaks plain HTTP on the LAN
  (old browsers cannot negotiate modern TLS).
- **Swappable UI**: the dashboard is plain static files with a small
  contract (see `docs/UI.md`) — a UI built with figcraft or anything
  else can replace the reference shell without touching device scripts.

## Quick start

```sh
cp .env.example .env          # set HA_URL and a HA long-lived token
docker compose up -d         # dashboard on http://<server>:8124
KINDLE_IP=192.168.1.50 bash scripts/install-kindle.sh
```

Requires a jailbroken Kindle with KUAL + USBNetwork (SSH). Full guide:
**[docs/INSTALL.md](docs/INSTALL.md)**.

## Repository layout

| Path | What it is |
|---|---|
| `kindle-ui/html/` | Dashboard web app (ES5, single file + `config.js`) |
| `server/` | nginx token-proxy template |
| `kindle/` | On-device files: sleep engine, upstart jobs, KUAL extension |
| `homeassistant/` | HA config snippet + presence-wake automation example |
| `scripts/` | Kindle installer |
| `docs/` | Install guide, architecture, UI contract, UI design prompt, attribution |

## How it works

The three pillars — interactive web app, token proxy, and the
sleep/wake state machine — are documented in
**[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**, including why
presence-wake requires light sleep rather than full suspend (the WiFi
chip and touch controller are unpowered in suspend-to-RAM; nothing on
the LAN can reach the device).

## Credits

A composite of patterns from the open-source Kindle dashboard
ecosystem — kindle-dash, hass-eink-dashboard, kindle-voyage-weather and
others. See **[docs/ATTRIBUTION.md](docs/ATTRIBUTION.md)**.

## License

MIT
