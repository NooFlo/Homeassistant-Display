#!/bin/sh
# kiosk-sleep.sh - the power-management engine of the Kindle HA display.
#
# Started by the kiosk-sleep upstart job at boot. Runs forever:
#
#   ACTIVE      - dashboard is live; touch events reset the idle timer.
#   LIGHT SLEEP - presence (input_boolean.kindle_wake) is 'on': the device
#                 stays awake-but-idle, polling the wake boolean. The next
#                 'on' transition reloads the dashboard so it is instantly
#                 interactive. Costs battery; paid only while someone is
#                 home.
#   DEEP SLEEP  - no presence, idle for IDLE seconds: RTC alarm armed,
#                 SoC suspended, e-ink holds the last image at zero power.
#                 Wakes on power button or the RTC alarm.
#
# Battery level is pushed to HA as sensor.kindle_battery.
#
# Patterns derived from higoorc/kindle-dash (MIT) and
# cdmckay/kindle-voyage-weather (MIT).

KIOSK_DIR=/mnt/us/kiosk
. "$KIOSK_DIR/kiosk.env"

BASE_URL="http://$SERVER_IP:$SERVER_PORT"
LAST_BATT=0
BATT_COUNT=0

log() { logger -t kiosk-sleep "$1"; }

# ---- helpers ----------------------------------------------------

# Blocking read of the touch device: returns as soon as any input event
# arrives, or after $1 seconds of silence.
touch_quiet() {
  timeout "$1" dd if="$TOUCH" bs=64 count=1 2>/dev/null >/dev/null
  [ $? -ne 0 ]
}

# Minimal HTTP GET via nc (Kindle busybox wget cannot do headers cleanly).
http_get() {
  printf 'GET %s HTTP/1.0\r\nHost: %s\r\n\r\n' "$1" "$SERVER_IP" | \
    nc "$SERVER_IP" "$SERVER_PORT" 2>/dev/null
}

# Push battery level as a state override into HA via the proxy.
push_battery() {
  BATT=$(gasgauge-info -s 2>/dev/null | tr -d ' %')
  [ -z "$BATT" ] && return 0
  PAYLOAD="{\"state\": \"$BATT\", \"attributes\": {\"unit_of_measurement\": \"%\", \"friendly_name\": \"Kindle Battery\"}}"
  printf 'POST /api/states/%s HTTP/1.0\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %s\r\n\r\n%s' \
    "$BATT_ENTITY" "$SERVER_IP" "${#PAYLOAD}" "$PAYLOAD" | \
    nc "$SERVER_IP" "$SERVER_PORT" >/dev/null 2>&1
  log "battery pushed: $BATT%"
}

# Poll the presence/wake boolean. Echoes 'on', 'off' or 'unknown'.
wake_state() {
  RESP=$(http_get '/wake' | tail -1)
  case "$RESP" in
    *'"state": "on"'*|*'"state":"on"'*)  echo on ;;
    *'"state": "off"'*|*'"state":"off"'*) echo off ;;
    *) echo unknown ;;
  esac
}

# Ask the framework to (re)load the dashboard in the stock browser.
load_dashboard() {
  lipc-set-prop -i com.lab126.appmgrd start app://web-reader \
    "{\"url\":\"$BASE_URL/\"}" >/dev/null 2>&1
}

# Arm the RTC wake alarm $1 seconds out, then suspend to RAM.
deep_sleep() {
  log "entering deep sleep (alarm in ${ALARM}s)"
  NOW=$(date +%s)
  echo $((NOW + $1)) > "$RTC/wakealarm" 2>/dev/null
  echo mem > /sys/power/state
  log "woke from deep sleep"
}

# ---- main loop --------------------------------------------------

log "kiosk-sleep started"

if [ -e /mnt/us/DISABLE_SLEEP ]; then
  log "DISABLE_SLEEP set: engine idle, not managing power"
  while [ -e /mnt/us/DISABLE_SLEEP ]; do sleep 60; done
  log "DISABLE_SLEEP removed: engine active"
fi

IDLE_COUNT=0
LIGHT_COUNT=0
WAS_AWAKE=off

while true; do

  # One poll cycle. Any touch counts as activity.
  if touch_quiet "$POLL"; then
    IDLE_COUNT=0
    LIGHT_COUNT=0
  else
    IDLE_COUNT=$((IDLE_COUNT + POLL))
    STATE=$(wake_state)
    [ "$STATE" = "on" ] && LIGHT_COUNT=$((LIGHT_COUNT + POLL))

    # Presence just switched on while we were idling: the dashboard went
    # stale, reload it so it is live and interactive immediately.
    if [ "$STATE" = "on" ] && [ "$WAS_AWAKE" = "off" ]; then
      log "presence wake: reloading dashboard"
      load_dashboard
      IDLE_COUNT=0
      LIGHT_COUNT=0
    fi
    WAS_AWAKE=$STATE

    # Battery telemetry.
    BATT_COUNT=$((BATT_COUNT + 1))
    if [ $BATT_COUNT -ge $BATT_EVERY ]; then
      BATT_COUNT=0
      push_battery
    fi

    # Sleep decisions.
    if [ $IDLE_COUNT -ge $IDLE ]; then
      if [ "$STATE" = "on" ] && [ $LIGHT_COUNT -lt $LIGHT_SLEEP_MAX ]; then
        # Presence active: light sleep, keep polling. No suspend, so
        # the screen stays live and touch keeps working.
        :
      elif [ -e /mnt/us/DISABLE_SLEEP ]; then
        : # escape hatch: stay awake
      else
        push_battery
        deep_sleep "$ALARM"
        # Returned from suspend: wake via power button or RTC.
        load_dashboard
        IDLE_COUNT=0
        LIGHT_COUNT=0
        BATT_COUNT=0
        push_battery
      fi
    fi
  fi

done
