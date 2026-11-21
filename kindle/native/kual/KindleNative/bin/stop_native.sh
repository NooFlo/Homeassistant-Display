#!/bin/sh
# Escape hatch: stop the native loop, restore the reader.
pkill -f kiosk-native.sh 2>/dev/null
killall -CONT lab126_gui 2>/dev/null
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
echo "Native kiosk stopped; framework restored."
