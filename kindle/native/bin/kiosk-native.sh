#!/bin/sh
# kiosk-native.sh - the framework-less native loop ("TRMNL with a screen").
#
# Runs alongside this loop:
#
#   fetch PNG + region map from the server renderer
#     -> paint the PNG (FBInk, full refresh on change)
#     -> wait for a tap (evdev)
#          tap  -> look the region up in the map -> POST the region's
#                  HA service call -> re-render (server + repaint)
#          idle -> presence check (light sleep, poll input_boolean.kindle_wake)
#                  -> deep sleep (RTC alarm) with no presence
#
# The UI lives entirely on the server: the renderer emits
#   /generated/dashboard.png  - the current dashboard image
#   /generated/dashboard.map  - TSV touch-region -> service-call map:
#       x, y, w, h, domain, service, entity, json-payload
# This loop is UI-agnostic; changing the dashboard changes nothing here.
#
# Started by the KindleNative KUAL entry, which stops lab126_gui first
# and restores it on exit.

KIOSK_DIR=/mnt/us/kiosk
. "$KIOSK_DIR/kiosk.env" 2>/dev/null || . ./kiosk.env

IMG="$KIOSK_DIR/dash.png"
IMG_NEW="$KIOSK_DIR/dash.png.new"
MAP="$KIOSK_DIR/dash.map"
MAP_NEW="$KIOSK_DIR/dash.map.new"
BASE="http://$SERVER_IP:$SERVER_PORT"
LAST_PAINT_MD5=""

log() { logger -t kiosk-native "$1"; }

# ---- painting ---------------------------------------------------

paint() { "$FBINK_BIN" -i "$IMG" >/dev/null 2>&1 || fbink -i "$IMG" >/dev/null 2>&1; }

# Content-conditional refresh: fetch new assets, repaint only when the
# image actually changed (the renderer's ETag discipline made simple).
fetch_and_paint() {
  wget -q -O "$IMG_NEW" "$BASE/generated/dashboard.png" && mv "$IMG_NEW" "$IMG"
  wget -q -O "$MAP_NEW" "$BASE/generated/dashboard.map" 2>/dev/null && mv "$MAP_NEW" "$MAP"
  NEW_MD5=$(md5sum "$IMG" 2>/dev/null | cut -d' ' -f1)
  if [ "$NEW_MD5" != "$LAST_PAINT_MD5" ]; then
    paint
    LAST_PAINT_MD5=$NEW_MD5
  fi
}

# ---- HA plumbing (busybox-safe) -----------------------------------

wake_state() {
  RESP=$(printf 'GET /wake HTTP/1.0\r\nHost: %s\r\n\r\n' "$SERVER_IP" | \
    nc "$SERVER_IP" "$SERVER_PORT" 2>/dev/null | tail -1)
  case "$RESP" in
    *'"state": "on"'*|*'"state":"on"'*)  echo on ;;
    *) echo off ;;
  esac
}

# Generic service call from a region map line:
#   x y w h | domain | service | entity | payload-json
http_post_service() {
  PAYLOAD=$(printf '{"entity_id": "%s", %s}' "$3" "$4")
  printf 'POST /api/services/%s/%s HTTP/1.0\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %s\r\n\r\n%s' \
    "$1" "$2" "$SERVER_IP" "${#PAYLOAD}" "$PAYLOAD" | \
    nc "$SERVER_IP" "$SERVER_PORT" >/dev/null 2>&1
}

push_battery() {
  BATT=$(gasgauge-info -s 2>/dev/null | tr -dc '0-9')
  [ -z "$BATT" ] && return 0
  PAYLOAD=$(printf '{"state": "%s", "attributes": {"unit_of_measurement": "%%", "friendly_name": "Kindle Battery"}}' "$BATT")
  printf 'POST /api/states/%s HTTP/1.0\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %s\r\n\r\n%s' \
    "$BATT_ENTITY" "$SERVER_IP" "${#PAYLOAD}" "$PAYLOAD" | \
    nc "$SERVER_IP" "$SERVER_PORT" >/dev/null 2>&1
  log "battery pushed: $BATT%"
}

# ---- touch regions -------------------------------------------------

# TAB-separated map; field split must treat the payload as one field.
T="$(printf '\t')"

find_region() { # $1=x $2=y -> sets REGION_* or returns 1
  awk -v tx="$1" -v ty="$2" -F"$T" \
    '$1+0 <= tx && tx <= $1+0+$3+0 && $2+0 <= ty && ty <= $2+0+$4+0 \
     { print $5; print $6; print $7; print $8; exit }' "$MAP"
}

handle_tap() { # $1=x $2=y
  R=$(find_region "$1" "$2")
  [ -z "$R" ] && return 0
  DOMAIN=$(echo "$R" | sed -n 1p)
  SERVICE=$(echo "$R" | sed -n 2p)
  ENTITY=$(echo "$R" | sed -n 3p)
  PAYLOAD=$(echo "$R" | sed -n 4p)
  [ -n "$DOMAIN" ] || return 0
  log "tap ($1,$2) -> $DOMAIN.$SERVICE $ENTITY"
  http_post_service "$DOMAIN" "$SERVICE" "$ENTITY" "$PAYLOAD"
}

# ---- deep sleep ---------------------------------------------------

deep_sleep() {
  log "deep sleep (alarm in ${ALARM}s)"
  NOW=$(date +%s)
  echo $((NOW + ALARM)) > "$RTC/wakealarm" 2>/dev/null
  echo mem > /sys/power/state
  log "woke from deep sleep"
}

# ---- main loop ---------------------------------------------------

log "kiosk-native started"
push_battery
fetch_and_paint

trap 'log "exiting"; exit 0' TERM INT

IDLE_COUNT=0
LIGHT_COUNT=0
WAS_AWAKE=off

if [ -e /mnt/us/DISABLE_SLEEP ]; then
  log "DISABLE_SLEEP set: staying awake"
fi

while true; do
  if COORDS=$("$KIOSK_DIR/bin/wait_tap" "$TOUCH" "$POLL" 2>/dev/null); then
    # A tap is activity: act + refresh.
    X=$(echo "$COORDS" | cut -d' ' -f1)
    Y=$(echo "$COORDS" | cut -d' ' -f2)
    handle_tap "$X" "$Y"
    sleep 2          # let HA settle, then pick up the fresh render
    fetch_and_paint
    IDLE_COUNT=0
    LIGHT_COUNT=0
    continue
  fi

  IDLE_COUNT=$((IDLE_COUNT + POLL))
  STATE=$(wake_state)

  if [ "$STATE" = "on" ] && [ "$WAS_AWAKE" = "off" ]; then
    log "presence wake: refreshing"
    fetch_and_paint
    IDLE_COUNT=0
  fi
  WAS_AWAKE=$STATE
  [ "$STATE" = "on" ] && LIGHT_COUNT=$((LIGHT_COUNT + POLL))

  # Periodic refresh while awake (weather/clock/sensor drift).
  fetch_and_paint
  push_battery

  if [ $IDLE_COUNT -ge $IDLE ] && [ ! -e /mnt/us/DISABLE_SLEEP ]; then
    if [ "$STATE" = "on" ] && [ $LIGHT_COUNT -lt $LIGHT_SLEEP_MAX ]; then
      : # light sleep: keep polling, screen live, touch armed
    else
      push_battery
      deep_sleep
      fetch_and_paint   # resume: refresh from resume time
      IDLE_COUNT=0
      LIGHT_COUNT=0
    fi
  fi
done
