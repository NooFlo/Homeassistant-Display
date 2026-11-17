# Installation

## 1. Jailbreak the Kindle first

Out of scope here — follow the [KindleModding wiki](https://kindlemodding.org/)
for your exact model and firmware. Critical points:

- Jailbreak **before** the device auto-updates; put it in airplane mode
  immediately if the firmware is still old enough.
- Install **KUAL**, **MRPI**, and **USBNetwork** (SSH over WiFi).

Model-specific values, per-generation differences (init system, browser
launch, non-touch models) and a generic install procedure for any model
are in **[MODELS.md](MODELS.md)**. Defaults target a Paperwhite 1:

| Setting | Where | Default |
|---|---|---|
| Panel resolution | `kindle-ui/html/config.js` `panelW/panelH` | 758×1024 |
| Touch device | `kindle/kiosk.env` `TOUCH` | `/dev/input/event0` |
| Wake RTC | `kindle/kiosk.env` `RTC` | `/sys/class/rtc/rtc1` |

List `/dev/input/` and `/sys/class/rtc/` over SSH to confirm.

## 2. Server side (any Docker host on the LAN)

```sh
git clone <this repo> && cd Homeassistant-Display
cp .env.example .env
# edit .env: HA_URL and a long-lived access token from HA
docker compose up -d
```

Sanity check from a desktop browser:

- `http://<server-ip>:8124` shows the dashboard
- `http://<server-ip>:8124/api/states/sun.sun` returns JSON (token proxy works)

Note: nginx reads the env template at startup — restart the container
after any `.env` change.

## 3. Home Assistant side

- Create a **long-lived access token** (profile → Security) and put it in
  `.env` as `KINDLE_HA_TOKEN`.
- Merge `homeassistant/configuration-snippet.yaml` (the
  `input_boolean.kindle_wake` helper) into your configuration.
- Merge `homeassistant/automation-presence-wake.yaml` into your
  automations and adapt the presence triggers to your setup.
- Restart HA.

## 4. Kindle side

Edit `kindle/kiosk.env` (`SERVER_IP` at minimum), then:

```sh
KINDLE_IP=192.168.1.50 bash scripts/install-kindle.sh
```

The script pushes the kiosk files and KUAL extension to `/mnt/us`,
installs the upstart jobs, and reboots the device. After a couple of
minutes it boots straight into the dashboard.

## Daily use

| You see | It means | Do |
|---|---|---|
| Dashboard, clock ticking | Live and interactive | Tap anything |
| Padlock, "ASLEEP" | Frozen image, device suspended | Press the **power button** |
| Want it asleep now | — | Let it idle, or wait for presence to go off |
| Keep it awake (charging/maintenance) | — | KUAL → KindleKiosk → Toggle Sleep Engine |

The battery level appears in HA as `sensor.kindle_battery` — a good hook
for a low-battery notification automation.

## Escape hatches

- `ssh root@<kindle> touch /mnt/us/DISABLE_SLEEP` — sleep engine off
  (device stays awake; remove the file to re-enable).
- KUAL → KindleKiosk → Stop Kiosk — return to the stock UI.
  Remove `/mnt/us/DISABLE_KIOSK` and use Start Kiosk to resume.

## Troubleshooting

See **[MODELS.md](MODELS.md)** for model-specific gotchas (WiFi quirks,
battery reporting, Oasis rotation, Scribe sizing).

- **Controls do nothing** — token proxy. Check `docker logs kindle-ui`
  for 401s; restart the container after `.env` changes.
- **Kindle can't see WiFi** — channel 12/13, or WPA3/PMF on the AP.
- **Unreachable while suspended** — expected; WiFi is fully off.
- **Wake shows a stale clock** — the frozen image predates the wake;
  the app refreshes within seconds of resume.
