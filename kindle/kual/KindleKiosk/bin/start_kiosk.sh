#!/bin/sh
# KUAL: Start Kiosk.
#
# On firmwares without working upstart (Paperwhite 11 / EY21, firmware
# 5.14+) this is the primary entry point: it launches the browser, the
# sleep engine, and keeps the framework screensaver suppressed.
. /mnt/us/kiosk/kiosk.env

rm -f /mnt/us/DISABLE_KIOSK

lipc-set-prop com.lab126.powerd preventScreenSaver 1

# Launch the sleep/wake engine if it is not already running and not
# explicitly disabled.
if [ ! -e /mnt/us/DISABLE_SLEEP ] && ! pgrep -f kiosk-sleep.sh >/dev/null 2>&1; then
  sh /mnt/us/kiosk/bin/kiosk-sleep.sh &
fi

lipc-set-prop -i com.lab126.appmgrd start app://web-reader "{\"url\":\"http://$SERVER_IP:$SERVER_PORT/\"}"
