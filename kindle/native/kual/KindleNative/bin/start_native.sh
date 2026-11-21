#!/bin/sh
# KUAL: Start Native Kiosk.
#
# Takes over the screen from the Amazon framework (level-B integration):
# stops lab126_gui, runs the native render loop in the foreground, and
# restores the framework when it exits.
#
# powerd, wifid and appmgrd stay running - they provide battery, WiFi
# and suspend plumbing the loop needs. Only the Java GUI is replaced.

. /mnt/us/kiosk/kiosk.env

rm -f /mnt/us/DISABLE_KIOSK

logmesg() { logger -t kindle-native "$1"; }

# Keep the framework's own idle/screenblanking out of the way.
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null

WAIT=$(pidof lab126_gui | head -1)
if [ -n "$WAIT" ]; then
  logmesg "stopping lab126_gui"
  killall -STOP lab126_gui            # freeze; full kill risks watchdog restarts
fi

logmesg "starting native loop"
sh /mnt/us/kiosk/bin/kiosk-native.sh
RC=$?

logmesg "native loop exited (rc=$RC), restoring framework"
killall -CONT lab126_gui 2>/dev/null || \
  (initctl start lab126_gui 2>/dev/null; lipc-set-prop -i com.lab126.appmgrd start app://com.lab126.home 2>/dev/null)
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
exit $RC
