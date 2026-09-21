#!/bin/sh
set -eu

TESTED_FW="1.1.6.1"
TESTED_ARCH="armv7l"
STOCK_HOMING_SHA="cc847821cb60fb0a322e75685ea2c27e86d608a15ef4888a0cbe3dce16a2f765"
TESTED_HOMING_SHA="50b9f01d15837879514ff60ed91f1c2b7be6eede1ff76b23b2f2700ec382c313"
BRIDGE_SHA="19a7a201f6187b193c56e166986e084fb9262722b4ea948f430ed0d373f30b95"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
FW_FILE="/mnt/UDISK/creality/userdata/config/system_version.json"
EXTRAS_DIR="/usr/share/klipper/klippy/extras"
STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/mnt/UDISK/root/backups/k2_dxc2_beacon_$STAMP"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

sha_of() {
    sha256sum "$1" | awk '{print $1}'
}

save_one() {
    src=$1
    name=$2
    if [ -e "$src" ] || [ -L "$src" ]; then
        cp -a "$src" "$BACKUP_DIR/$name"
    else
        : > "$BACKUP_DIR/$name.missing"
    fi
}

[ "$(uname -m)" = "$TESTED_ARCH" ] || fail "This bridge is for $TESTED_ARCH, not $(uname -m)."
[ -f "$FW_FILE" ] || fail "Firmware identity file not found: $FW_FILE"
FW=$(sed -n 's/.*"sys_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FW_FILE" | head -n 1)
[ -n "$FW" ] || fail "Could not read sys_version from $FW_FILE"
if [ "$FW" != "$TESTED_FW" ] && [ "${FORCE_UNTESTED:-0}" != "1" ]; then
    fail "Firmware $FW is not the tested $TESTED_FW. Diff the vendor files first, or set FORCE_UNTESTED=1 to accept the risk."
fi

[ -f "$REPO_DIR/bin/armv7l/beacon_usb_bridge" ] || fail "Bridge binary is missing from the repository."
[ "$(sha_of "$REPO_DIR/bin/armv7l/beacon_usb_bridge")" = "$BRIDGE_SHA" ] || fail "Bridge checksum does not match the tested artifact."

CURRENT_HOMING_SHA="missing"
if [ -f "$EXTRAS_DIR/homing.py" ]; then
    CURRENT_HOMING_SHA=$(sha_of "$EXTRAS_DIR/homing.py")
fi
case "$CURRENT_HOMING_SHA" in
    "$STOCK_HOMING_SHA"|"$TESTED_HOMING_SHA") ;;
    *)
        [ "${FORCE_HOMING:-0}" = "1" ] || fail "Installed homing.py has unknown hash $CURRENT_HOMING_SHA. Diff it manually; FORCE_HOMING=1 explicitly overwrites it."
        ;;
esac

mkdir -p "$BACKUP_DIR"
save_one "/mnt/UDISK/bin/beacon_usb_bridge" bridge_binary
save_one "/etc/init.d/beacon" beacon_init
save_one "/mnt/UDISK/root/beacon_klipper/beacon.py" beacon_target
save_one "$EXTRAS_DIR/beacon.py" beacon_extra
save_one "$EXTRAS_DIR/beacon_guard.py" beacon_guard_extra
save_one "$EXTRAS_DIR/homing.py" homing_extra
if ls /etc/rc.d/S*beacon >/dev/null 2>&1; then
    : > "$BACKUP_DIR/beacon_service_was_enabled"
fi
{
    echo "firmware=$FW"
    echo "architecture=$(uname -m)"
    echo "homing_sha_before=$CURRENT_HOMING_SHA"
    echo "created=$STAMP"
} > "$BACKUP_DIR/manifest.txt"

mkdir -p /mnt/UDISK/bin /mnt/UDISK/root/beacon_klipper "$EXTRAS_DIR"
cp "$REPO_DIR/bin/armv7l/beacon_usb_bridge" /mnt/UDISK/bin/beacon_usb_bridge
chmod 0755 /mnt/UDISK/bin/beacon_usb_bridge
cp "$REPO_DIR/runtime/firmware-1.1.6.1/beacon.py" /mnt/UDISK/root/beacon_klipper/beacon.py
rm -f "$EXTRAS_DIR/beacon.py"
ln -s /mnt/UDISK/root/beacon_klipper/beacon.py "$EXTRAS_DIR/beacon.py"
cp "$REPO_DIR/runtime/firmware-1.1.6.1/beacon_guard.py" "$EXTRAS_DIR/beacon_guard.py"
cp "$REPO_DIR/runtime/firmware-1.1.6.1/homing.py" "$EXTRAS_DIR/homing.py"
cp "$REPO_DIR/service/beacon.init" /etc/init.d/beacon
chmod 0755 /etc/init.d/beacon
/etc/init.d/beacon enable
/etc/init.d/beacon restart

echo "Beacon runtime staged and USB bridge restarted."
echo "Backup: $BACKUP_DIR"
echo "Klipper was not restarted and printer configuration was not edited."
echo "Merge the configuration, run scripts/verify.sh, then restart Klipper while physically present."
