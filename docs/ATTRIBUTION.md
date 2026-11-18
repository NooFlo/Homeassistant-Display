# Attribution

This project is a composite of patterns from the open-source Kindle
dashboard ecosystem. Nothing here was possible without the Kindle
modding community (jailbreaks, KUAL, MRPI, USBNetwork — see the
[KindleModding wiki](https://kindlemodding.org/) and
[MobileRead forums](https://www.mobileread.com/forums/forumdisplay.php?f=150)).

Direct inspirations and derived patterns:

- **[higoorc/kindle-dash](https://github.com/higoorc/kindle-dash)** (MIT) —
  the overall architecture: stock-browser SPA, nginx token-injection
  proxy, upstart kiosk + sleep cycle, battery push via `nc`,
  no-cache headers, escape-hatch flag files. The sleep engine and
  proxy are derived from this project's patterns.
- **[cryptomilk/hass-eink-dashboard](https://github.com/cryptomilk/hass-eink-dashboard)** —
  e-ink image optimization concepts (dithering, conditional refresh)
  and unauthenticated LAN endpoints for TLS-incapable Kindles.
- **[sibbl/hass-lovelace-kindle-screensaver](https://github.com/sibbl/hass-lovelace-kindle-screensaver)**
  and **[sibbl/hass-kindle-screensaver](https://github.com/sibbl/hass-kindle-screensaver)** —
  popularized the server-rendered PNG + screensaver approach and the
  battery-entity reporting pattern.
- **[cdmckay/kindle-voyage-weather](https://github.com/cdmckay/kindle-voyage-weather)** (MIT) —
  documented the power cycle in detail: `lab126_gui` handling,
  `lipc-set-prop` screensaver suppression, RTC wake alarms,
  suspend via `/sys/power/state`.
- **[justinledwards/ferrink-home-assistant](https://github.com/justinledwards/ferrink-home-assistant)** —
  the native Rust/Slint alternative; informed the architecture
  comparison (see docs/ARCHITECTURE.md).
- **[chimayBleue29470/kindle-monitoring](https://github.com/chimayBleue29470/kindle-monitoring)** —
  e-ink refresh management (partial vs. full refresh, ghosting).
- **[NiLuJe/FBInk](https://github.com/NiLuJe/FBInk)** — the framebuffer
  ink library used across the ecosystem (not currently a runtime
  dependency of this browser-based variant, but the reference for any
  future native renderer).
- **[mpetroff's Kindle Weather Display](https://mpetroff.net/2012/09/kindle-weather-display/)** —
  the original Kindle e-ink dashboard hack.

Weather data: [Open-Meteo](https://open-meteo.com/).
