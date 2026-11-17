#!/bin/sh
touch /mnt/us/DISABLE_KIOSK
lipc-set-prop com.lab126.powerd preventScreenSaver 0
# Return to the stock home screen.
lipc-set-prop -i com.lab126.appmgrd start app://com.lab126.home
