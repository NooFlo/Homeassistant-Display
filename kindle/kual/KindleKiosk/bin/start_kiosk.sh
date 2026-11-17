#!/bin/sh
. /mnt/us/kiosk/kiosk.env
rm -f /mnt/us/DISABLE_KIOSK
lipc-set-prop com.lab126.powerd preventScreenSaver 1
lipc-set-prop -i com.lab126.appmgrd start app://web-reader "{\"url\":\"http://$SERVER_IP:$SERVER_PORT/\"}"
