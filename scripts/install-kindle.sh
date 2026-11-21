#!/bin/sh
# install-kindle.sh - push the kiosk onto a jailbroken Kindle over SSH.
#
# Prerequisites on the device (see docs/INSTALL.md, docs/MODELS.md,
# docs/EY21.md):
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
# Native mode (framework-less kiosk, see docs/NATIVE.md) is always
# installed alongside; build the touch helper first:
#   make -C kindle/native
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

# --- userstore: kiosk files + KUAL extensions -------------------------------

ssh "root@$KINDLE_IP" "mkdir -p /mnt/us/kiosk/bin /mnt/us/extensions/KindleKiosk/bin /mnt/us/extensions/KindleNative/bin"

echo "    pushing kindle/kiosk.env"
ssh "root@$KINDLE_IP" "cat > /mnt/us/kiosk/kiosk.env" < "$REPO_ROOT/kindle/kiosk.env"

echo "    pushing kindle/bin/kiosk-sleep.sh"
ssh "root@$KINDLE_IP" "cat > /mnt/us/kiosk/bin/kiosk-sleep.sh" \
  < "$REPO_ROOT/kindle/bin/kiosk-sleep.sh"
ssh "root@$KINDLE_IP" "chmod +x /mnt/us/kiosk/bin/kiosk-sleep.sh"

for f in start_kiosk.sh stop_kiosk.sh toggle_sleep.sh; do
  echo "    pushing KUAL KindleKiosk bin/$f"
  ssh "root@$KINDLE_IP" "cat > /mnt/us/extensions/KindleKiosk/bin/$f" \
    < "$REPO_ROOT/kindle/kual/KindleKiosk/bin/$f"
  ssh "root@$KINDLE_IP" "chmod +x /mnt/us/extensions/KindleKiosk/bin/$f"
done

echo "    pushing KUAL KindleKiosk menu.json"
ssh "root@$KINDLE_IP" "cat > /mnt/us/extensions/KindleKiosk/menu.json" \
  < "$REPO_ROOT/kindle/kual/KindleKiosk/menu.json"

# --- native mode (framework-less kiosk) --------------------------------------

echo "    pushing native engine (kiosk-native.sh)"
ssh "root@$KINDLE_IP" "cat > /mnt/us/kiosk/bin/kiosk-native.sh" \
  < "$REPO_ROOT/kindle/native/bin/kiosk-native.sh"
ssh "root@$KINDLE_IP" "chmod +x /mnt/us/kiosk/bin/kiosk-native.sh"

if [ -f "$REPO_ROOT/kindle/native/bin/wait_tap" ]; then
  echo "    pushing native bin/wait_tap"
  ssh "root@$KINDLE_IP" "cat > /mnt/us/kiosk/bin/wait_tap" \
    < "$REPO_ROOT/kindle/native/bin/wait_tap"
  ssh "root@$KINDLE_IP" "chmod +x /mnt/us/kiosk/bin/wait_tap"
else
  echo "    WARNING: kindle/native/bin/wait_tap not built."
  echo "    Build it first: make -C kindle/native"
  echo "    Without it the native kiosk cannot receive taps."
fi

for f in start_native.sh stop_native.sh; do
  echo "    pushing KUAL KindleNative bin/$f"
  ssh "root@$KINDLE_IP" "cat > /mnt/us/extensions/KindleNative/bin/$f" \
    < "$REPO_ROOT/kindle/native/kual/KindleNative/bin/$f"
  ssh "root@$KINDLE_IP" "chmod +x /mnt/us/extensions/KindleNative/bin/$f"
done

echo "    pushing KUAL KindleNative menu.json"
ssh "root@$KINDLE_IP" "cat > /mnt/us/extensions/KindleNative/menu.json" \
  < "$REPO_ROOT/kindle/native/kual/KindleNative/menu.json"

# --- upstart jobs (classic firmware only) -------------------------------------

if [ "$KUAL_ONLY" = "1" ]; then
  echo "==> KUAL_ONLY=1: skipping upstart jobs (modern firmware)."
  echo "==> Browser kiosk: KUAL -> KindleKiosk -> Start Kiosk"
  echo "==> Native kiosk:  KUAL -> KindleNative -> Start Native Kiosk"
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
