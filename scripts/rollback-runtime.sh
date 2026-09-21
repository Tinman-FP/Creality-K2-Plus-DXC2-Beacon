#!/bin/sh
set -eu

BACKUP_DIR=${1:-}
EXTRAS_DIR="/usr/share/klipper/klippy/extras"

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 /mnt/UDISK/root/backups/k2_dxc2_beacon_YYYYMMDD_HHMMSS" >&2
    exit 2
fi
case "$BACKUP_DIR" in
    /mnt/UDISK/root/backups/k2_dxc2_beacon_*) ;;
    *) echo "Refusing unexpected backup path: $BACKUP_DIR" >&2; exit 2 ;;
esac
[ -d "$BACKUP_DIR" ] || { echo "Backup directory not found: $BACKUP_DIR" >&2; exit 2; }
[ -f "$BACKUP_DIR/manifest.txt" ] || { echo "Backup manifest missing: $BACKUP_DIR" >&2; exit 2; }

restore_one() {
    name=$1
    dest=$2
    if [ -e "$BACKUP_DIR/$name" ] || [ -L "$BACKUP_DIR/$name" ]; then
        rm -f "$dest"
        cp -a "$BACKUP_DIR/$name" "$dest"
    elif [ -f "$BACKUP_DIR/$name.missing" ]; then
        rm -f "$dest"
    else
        echo "Backup entry missing for $name" >&2
        exit 1
    fi
}

/etc/init.d/beacon stop 2>/dev/null || true
restore_one bridge_binary /mnt/UDISK/bin/beacon_usb_bridge
restore_one beacon_init /etc/init.d/beacon
restore_one beacon_target /mnt/UDISK/root/beacon_klipper/beacon.py
restore_one beacon_extra "$EXTRAS_DIR/beacon.py"
restore_one beacon_guard_extra "$EXTRAS_DIR/beacon_guard.py"
restore_one homing_extra "$EXTRAS_DIR/homing.py"

if [ -f /etc/init.d/beacon ]; then
    chmod 0755 /etc/init.d/beacon
    if [ -f "$BACKUP_DIR/beacon_service_was_enabled" ]; then
        /etc/init.d/beacon enable
        /etc/init.d/beacon start
    else
        /etc/init.d/beacon disable 2>/dev/null || true
    fi
else
    rm -f /dev/cartographer
fi

echo "Runtime restored from $BACKUP_DIR."
echo "Printer configuration was not changed and Klipper was not restarted."
echo "Restore your separately backed-up cfg files, then restart Klipper while physically present."
