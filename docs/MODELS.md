# Installing on different Kindles

The kiosk is developed against a **Paperwhite 1** (firmware 5.3.x,
upstart-based). Other models work with the adjustments below. This guide
covers the common jailbroken generations; if your model is not listed, the
generic procedure at the end applies.

Jailbreaking itself is out of scope — always start at the
[KindleModding wiki](https://kindlemodding.org/) for your exact model and
firmware, and check the
[MobileRead Kindle Developer's Corner](https://www.mobileread.com/forums/forumdisplay.php?f=150).
Two universal warnings first:

1. **Jailbreak before the device updates.** Exploits are firmware-version
   specific. Put the Kindle in airplane mode the moment you get it, check
   the firmware version (Settings → Device Options → Device Info), and
   jailbreak *before* it ever sees WiFi.
2. **Everything below assumes SSH access** via USBNetwork (or
   USBNetwork over WiFi). Install it during the jailbreak phase.

---

## Quick reference table

Values marked ▸ must be confirmed on the device (`ls /dev/input/`,
`ls /sys/class/rtc/`) — they vary even within a generation.

| Model (gen) | Resolution (portrait) | Touch device | Wake RTC | Init/browser notes |
|---|---|---|---|---|
| Kindle Touch (K5, 4th gen) | 600×800 | ▸ `/dev/input/event1` | ▸ `rtc0` | Upstart; older browser, same ES5 target |
| Kindle 4 (NT, no touch) | 600×800 | none | ▸ `rtc0` | **No touch — see "Non-touch models"** |
| Kindle 5 / Paperwhite 1 (K5PW, 5th gen) | 758×1024 | ▸ `/dev/input/event0` | ▸ `rtc1` | Reference target; upstart; `mesquite` browser |
| Paperwhite 2 / 3 (6th/7th gen) | 758×1024 | ▸ `/dev/input/event0` | ▸ `rtc1` | Upstart; same browser family |
| Voyage (7th gen) | 1080×1440 | ▸ `/dev/input/event1` | ▸ `rtc1` | Upstart; page-press sensors harmless |
| Oasis 1–3 (8th–10th gen) | 1264×1680 | ▸ `/dev/input/event1` | ▸ `rtc0` | Upstart/transition era; check init below |
| Paperwhite 4 (10th gen) | 1264×1680 | ▸ `/dev/input/event0` | ▸ `rtc1` | Newer firmware — see "5.12+ firmware" |
| Basic Kindle 7/8 (8th/10th gen) | 600×800 / 600×1024 | ▸ `/dev/input/event0` | ▸ `rtc1` | Newer firmware on K8 |
| Paperwhite 5 / Signature (11th gen) | 1236×1648 | ▸ `/dev/input/event0` | ▸ `rtc1` | **5.14+ firmware — see below** |
| Scribe (11th gen) | 1860×2480 | ▸ `/dev/input/event0` | ▸ `rtc1` | Large panel; pen input also works |

## What to change per model

### 1. Panel resolution — `kindle-ui/html/config.js`

Set `panelW`/`panelH` to the portrait resolution from the table. The app
rotates itself 90°, so `panelW` is the *narrow* dimension. Wrong values
give a squashed or clipped dashboard, never a crash — adjust until it
fills the screen edge to edge.

### 2. Device paths — `kindle/kiosk.env`

- `TOUCH`: the touchscreen's `/dev/input/eventN`. Confirm over SSH:

  ```sh
  ls /dev/input/
  # then verify which one is touch (event numbers shuffle per model):
  timeout 3 dd if=/dev/input/event0 bs=64 count=1 >/dev/null && echo "event0 fires"
  ```

  Tap the screen while the `dd` runs; the device that "fires" is touch.
- `RTC`: the wake-capable alarm interface. Check which RTC supports
  `wakealarm`:

  ```sh
  cat /sys/class/rtc/rtc*/device/uevent  # look for the one tied to the SoC
  echo 0 > /sys/class/rtc/rtc1/wakealarm   # must not error
  ```

### 3. Browser launch — `kindle/kiosk.conf` and the KUAL scripts

The reference launch uses:

```sh
lipc-set-prop -i com.lab126.appmgrd start app://web-reader '{"url":"..."}'
```

This is the `mesquite` experimental browser of the PW1–PW3 era. On other
firmwares:

- If `web-reader` does not open anything, check
  `/usr/bin/` and `/var/local/mesquite/browser/` for the browser binary
  and try launching it directly with the URL as an argument.
- On some firmwares the app id differs (`app://com.lab126.browser` or
  similar); `lipc-hash` and the appmgrd logs (`/var/log/messages`) show
  what appmgrd accepted.
- If the browser ignores fullscreen, the reference project's self-heal
  patching of browser config files under `/var/local/mesquite/` is the
  pattern to copy — the exact file differs per firmware generation.

### 4. Init system — the big firmware divide

- **Firmware < 5.12 (PW1–PW3, Touch, K4/K5, Voyage, Oasis 1):** classic
  upstart. Install the `.conf` files to `/etc/upstart/` as
  `scripts/install-kindle.sh` does; they start on the next boot.
  Upstart jobs on these firmwares can only be started by boot events —
  there is no usable `initctl`.
- **Firmware 5.12–5.13 (PW4, Oasis 2/3, K8):** transitional. Check what
  exists on the device: if `/etc/upstart/` is still the init dir, the
  stock procedure works unchanged. If not, install the same scripts as a
  KUAL-triggered launcher instead (see below).
- **Firmware 5.14+ (PW5/Signature, Scribe, 2022+ basics):** modern
  firmware. Upstart may not manage user-visible sessions the same way;
  the reliable path is the **KUAL launcher** (this is what
  `chimayBleue29470/kindle-monitoring` does on a PW5). Skip the upstart
  jobs entirely and wire `kiosk.conf`'s body into a KUAL start menu
  entry: KUAL → KindleKiosk → Start Kiosk runs the browser launch and
  the sleep engine in the background.

### 5. Non-touch models (Kindle 4 and older basics)

The touch-interaction contract is meaningless without a touchscreen.
Options:

- Use the 5-way/keyboard: the app works with `click` events synthesized
  by the cursor; add keyboard handlers if you want native navigation.
- Or convert the project to the **static display** style: run only the
  deep-sleep branch of the engine (drop `TOUCH` polling, set `IDLE=0`)
  and have the dashboard render status-only content. The
  `hass-lovelace-kindle-screensaver` + KUAL Online Screensaver approach
  is the better fit for these devices.

---

## Generic install procedure (any model)

1. Jailbreak per the KindleModding wiki; install **KUAL + MRPI +
   USBNetwork**. Confirm SSH: `ssh root@<kindle-ip>`.
2. Confirm the three model-specific values:
   - touch device (`ls /dev/input/`, tap test)
   - wake RTC (`/sys/class/rtc/rtcN/wakealarm`)
   - panel resolution (table above, or `eips -i` which prints the
     framebuffer geometry)
3. Set `panelW`/`panelH` in `kindle-ui/html/config.js`.
4. Set `SERVER_IP`, `TOUCH`, `RTC` in `kindle/kiosk.env`.
5. Start the server (`docker compose up -d`) and sanity-check
   `http://<server-ip>:8124` from a desktop browser.
6. If your firmware is upstart-based:
   `KINDLE_IP=<ip> bash scripts/install-kindle.sh` — done, it reboots.
7. If not (5.14+): copy the kiosk files manually:

   ```sh
   ssh root@<kindle> mkdir -p /mnt/us/kiosk/bin /mnt/us/extensions/KindleKiosk/bin
   scp kindle/kiosk.env kindle/bin/kiosk-sleep.sh root@<kindle>:/mnt/us/kiosk/
   scp -r kindle/kual/KindleKiosk/* root@<kindle>:/mnt/us/extensions/KindleKiosk/
   ssh root@<kindle> "sed -i 's|/mnt/us/kiosk/kiosk-sleep.sh|/mnt/us/kiosk-sleep.sh|' /mnt/us/extensions/KindleKiosk/bin/start_kiosk.sh; chmod +x /mnt/us/kiosk/*.sh /mnt/us/extensions/KindleKiosk/bin/*.sh"
   ```

   Then use **KUAL → KindleKiosk → Start Kiosk** each boot (or wire it
   into KOReader/KUAL auto-start if your setup supports it).
8. Verify the sleep cycle: leave it idle `IDLE` seconds, confirm the
   ASLEEP view and that the power button wakes it; confirm a presence
   event (`input_boolean.kindle_wake` on) reloads the dashboard.

## Model-specific gotchas

- **PW1**: WiFi drops on channels 12/13 and with WPA3/PMF access
  points. The `wifi-keepalive` job exists for this family.
- **PW2/PW3**: identical to PW1 in practice; some units have touch on
  `event1`.
- **PW4**: first model without physical home button — the "exit kiosk"
  escape is KUAL only (or the gear icon if you add one to the UI).
- **PW5/Scribe**: `gasgauge-info` may report differently; check the
  battery push in the logs (`logger -t kiosk-sleep`) and adapt the
  parsing if the percentage isn't clean.
- **Oasis**: the accelerometer rotates the panel; lock orientation
  with `lipc-set-prop com.lab126.winmgr orientationLock 1` (value per
  orientation) or the dashboard will flip when mounted sideways.
- **Scribe**: the panel is 300 ppi — double all minimum sizes from the
  design prompt (touch targets ≥128 device px) or controls will be
  unusably small.
- **Any model**: if the browser shows an address bar after a firmware
  hiccup, the self-heal re-applies fullscreen on the next boot —
  reboot once.

If you port to an unlisted model, the two things to report back are the
`TOUCH` path and the RTC device — everything else is configuration.
