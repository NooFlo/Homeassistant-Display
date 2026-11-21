#!/usr/bin/env python3
"""Server-side dashboard renderer for the native Kindle kiosk.

Renders Home Assistant entity state to:
  - dashboard.png : a 1-bit-friendly grayscale image of the dashboard
  - dashboard.map : a TSV touch-region map binding screen rectangles
                    to Home Assistant service calls

The native loop on the Kindle (kiosk-native.sh) is UI-agnostic: it
paints the PNG and POSTs whatever service call a tapped region
describes. All UI decisions - layout, styling, which entities, and
what each tappable area does - are made here. A figcraft-built UI
belongs in this pipeline (render to PNG + emit an equivalent map),
not on the device.

Environment:
  HA_URL            e.g. http://homeassistant:8123
  KINDLE_HA_TOKEN   long-lived HA token
  CONFIG            path to config.json     (default: ./config.json)
  OUT_DIR           output directory        (default: /generated)
  RENDER_INTERVAL   seconds between renders (default: 30)

Field order of the .map lines (TSV):
  x, y, w, h, ha-domain, ha-service, entity_id, json-payload-extra
The native side wraps entity_id and the payload fragment into
{"entity_id": ..., <fragment>}.
"""

import json
import os
import time
import urllib.request
from datetime import datetime

from PIL import Image, ImageDraw, ImageFont

HA_URL = os.environ.get("HA_URL", "http://homeassistant:8123")
TOKEN = os.environ.get("KINDLE_HA_TOKEN", "")
CONFIG = os.environ.get("CONFIG", "./config.json")
OUT_DIR = os.environ.get("OUT_DIR", "/generated")
INTERVAL = int(os.environ.get("RENDER_INTERVAL", "30"))

FONT_SIZES = (24, 32, 44, 60, 84)  # index by usage below


def _font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


F_SMALL, F_NAME, F_STATE, F_BIG, F_HUGE = (_font(s) for s in FONT_SIZES)


