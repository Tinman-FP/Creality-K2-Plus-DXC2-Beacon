# Changelog

## Unreleased

- Documented a captured abort where cutter contact/return reported success but
  the DXC2 did not sever the filament.
- Recorded the resulting `RETRUDE_ERR6` / `key865` timeline and confirmed that
  `Tn_retrude: -18` was not the initiating fault.
- Identified a recovery-state gap: cleanup relied on the late toolhead filament
  switch, skipped a second physical unload after it cleared, and left the
  sensor disabled.
- Added validation requirements for bounded recovery, fresh post-unload state
  evaluation, delayed CFS bookkeeping, and unconditional sensor restoration.
- Marked cutter-depth compensation changes as unvalidated pending a watched
  hardware test.

## 2026-09-20

- Published the tested K2 Plus firmware 1.1.6.1 runtime and documentation.
- Added Beacon RevH userspace USB bridge integration.
- Added K2-specific Contact/proximity homing flow and KAMP adaptive meshing.
- Added guarded post-mesh Beacon dropout handling.
- Added staged `START_PRINT` mesh-state fix after CFS preflight.
- Added DXC2 physical end-of-print unload.
- Recorded final `Tn_retrude: -18`, `buffer_empty_len: 25.5`, and extended-cutter calibration window.
- Documented PTFE routing, CFS engagement, cutter, and repeated-load findings.
