# Reference-machine live configuration snapshot

These files are the complete active K2 Plus configuration files touched during
the DXC2, CFS, Beacon, adaptive-mesh, start/end, and recovery work. They were
captured from the validated reference printer on 2026-09-24 after the successful
ten-change A/B qualification print.

> [!CAUTION]
> This directory is an audit/reference snapshot, not a drop-in configuration
> package. Do not copy the complete directory over another printer. Firmware
> revision, pins, travel limits, probe mount, cutter contact, PTFE path, CFS
> topology, PID values, and saved calibration all vary. Follow
> [`docs/INSTALL.md`](../../docs/INSTALL.md) and merge only the documented
> sections after making backups.

## Files

| File | Relevant changes represented |
|---|---|
| [`printer.cfg`](printer.cfg) | Includes for the CFS wrapper, Beacon, guard and KAMP; Beacon Z endstop path; verified heater and mesh geometry |
| [`sensorless.cfg`](sensorless.cfg) | K2 optical-bottom reference plus Beacon Contact/proximity homing flow |
| [`gcode_macro.cfg`](gcode_macro.cfg) | Staged print start, adaptive mesh/guard order, DXC2 40 mm retract, physical end/cancel unload and bounded recovery |
| [`box.cfg`](box.cfg) | `Tn_retrude: -18`, `buffer_empty_len: 23.25`, extended cutter window and direct-load `TNN` forwarding |
| [`motor_control.cfg`](motor_control.cfg) | Calibrated reference cutter compensation `cut_pos_offset: 0.1` |
| [`codex_cfs_tool_alias.cfg`](codex_cfs_tool_alias.cfg) | Physical T0–T3 bay mapping, pre-cut heat wait, double cut, 400 ms dwell, sensor gate and bounded watchdog |
| [`beacon_user.cfg`](beacon_user.cfg) | Measured Beacon offsets and K2 Contact/homing compatibility macros |
| [`beacon_guard.cfg`](beacon_guard.cfg) | Post-mesh, print-only Beacon communication policy |
| [`KAMP_Settings.cfg`](KAMP_Settings.cfg) | Adaptive-mesh settings used by the reference printer |
| [`KAMP/Adaptive_Meshing.cfg`](KAMP/Adaptive_Meshing.cfg) | Full adaptive mesh macro installed on the printer |

## Sanitization

Nine files are byte-for-byte copies of the active printer files. The public
`printer.cfg` copy ends immediately before Klipper's generated `SAVE_CONFIG`
block. That block was intentionally excluded because it contained:

- CFS auto-address identity bytes;
- this machine's saved cutter contact position;
- bed meshes and Beacon model coefficients;
- PID and input-shaper calibration; and
- nozzle/calibration values that must be generated on the destination printer.

No SSH credentials, access codes, IP addresses, Wi-Fi details, tokens, or API
keys are included.

## Recommended use

1. Read the smaller installable examples under [`config/`](../../config/).
2. Use this snapshot to understand surrounding stock macro context or audit the
   exact integration points.
3. Diff one file at a time against the matching file from your printer.
4. Merge only the relevant sections.
5. Recalibrate the cutter, Beacon, bed mesh, PID, and input shaping locally.
6. Run the complete [`validation checklist`](../../docs/VALIDATION.md) while
   physically present.