def ha_get(entity):
    req = urllib.request.Request(
        f"{HA_URL}/api/states/{entity}", headers={"Authorization": f"Bearer {TOKEN}"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode())
    except Exception:
        return None


def payload(*fragments):
    """Compact JSON payload fragment (no spaces - map is TSV)."""
    return ",".join(fragments).replace(" ", "")


def render(cfg, states):
    W, H = cfg["panel"]["w"], cfg["panel"]["h"]
    img = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(img)
    regions = []

    # ---- top bar ----
    bar = 150
    d.rectangle([0, 0, W, bar], fill=0)
    d.text((40, 20), cfg.get("locationLabel", "Home"), fill=255, font=F_HUGE)
    d.text(
        (W - 40, 55),
        "updated " + datetime.now().strftime("%H:%M"),
        fill=255,
        font=F_NAME,
        anchor="ra",
    )

    # ---- room cards in a 2-column grid ----
    rooms = cfg["rooms"]
    cols = 2
    gap = 40
    x0, y0 = gap, bar + gap
    card_w = (W - gap * (cols + 1)) // cols
    max_rows = 0
    for i, room in enumerate(rooms):
        cx = x0 + (i % cols) * (card_w + gap)
        cy = y0 + (i // cols) * 0  # heights computed below per column
        max_rows = max(max_rows, len(room["devices"]))

    # simple stack: equal-height cards per column
    rows = (len(rooms) + 1) // cols
    if rows == 0:
        return img, regions
    card_h = (H - y0 - gap - rows * gap) // rows if rows > 0 else 0
    for i, room in enumerate(rooms):
        cx = gap + (i % cols) * (card_w + gap)
        cy = y0 + (i // cols) * (card_h + gap)
        d.rectangle([cx, cy, cx + card_w, cy + card_h], outline=0, width=6)
        d.text((cx + 20, cy + 10), room["name"].upper(), fill=0, font=F_BIG)
        d.line([cx, cy + 100, cx + card_w, cy + 100], fill=0, width=6)

        y = cy + 120
        for dev in room["devices"]:
            st = states.get(dev["entity"])
            state_txt = st["state"] if st else "..."
            unit = (st or {}).get("attributes", {}).get("unit_of_measurement", "")
            if unit:
                state_txt += " " + unit
            d.text((cx + 20, y), dev["name"], fill=0, font=F_NAME)
            d.text((cx + 20, y + 44), state_txt, fill=0, font=F_STATE)
            y += 100

            t = dev["type"]
            if t == "toggle":
                # A large tappable button that spans the card width.
                bx, by = cx + 20, y
                bw, bh = card_w - 40, 90
                on = st and st.get("state") == "on"
                d.rectangle([bx, by, bx + bw, by + bh], fill=0 if on else 255,
                            outline=0, width=5)
                d.text((bx + bw // 2, by + bh // 2),
                       "ON" if on else "OFF",
                       fill=255 if on else 0, font=F_BIG, anchor="mm")
                regions.append((bx, by, bw, bh, "homeassistant", "toggle",
                                dev["entity"], ""))
                y += bh + 30
            elif t == "climate":
                # mode buttons from the entity's hvac_modes
                modes = (st or {}).get("attributes", {}).get("hvac_modes", [])
                bx = cx + 20
                for m in modes[:4]:
                    mw = (card_w - 40 - 3 * 10) // 4
                    active = st and st.get("state") == m
                    d.rectangle([bx, y, bx + mw, y + 70],
                                fill=0 if active else 255, outline=0, width=4)
                    d.text((bx + mw // 2, y + 35), m[:6], fill=255 if active else 0,
                           font=F_NAME, anchor="mm")
                    regions.append((bx, y, mw, 70, "climate", "set_hvac_mode",
                                    dev["entity"], f'"hvac_mode":"{m}"'))
                    bx += mw + 10
                y += 90
                cur = (st or {}).get("attributes", {}).get("temperature", 20)
                for label, delta in (("- 0.5", -0.5), ("+ 0.5", 0.5)):
                    mw = (card_w - 40 - 10) // 2
                    bx = cx + 20 + (0 if label[0] == "-" else mw + 10)
                    d.rectangle([bx, y, bx + mw, y + 70], outline=0, width=4)
                    d.text((bx + mw // 2, y + 35), label, fill=0, font=F_BIG,
                           anchor="mm")
                    regions.append((bx, y, mw, 70, "climate", "set_temperature",
                                    dev["entity"],
                                    f'"temperature":{cur + delta}'))
                y += 100
            elif t == "lock":
                locked = st and st.get("state") == "locked"
                service = "unlock" if locked else "lock"
                bx, by = cx + 20, y
                bw, bh = card_w - 40, 90
                d.rectangle([bx, by, bx + bw, by + bh], outline=0, width=5)
                d.text((bx + bw // 2, by + bh // 2),
                       "UNLOCK" if locked else "LOCK",
                       fill=0, font=F_BIG, anchor="mm")
                regions.append((bx, by, bw, bh, "lock", service,
                                dev["entity"], ""))
                y += bh + 30
            # sensor: no region, read-only

    return img, regions


def write_map(regions, path):
    with open(path, "w") as f:
        for x, y, w, h, dom, svc, ent, payload_extra in regions:
            f.write(f"{x}\t{y}\t{w}\t{h}\t{dom}\t{svc}\t{ent}\t{payload_extra}\n")


def main():
    with open(CONFIG) as f:
        cfg = json.load(f)
    os.makedirs(OUT_DIR, exist_ok=True)

    print(f"renderer: panel {cfg['panel']['w']}x{cfg['panel']['h']}, "
          f"{len(cfg['rooms'])} rooms, interval {INTERVAL}s", flush=True)

    while True:
        states = {}
        for room in cfg["rooms"]:
            for dev in room["devices"]:
                states[dev["entity"]] = ha_get(dev["entity"])

        img, regions = render(cfg, states)
        tmp = os.path.join(OUT_DIR, ".dash.png.tmp")
        img.save(tmp, "PNG")
        os.replace(tmp, os.path.join(OUT_DIR, "dashboard.png"))
        write_map(regions, os.path.join(OUT_DIR, ".dash.map.tmp"))
        os.replace(os.path.join(OUT_DIR, ".dash.map.tmp"),
                   os.path.join(OUT_DIR, "dashboard.map"))
        print(f"renderer: rendered {len(regions)} regions", flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
