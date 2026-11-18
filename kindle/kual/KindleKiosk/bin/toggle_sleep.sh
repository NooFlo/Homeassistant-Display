#!/bin/sh
# Escape hatch: create/remove the flag that disables the sleep engine.
FLAG=/mnt/us/DISABLE_SLEEP
if [ -e "$FLAG" ]; then
  rm -f "$FLAG"
  echo "Sleep engine ENABLED"
else
  touch "$FLAG"
  echo "Sleep engine DISABLED (device stays awake)"
fi
