# Installation

This procedure is intentionally backup-first and staged. Do not paste a complete reference `printer.cfg` over your machine.

## 1. Prerequisites

- Creality K2 Plus with working SSH access.
- DXC2 mechanically installed with the correct screws, both transferred sensor boards, pressure arm, PTFE guide, and extended cutter actuator verified.
- Beacon RevH mounted rigidly and connected by USB.
- A computer on the same LAN with `git` and `scp`.
- Physical access to the printer for the first home, Contact calibration, cutter calibration, load/unload, and print.

The supplied runtime is pinned to Creality firmware `1.1.6.1` on 32-bit ARMv7. The installer refuses a different firmware unless `FORCE_UNTESTED=1` is explicitly supplied. That override means only “copy the files”; it does not mean the firmware is compatible.

## 2. Clone and transfer

On your computer:

```sh
git clone https://github.com/Tinman-FP/Creality-K2-Plus-DXC2-Beacon.git
scp -r Creality-K2-Plus-DXC2-Beacon root@PRINTER_IP:/mnt/UDISK/root/
```

Do not put a printer IP address or SSH password into a public configuration file.

## 3. Install the version-pinned runtime

SSH to the printer and run:

```sh
cd /mnt/UDISK/root/Creality-K2-Plus-DXC2-Beacon
sh scripts/install-runtime.sh
```

The script:

1. records the firmware and architecture;
2. creates `/mnt/UDISK/root/backups/k2_dxc2_beacon_<timestamp>`;
3. installs the ARMv7 USB bridge and OpenWrt service;
4. installs the tested Beacon Klipper module and Beacon guard;
5. replaces `homing.py` only when its SHA-256 matches the known `1.1.6.1` stock file or the already-tested modified file;
6. starts the USB bridge; and
7. does **not** restart Klipper or edit the main printer configuration.

Write down the backup directory printed by the installer.

## 4. Confirm the USB bridge

Run:

```sh
lsusb | grep -i '04d8:e72b'
ls -l /dev/cartographer
ps | grep '[b]eacon_usb_bridge'
```

Expected results:

- Beacon appears as `04d8:e72b`.
- `/dev/cartographer` points to a PTY such as `/dev/pts/0`.
- one `beacon_usb_bridge` process is running.

Stop here if any of these are missing.

## 5. Add configuration files

Copy the reusable files:

```sh
cp config/beacon_user.cfg.example /mnt/UDISK/printer_data/config/beacon_user.cfg
cp config/beacon_guard.cfg /mnt/UDISK/printer_data/config/beacon_guard.cfg
cp config/KAMP_Settings.cfg /mnt/UDISK/printer_data/config/KAMP_Settings.cfg
mkdir -p /mnt/UDISK/printer_data/config/KAMP
cp config/KAMP/Adaptive_Meshing.cfg /mnt/UDISK/printer_data/config/KAMP/Adaptive_Meshing.cfg
```

Edit `beacon_user.cfg` before restarting Klipper:

```ini
[beacon]
serial: /dev/cartographer
x_offset: 0
y_offset: -25.703
```

The values above belong to the reference mount. Measure your mount from nozzle to coil center:

- probe right of nozzle: positive X;
- probe left of nozzle: negative X;
- probe behind nozzle: positive Y;
- probe in front of nozzle: negative Y.

The reference coil was measured approximately 2.6 mm above the nozzle tip. Do **not** enter that as a conventional fixed Z offset; `BEACON_AUTO_CALIBRATE` learns the Contact/model relationship.

## 6. Merge `printer.cfg`

Add the following includes above the `SAVE_CONFIG` block:

```ini
[include beacon_user.cfg]
[include beacon_guard.cfg]
[include KAMP_Settings.cfg]
```

Replace the stock strain-gauge probe path:

```ini
[stepper_z]
endstop_pin: probe:z_virtual_endstop
homing_retract_dist: 0

[stepper_z1]
endstop_pin: probe:z_virtual_endstop
```

Remove or comment the entire stock `[prtouch_v3]` section. Do not leave both probe systems active.

The tested bed-mesh geometry is:

```ini
[bed_mesh]
zero_reference_position: 175,175
speed: 200
mesh_min: 10,5
mesh_max: 340,325
probe_count: 31,31
mesh_pps: 2,2
algorithm: bicubic
horizontal_move_z: 5
```

Those bounds are safe only for the measured `x_offset: 0`, `y_offset: -25.703` and the reference machine's travel limits. Recalculate bounds for a different mount. At probe Y=325, the reference toolhead sits at Y=350.703, leaving about 1.3 mm before its 352 mm limit.

Do not copy anything from another machine's `SAVE_CONFIG` block.

## 7. Merge the homing override

The K2's bed can be at an unknown height after power-up. The tested flow is:

1. home X/Y;
2. use Creality's lower optical switches (`ZDOWN`) to establish and level the bed;
3. move to Z=20 at normal Z speed;
4. run `BEACON_AUTO_CALIBRATE` at bed center;
5. use fast Beacon proximity homing for later Z homes.

Compare your `sensorless.cfg` with [`reference/sensorless.cfg.tested`](../reference/sensorless.cfg.tested). Merge the `_HOME_Z` and homing-override changes; do not blindly replace a firmware-version-mismatched file.

Important details:

- remove `PRES_CHECK` calls tied to the removed stock probe;
- use `BED_MESH_CLEAR` after homing instead of loading a stale default profile;
- `G28 Z BEACON=1` selects the Beacon-specific path in the supplied `homing.py`;
- the Contact calibration position is nozzle-centered at X175/Y175;
- proximity homing is coil-centered using the configured X/Y offset.

## 8. Merge print and calibration macros

Use the files in [`config/macros`](../config/macros):

- `start_print.cfg`: disarms the guard, completes CFS preflight, then evaluates the current mesh in a second macro stage;
- `dxc2_end_unload.cfg`: performs a physical CFS unload before Creality end bookkeeping;
- `beacon_calibration.cfg`: full-bed and maintenance calibration references.

These sections replace existing macro sections with the same names. Klipper rejects duplicate macro names.

Why two start stages matter: Klipper renders a macro's Jinja state before queued commands execute. A single-stage macro can see an active mesh, queue `BOX_START_PRINT`, have that preflight clear the mesh, skip calibration, and then fail while arming the Beacon guard. Calling a second macro after `BOX_START_PRINT` forces a fresh state evaluation.

## 9. Apply DXC2/CFS values

Follow [`DXC2-CFS.md`](DXC2-CFS.md). Begin with the manufacturer changes, verify the mechanics, and only then approach the reference-machine tuning.

Merge `cut_pos_offset: 0.6` from
[`config/dxc2/motor-control-values.cfg.example`](../config/dxc2/motor-control-values.cfg.example)
into the existing `[motor_control]` section; do not include the example as a
second section. Run `CALIBRATE_CUT_POS` afterward and watch the entire move.

The unload reference file also requires small integration lines in the
existing `START_PRINT`, `END_PRINT`, `CANCEL_PRINT`, and `MOTOR_CANCEL_PRINT`
macros. Follow the comments at the top of
[`config/macros/dxc2_end_unload.cfg`](../config/macros/dxc2_end_unload.cfg) and
do not create duplicate macro sections.

## 10. Restart and validate

Run the read-only verifier:

```sh
sh scripts/verify.sh
```

Only after it passes and while standing at the printer:

```gcode
RESTART
```

Continue with [`VALIDATION.md`](VALIDATION.md). Do not start with a production print.
