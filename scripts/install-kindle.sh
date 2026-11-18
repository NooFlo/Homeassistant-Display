#!/bin/sh
# install-kindle.sh - push the kiosk onto a jailbroken Kindle over SSH.
#
# Prerequisites on the device (see docs/INSTALL.md and docs/MODELS.md):
#   - jailbreak + KUAL + MRPI + USBNetwork (SSH over WiFi)
#   - the server (docker compose up -d) running and reachable
#
# Usage:
#   KINDLE_IP=192.168.1.50 bash scripts/install-kindle.sh
#
# On modern firmware (Paperwhite 11 / EY21, 5.14+) upstart is not used;
# run in KUAL-only mode and start the kiosk from the KUAL menu instead:
#   KINDLE_IP=192.168.1.50 KUAL_ONLY=1 bash scripts/install-kindle.sh
#
# Safe to re-run at any time.

set -e

KINDLE_IP="${KINDLE_IP:?Set KINDLE_IP to your Kindle's address, e.g. KINDLE_IP=192.168.1.50 bash scripts/install-kindle.sh}"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "==> Installing kiosk onto Kindle at $KINDLE_IP"

# Read the server address from the Kindle env file so device files and
# the local config stay in sync.
SERVER_IP=$(grep '^SERVER_IP=' "$REPO_ROOT/kindle/kiosk.env" | cut -d= -f2)
SERVER_PORT=$(grep '^SERVER_PORT=' "$REPO_ROOT/kindle/kiosk.env" | cut -d= -f2)
echo "    dashboard server: $SERVER_IP:$SERVER_PORT"

# --- userstore: kiosk files + KUAL extension ------------------------------

ssh "root@$KINDLE_IP" "mkdir -p /mnt/us/kiosk/bin /mnt/us/extensions/KindleKiosk/bin"

echo "    pushing kindle/kiosk.env"
ssh "root@$KINDLE_IP" "cat > /mnt/us/kiosk/kiosk.env" < "$REPO_ROOT/kindle/kiosk.env"

echo "    pushing kindle/bin/kiosk-sleep.sh"
ssh "root@$KINDLE_IP" "cat > /mnt/us/kiosk/bin/kiosk-sleep.sh" \
  < "$REPO_ROOT/kindle/bin/kiosk-sleep.sh"
ssh "root@$KINDLE_IP" "chmod +x /mnt/us/kiosk/bin/kiosk-sleep.sh"

for f in start_kiosk.sh stop_kiosk.sh toggle_sleep.sh; do
  echo "    pushing KUAL bin/$f"
  ssh "root@$KINDLE_IP" "cat > /mnt/us/extensions/KindleKiosk/bin/$f" \
    < "$REPO_ROOT/kindle/kual/KindleKiosk/bin/$f"
  ssh "root@$KINDLE_IP" "chmod +x /mnt/us/extensions/KindleKiosk/bin/$f"
done

echo "    pushing KUAL menu.json"
ssh "root@$KINDLE_IP" "cat > /mnt/us/extensions/KindleKiosk/menu.json" \
  < "$REPO_ROOT/kindle/kual/KindleKiosk/menu.json"

# --- upstart jobs (classic firmware only) ----------------------------------

if [ "$KUAL_ONLY" = "1" ]; then
  echo "==> KUAL_ONLY=1: skipping upstart jobs (modern firmware)."
  echo "==> Done. Start the dashboard from KUAL -> KindleKiosk -> Start Kiosk."
  echo "    (Re-run the KUAL entry after each reboot; battery/sleep engine"
  echo "     runs from the same menu entry.)"
  exit 0
fi

# (cat > file because scp is not reliably present on these devices)

echo "    remounting rootfs read-write"
ssh "root@$KINDLE_IP" "mount -o remount,rw /dev/root /"

for f in kiosk.conf kiosk-sleep.conf wifi-keepalive.conf; do
  echo "    installing upstart job $f"
  sed -e "s/SERVER_IP/$SERVER_IP/g" -e "s/SERVER_PORT/$SERVER_PORT/g" \
    "$REPO_ROOT/kindle/$f" | ssh "root@$KINDLE_IP" "cat > /etc/upstart/$f"
done

echo "    remounting rootfs read-only"
ssh "root@$KINDLE_IP" "mount -o remount,ro /dev/root /"

echo "==> Done. Rebooting the Kindle to start the kiosk."
ssh "root@$KINDLE_IP" "/sbin/reboot"
