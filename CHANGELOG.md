# Changelog

## Unreleased

- Captured a repeat in-print B → A retract failure: the slicer held the nozzle
  at 240 C while the vendor `T1` cutter path raised its target to 250 C and
  cut without waiting. Added an experimental pre-cut heat wait around the
  original `T0`–`T3` commands; a watched loaded toolchange is still required.
- Updated the recorded reference cutter offset to the calibrated `0.1` value
  and refreshed repository checksums.
- Added a validated, bounded DXC2 cancel/end recovery path that forces cutter
  motion when the CFS remains active after the toolhead switch clears.
- Added fresh post-unload verification, delayed CFS bookkeeping, a two-attempt
  limit, XY-only recovery homing, and unconditional filament-sensor cleanup.
- Corrected the cutter-depth direction after a real unload at `0.6` left a
  thin tail in the barrel. The conservative starting value is `0.2`; the
  reference printer was later calibrated at `0.1` after a watched failure.
- Added a 300 ms settling pause after the DXC2's 40 mm local unload retract.
- Documented the `cfs empty print` tail-obstruction sequence and the separate
  closed-loop extruder-controller (`0x85`) startup-handshake fault.
- Recorded the known-good dummy-motor isolation test: both motor assemblies
  were silent on the same cable, narrowing the `0x85` fault to the short motor
  cable, toolboard, or upstream toolhead harness.
- Documented the Beacon bridge boot race where USB is present but the running
  bridge fails to create `/dev/cartographer`.
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
