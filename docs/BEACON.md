# Beacon integration

## Why a USB bridge is required

The tested K2 Plus firmware sees Beacon through `lsusb` but does not provide a kernel `cdc_acm` serial device. The included ARMv7 userspace bridge opens Beacon directly through libusb, creates a PTY, and links it as:

```text
/dev/cartographer -> /dev/pts/N
```

The OpenWrt service respawns the bridge after a USB disconnect.

Tested USB identity:

```text
04d8:e72b Beacon Beacon RevH
```

## Measured mount geometry

The reference mount was measured as:

- X offset: `0` mm;
- Y offset: `-25.703` mm (coil forward of the nozzle); and
- coil approximately `2.6` mm above the nozzle tip.

Only X/Y are entered directly. Contact/model calibration determines the vertical relationship.

## Host-load changes

The K2 host is a dual-core 32-bit ARMv7 system with about 500 MB RAM. Full-rate Beacon position reconstruction can consume enough CPU to destabilize the userspace bridge. The tested configuration uses:

```ini
trsync_timeout: 0.25
stream_sample_decimation: 8
accel_enable: False
```

`stream_sample_decimation` reduces host processing of streamed measurement samples. Beacon firmware-side contact/homing detection still operates at its native rate. The accelerometer is disabled in this build to preserve headroom; enable it only after verifying CPU and MCU stability.

## Z homing sequence

The K2 bed can be anywhere after a restart, and Creality's fork assigns a synthetic high Z position during its normal sequence. A slow Beacon Contact move from an unknown position is unsafe and can also exceed multi-MCU synchronization timing.

The tested first-Z-home sequence is:

```text
X/Y home
  -> stock lower optical Z reference (ZDOWN)
  -> normal-speed move to Z=20
  -> nozzle centered at X175/Y175
  -> BEACON_AUTO_CALIBRATE
  -> move to Z=5
```

Later Z homes use proximity:

```text
coil centered over X175/Y175
  -> stage at Z=5
  -> G28 Z BEACON=1
```

The small `homing.py` compatibility change ensures the `BEACON=1` path uses the Beacon virtual endstop instead of routing that synthetic Z home through Creality's lower optical Z-align routine.

## Adaptive mesh

The configured maximum mesh is 31 x 31, but KAMP reduces it to the current object footprint plus a 5 mm margin. For the reference geometry:

```ini
mesh_min: 10,5
mesh_max: 340,325
probe_count: 31,31
zero_reference_position: 175,175
```

The slicer must emit `EXCLUDE_OBJECT_DEFINE` before `START_PRINT`. Otherwise KAMP cannot see the object polygon and will mesh the full configured area.

## Beacon guard

Beacon is essential during homing, Z tilt, and mesh generation. Once an active print has a valid mesh, Beacon is no longer needed for ordinary toolpath execution.

The optional `beacon_guard.py` module is therefore deliberately narrow:

- it patches only the Beacon MCU timeout path;
- it starts disarmed;
- it refuses to arm if Beacon is disconnected;
- it refuses to arm while Beacon is streaming;
- it requires an active bed-mesh profile;
- it requires print state `printing` or `paused`; and
- after an ignored dropout, Klipper must be restarted before any later home or mesh.

All homing/calibration macros begin with:

```gcode
BEACON_MCU_GUARD ENABLE=0
```

The start macro arms it only after the mesh:

```gcode
BEACON_MCU_GUARD ENABLE=1
```

Do not use `FORCE=1` in normal operation.

## The staged-start fix

A real print failed with:

```text
Cannot arm Beacon MCU guard until a bed mesh is active
```

The job stopped before layer one with zero filament used. The slicer G-code was valid: object definitions preceded `START_PRINT`. The defect was Klipper macro timing:

1. the single start macro rendered Jinja while a previous mesh and `PRINT_PREPARED` flag were present;
2. it queued `BOX_START_PRINT`;
3. CFS/preflight homing cleared the active mesh;
4. the already-rendered macro skipped adaptive calibration; and
5. the guard correctly refused to arm.

The fix splits the sequence:

```text
START_PRINT
  -> disarm guard
  -> BOX_START_PRINT
  -> _CODEX_START_PRINT_AFTER_BOX
       -> freshly evaluate prepare flag and mesh profile
       -> force full preparation if either is invalid
       -> arm guard only after mesh completion
```

This preserves both CFS behavior and the Beacon safety check.

## Calibration commands

With the bed clear and while present at the machine:

```gcode
BEACON_TOUCH_HOME
Z_TILT_ADJUST
G28 Z
BED_MESH_CALIBRATE ADAPTIVE=0 PROFILE=default
SAVE_CONFIG
```

For normal sliced prints, use the supplied start macro and `PROFILE=kamp` adaptive mesh.
