# Validation checklist

Perform this checklist in order. Stay at the printer and keep a hand near the power switch for every first motion test.

## 1. Static checks

```sh
cd /mnt/UDISK/root/Creality-K2-Plus-DXC2-Beacon
sh scripts/verify.sh
```

Confirm:

- firmware/architecture match the tested target or are explicitly understood;
- the Beacon USB VID:PID is present;
- the bridge process exists;
- `/dev/cartographer` points to a PTY;
- the installed files match repository checksums;
- required config includes exist; and
- no printer IP, password, MCU serial, or another machine's calibration was copied into public/reference files.

## 2. Klipper startup

Restart Klipper. Confirm it reaches `ready` without:

- duplicate macro sections;
- unknown `[beacon]` or `[beacon_guard]` sections;
- missing `KAMP/Adaptive_Meshing.cfg`;
- missing `/dev/cartographer`; or
- references to the removed `[prtouch_v3]` object.

Do not move the printer if Klipper is not ready.

## 3. Beacon status

From the console:

```gcode
BEACON_QUERY
BEACON_MCU_GUARD
```

Expected guard state is disarmed. Verify Beacon coil and MCU temperatures are plausible.

## 4. First Z reference and Contact calibration

Remove the build plate debris and filament ooze. Put the build plate in place.

```gcode
G28 X Y
BEACON_TOUCH_HOME
```

Watch for:

- correct X/Y directions;
- successful lower optical Z reference;
- nozzle centered at X175/Y175;
- controlled approach to the bed; and
- a completed Beacon model calibration.

Power off immediately if the bed/nozzle moves in an unexpected direction.

## 5. Z tilt and full mesh

```gcode
Z_TILT_ADJUST
G28 Z
BED_MESH_CALIBRATE ADAPTIVE=0 PROFILE=default
SAVE_CONFIG
```

Verify the toolhead stays within mechanical clearance at all mesh edges. A mount with different offsets needs different mesh limits.

## 6. DXC2 sensor and cutter

With the nozzle at a material-appropriate temperature:

1. operate the filament switch by hand and confirm state changes;
2. run the printer's cutter calibration while watching the extended actuator;
3. confirm the cutter fully severs filament rather than performing a cold pull; and
4. verify the measured contact falls inside the configured min/max window.

The reference machine is being corrected to `cut_pos_offset: 0.2` after a
watched unload revealed that `0.6` left a thin filament tail. Lower values
command more cutter travel on this firmware. Your saved position will differ;
do not reuse a saved `cut_pos_x` from another machine.

## 7. CFS load/unload

Use one visible, straight filament path first.

1. Load one slot.
2. Confirm filament passes the switch, enters both DXC2 drive stages, and extrudes.
3. Unload it.
4. Inspect for a flattened or chewed section.
5. Repeat twice, then repeat with a second slot.

If the first stage catches but the second does not, follow the `buffer_empty_len` tuning procedure in [`DXC2-CFS.md`](DXC2-CFS.md).

## 8. Start-sequence test

Slice a small, single-object print with object labeling enabled. Inspect the G-code header and confirm `EXCLUDE_OBJECT_DEFINE` appears before `START_PRINT`.

During startup confirm:

- guard disarms;
- CFS preflight completes;
- a missing/cleared mesh causes the full home, clean, Z tilt, re-home, and adaptive mesh path;
- the `kamp` profile becomes active;
- the guard arms only after mesh completion; and
- the selected CFS tool loads only after the start sequence reaches its tool command.

## 9. End-sequence test

At completion confirm:

- `DXC2_END_UNLOAD` reports a physical unload;
- the cutter actuates;
- filament leaves both DXC2 drive stages;
- CFS retracts cleanly; and
- Creality CFS bookkeeping completes afterward.

Then perform one watched cancel test with filament genuinely engaged in both
DXC2 drive stages. Confirm the bounded recovery does not exceed two attempts,
does not produce `RETRUDE_ERR6`/`key865`, and reports `DXC2 cleanup: filament
sensor restored`. Cutter-contact messages alone do not prove severance.

## 10. Acceptance criteria

Do not move to an unattended production print until all of the following pass:

- three consecutive Z homes;
- two full meshes without communication loss;
- three consecutive load/unload cycles on two different slots;
- one complete small print with adaptive mesh;
- one verified end-of-print unload; and
- one cold restart followed by successful Contact calibration.
