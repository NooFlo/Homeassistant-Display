#!/bin/sh
# KUAL: Stop Kiosk - stop the sleep engine and return to the stock UI.
touch /mnt/us/DISABLE_KIOSK

pkill -f kiosk-sleep.sh >/dev/null 2>&1

lipc-set-prop com.lab126.powerd preventScreenSaver 0
# Return to the stock home screen.
lipc-set-prop -i com.lab126.appmgrd start app://com.lab126.home
