#!/bin/sh
set -u

TESTED_FW="1.1.6.1"
BRIDGE_SHA="19a7a201f6187b193c56e166986e084fb9262722b4ea948f430ed0d373f30b95"
BEACON_SHA="3f9239e04d0a04cea946749d3ec83b7f9ee00914439b973a2d10d252698eba20"
GUARD_SHA="f33d11ded797101863119689357cf0b7129b1323ad737058c46e6a1ba5ceaa6a"
HOMING_SHA="50b9f01d15837879514ff60ed91f1c2b7be6eede1ff76b23b2f2700ec382c313"
FW_FILE="/mnt/UDISK/creality/userdata/config/system_version.json"
CONFIG_DIR="/mnt/UDISK/printer_data/config"
ERRORS=0
WARNINGS=0

pass() { echo "PASS: $*"; }
warn() { echo "WARN: $*"; WARNINGS=$((WARNINGS + 1)); }
error() { echo "FAIL: $*"; ERRORS=$((ERRORS + 1)); }

check_hash() {
    label=$1
    path=$2
    expected=$3
    if [ ! -f "$path" ]; then
        error "$label missing: $path"
        return
    fi
    actual=$(sha256sum "$path" | awk '{print $1}')
    if [ "$actual" = "$expected" ]; then pass "$label checksum"; else error "$label checksum is $actual"; fi
}

if [ -f "$FW_FILE" ]; then
    FW=$(sed -n 's/.*"sys_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FW_FILE" | head -n 1)
    if [ "$FW" = "$TESTED_FW" ]; then pass "firmware $FW"; else warn "firmware is $FW; repository runtime was tested on $TESTED_FW"; fi
else
    error "firmware identity file missing"
fi

if [ "$(uname -m)" = "armv7l" ]; then pass "ARMv7 architecture"; else error "unsupported architecture $(uname -m)"; fi
if lsusb 2>/dev/null | grep -qi '04d8:e72b'; then pass "Beacon RevH USB device"; else error "Beacon USB VID:PID 04d8:e72b not found"; fi
if [ -L /dev/cartographer ] && [ -e /dev/cartographer ]; then pass "/dev/cartographer resolves to $(readlink /dev/cartographer)"; else error "/dev/cartographer is missing or broken"; fi
if ps | grep '[b]eacon_usb_bridge' >/dev/null 2>&1; then pass "Beacon bridge process"; else error "Beacon bridge process not running"; fi

check_hash "bridge" /mnt/UDISK/bin/beacon_usb_bridge "$BRIDGE_SHA"
check_hash "Beacon Klipper module" /mnt/UDISK/root/beacon_klipper/beacon.py "$BEACON_SHA"
check_hash "Beacon guard module" /usr/share/klipper/klippy/extras/beacon_guard.py "$GUARD_SHA"
check_hash "K2 homing compatibility module" /usr/share/klipper/klippy/extras/homing.py "$HOMING_SHA"

for include in beacon_user.cfg beacon_guard.cfg KAMP_Settings.cfg; do
    if grep -Eq "^[[:space:]]*\[include[[:space:]]+$include\]" "$CONFIG_DIR/printer.cfg" 2>/dev/null; then
        pass "printer.cfg includes $include"
    else
        warn "printer.cfg does not include $include"
    fi
done

if grep -Eq '^[[:space:]]*Tn_retrude:[[:space:]]*-18([[:space:]]|$)' "$CONFIG_DIR/box.cfg" 2>/dev/null; then pass "DXC2 Tn_retrude -18"; else warn "Tn_retrude is not the tested -18"; fi
if grep -Eq '^[[:space:]]*buffer_empty_len:[[:space:]]*25\.5([[:space:]]|$)' "$CONFIG_DIR/box.cfg" 2>/dev/null; then pass "CFS buffer_empty_len 25.5"; else warn "buffer_empty_len is not the tested 25.5"; fi
if grep -q '^\[gcode_macro _CODEX_START_PRINT_AFTER_BOX\]' "$CONFIG_DIR/gcode_macro.cfg" 2>/dev/null; then pass "staged start macro"; else warn "staged start macro not found"; fi
if grep -q '^\[gcode_macro DXC2_END_UNLOAD\]' "$CONFIG_DIR/gcode_macro.cfg" 2>/dev/null; then pass "DXC2 end unload macro"; else warn "DXC2 end unload macro not found"; fi
if grep -Eq '^[[:space:]]*G0[[:space:]]+E-40[[:space:]]+F360' "$CONFIG_DIR/gcode_macro.cfg" 2>/dev/null; then pass "DXC2 40 mm unload retract"; else warn "DXC2 unload retract not found"; fi

echo "Summary: $ERRORS failure(s), $WARNINGS warning(s)."
[ "$ERRORS" -eq 0 ]
