# Changelog

## Unreleased

- Added a validated, bounded DXC2 cancel/end recovery path that forces cutter
  motion when the CFS remains active after the toolhead switch clears.
- Added fresh post-unload verification, delayed CFS bookkeeping, a two-attempt
  limit, XY-only recovery homing, and unconditional filament-sensor cleanup.
- Calibrated `cut_pos_offset: 0.6`; contact was X=-6.00 and the saved
  compensated `cut_pos_x` was -5.40.
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
