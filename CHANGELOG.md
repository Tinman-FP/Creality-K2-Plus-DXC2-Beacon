# Changelog

## Unreleased

- Added a validated, bounded DXC2 cancel/end recovery path that forces cutter
  motion when the CFS remains active after the toolhead switch clears.
- Added fresh post-unload verification, delayed CFS bookkeeping, a two-attempt
  limit, XY-only recovery homing, and unconditional filament-sensor cleanup.
- Corrected the cutter-depth direction after a real unload at `0.6` left a
  thin tail in the barrel. The live conservative starting value is now
  `cut_pos_offset: 0.2`, pending watched post-power-cycle calibration.
- Added a 300 ms settling pause after the DXC2's 40 mm local unload retract.
- Documented the `cfs empty print` tail-obstruction sequence and the separate
  closed-loop extruder-controller (`0x85`) startup-handshake fault.
- Verified the forced-actuation/retraction recovery path without
  `RETRUDE_ERR6`, `key865`, tangle, pause, or sensor-cleanup faults.
- Documented the captured failure timeline, safe homing recovery, and delayed
  CFS aggregate connection behavior after service restart.

## 2026-09-20

- Published the tested K2 Plus firmware 1.1.6.1 runtime and documentation.
- Added Beacon RevH userspace USB bridge integration.
- Added K2-specific Contact/proximity homing flow and KAMP adaptive meshing.
- Added guarded post-mesh Beacon dropout handling.
- Added staged `START_PRINT` mesh-state fix after CFS preflight.
- Added DXC2 physical end-of-print unload.
- Recorded final `Tn_retrude: -18`, `buffer_empty_len: 25.5`, and extended-cutter calibration window.
- Documented PTFE routing, CFS engagement, cutter, and repeated-load findings.
