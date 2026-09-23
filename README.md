# Creality K2 Plus DXC2 + Beacon

Field-tested configuration, runtime files, macros, and troubleshooting notes for a Creality K2 Plus Combo fitted with:

- a Phaetus / D3vil Design DXC2 dual-drive extruder;
- the DXC2 extended cutter actuator;
- a Creality CFS;
- a USB Beacon RevH bed scanner;
- adaptive per-object bed meshing; and
- a guarded post-mesh Beacon failure policy.

This repository records the complete working approach developed on a real K2 Plus. It is not an official Creality, Phaetus, D3vil Design, or Beacon product.

> [!WARNING]
> These changes replace the stock strain-gauge Z probe path and modify homing, CFS loading, cutter calibration, and print start/end behavior. A wrong probe offset, homing edit, or cutter value can cause a collision. Back up every file, keep the bed clear, remain at the printer during commissioning, and test one subsystem at a time.

## Tested system

| Component | Tested value |
|---|---|
| Printer | Creality K2 Plus Combo |
| Creality firmware | `1.1.6.1` |
| Klipper fork | `09faed31-dirty` |
| Host | 32-bit ARMv7, OpenWrt 21.02 snapshot, Linux 5.4.61 |
| CFS firmware | `1.4.2` |
| Extruder | DXC2 with extended cutter actuator |
| Probe | Beacon RevH, USB VID:PID `04d8:e72b` |
| Beacon mount measurement | X `0`, Y `-25.703`; coil is approximately 2.6 mm above nozzle tip |
| Bridge device | `/dev/cartographer` |

Firmware updates can overwrite `/usr/share/klipper`, `/etc/init.d`, and printer configuration files. Re-run the verification checklist after every Creality update.

## What this solves

### DXC2 and CFS

- Applies the manufacturer-required 40 mm extruder retract during unload.
- Records the manufacturer starting value `Tn_retrude: -20` and our smoother tested value `-18`.
- Tunes CFS handoff so filament reaches the DXC2's second drive stage instead of stopping after the filament switch/first gear.
- Accounts for PTFE length, bend radius, guide friction, lid contact, and cable-chain geometry.
- Expands the cutter-calibration window for the extended actuator.
- Performs a real CFS unload at print completion instead of only CFS bookkeeping.

### Beacon

- Bridges Beacon USB on the K2's kernel, which does not expose the probe through `cdc_acm`.
- Integrates Beacon Contact with Creality's bottom optical Z reference and dual-Z mechanics.
- Adds Z tilt, full-bed calibration, and adaptive per-object meshing.
- Reduces host load by decimating the high-rate Beacon stream while leaving firmware-side contact detection at native rate.
- Uses a longer multi-MCU synchronization timeout suitable for the userspace USB-to-PTY bridge.
- Can allow an active print to continue after an *idle, post-mesh* Beacon dropout while still requiring Beacon for homing and probing.
- Rechecks the live mesh state after CFS preflight so the Beacon guard cannot arm against a mesh that was cleared during startup.

## Repository map

| Path | Purpose |
|---|---|
| [`docs/DXC2-CFS.md`](docs/DXC2-CFS.md) | DXC2 installation deltas, CFS engagement tuning, cutter calibration, and PTFE findings |
| [`docs/BEACON.md`](docs/BEACON.md) | Beacon architecture, offsets, homing flow, mesh limits, and calibration |
| [`docs/INSTALL.md`](docs/INSTALL.md) | Backup-first installation procedure |
| [`docs/VALIDATION.md`](docs/VALIDATION.md) | Commissioning tests and expected results |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Symptoms, causes, and corrections found during testing |
| [`docs/ROLLBACK.md`](docs/ROLLBACK.md) | Recovery and firmware-update checklist |
| [`config/dxc2/`](config/dxc2/) | Small DXC2/CFS edits; these are intentionally not a full machine config |
| [`config/macros/`](config/macros/) | Start, end, calibration, and guard macro references |
| [`config/beacon_user.cfg.example`](config/beacon_user.cfg.example) | Tested Beacon configuration; offsets must match your mount |
| [`runtime/firmware-1.1.6.1/`](runtime/firmware-1.1.6.1/) | Version-pinned Klipper runtime files used by the tested machine |
| [`bin/armv7l/beacon_usb_bridge`](bin/armv7l/beacon_usb_bridge) | Tested ARMv7 USB-to-PTY bridge |
| [`scripts/`](scripts/) | Runtime installer, verifier, checksum generator, and rollback helper |

## Fast path

Read the full installation guide before running anything.

1. Clone this repository on another computer:

   ```sh
   git clone https://github.com/Tinman-FP/Creality-K2-Plus-DXC2-Beacon.git
   ```

2. Copy it to your printer, replacing `PRINTER_IP`:

   ```sh
   scp -r Creality-K2-Plus-DXC2-Beacon root@PRINTER_IP:/mnt/UDISK/root/
   ```

3. On the printer, stage the version-pinned runtime:

   ```sh
   cd /mnt/UDISK/root/Creality-K2-Plus-DXC2-Beacon
   sh scripts/install-runtime.sh
   ```

   The installer creates a dated backup, verifies the architecture and firmware, installs the Beacon bridge/runtime, and starts the bridge. It deliberately does **not** restart Klipper or overwrite `printer.cfg`, `sensorless.cfg`, `box.cfg`, or `gcode_macro.cfg`.

4. Follow [`docs/INSTALL.md`](docs/INSTALL.md) to merge the configuration and macros.

5. Run the read-only verifier:

   ```sh
   sh scripts/verify.sh
   ```

6. With the build plate clear and while physically present, restart Klipper and follow [`docs/VALIDATION.md`](docs/VALIDATION.md).

## Tested DXC2 values

These are the current tested values on the reference machine, not universal defaults:

```ini
# box.cfg
Tn_retrude: -18
buffer_empty_len: 25.5
check_cut_pos_x_max: -5.0
check_cut_pos_x_min: -9.5
# motor_control.cfg
cut_pos_offset: 0.1
```

The official DXC2 instructions use `Tn_retrude: -20`. On the reference machine, `-18` produced a smoother load/unload transition. The final `buffer_empty_len: 25.5` was reached by tuning in halves after a large correction fed too far and triggered a tangle fault. See [`docs/DXC2-CFS.md`](docs/DXC2-CFS.md) before changing either value.

## Critical slicer requirement

Adaptive meshing needs object geometry before `START_PRINT`. Confirm your G-code contains one or more `EXCLUDE_OBJECT_DEFINE` commands before:

```gcode
START_PRINT EXTRUDER_TEMP=... BED_TEMP=...
```

If object definitions are missing, the supplied KAMP macro falls back to the configured full mesh area.

## Validated cancel/unload recovery

A captured abort on 2026-09-20 exposed a cutter/recovery edge case: the K2
reported cutter contact and return even though the filament was not severed.
Retraction failed, later cleanup trusted an already-clear toolhead switch, and
the filament sensor remained disabled.

The reference machine adds a 300 ms settling
pause after the local `E-40` retract, and retains the bounded recovery macro.
On this firmware, reducing the offset commands more cutter travel after the
contact calibration; the previous `0.6` experiment moved in the wrong
direction. The macro forces the physical cutter move when the CFS still owns the
path but the toolhead switch has cleared, waits for that move before
retraction, freshly verifies the result, delays CFS bookkeeping until success,
and restores the filament sensor on every terminal path. The recovery sequence
completed without `RETRUDE_ERR6`, `key865`, a tangle, or a pause fault.

Cutter contact still proves actuator contact—not filament severance. On
2026-09-22, an in-print PCTG change failed retraction after the `0.2` cutter
stroke reported contact/return. The reference machine was recalibrated, then
changed to `0.1` and recalibrated again. One watched CFS 1 slot B → A change
then cut, retracted, loaded, and purged without a fault. This is one successful
cycle, not proof that every future cut will succeed. See
[`docs/DXC2-CFS.md`](docs/DXC2-CFS.md#captured-abort-and-cutter-failure).

The same session exposed a separate Creality macro bug: direct
`BOX_LOAD_MATERIAL TNN=T1B` did not forward `TNN` into its nested feed/flush
macros and shut Klipper down with `KeyError: None`. The reference machine now
forwards the optional parameter; see
[`config/dxc2/box-load-tnn-forward.cfg.example`](config/dxc2/box-load-tnn-forward.cfg.example).

## Support boundaries

- Only firmware `1.1.6.1` is represented by the supplied version-pinned runtime files.
- Do not copy the reference machine's saved Beacon model, bed mesh, PID values, CFS serial/auto-address table, or input-shaper values.
- Measure your own Beacon X/Y offsets and run your own Contact/model calibration.
- `Tn_extrude_temp` is material-dependent. The reference machine currently uses `260 C` for its high-temperature workflow; that is not a general DXC2 requirement and is unsuitable as a universal default.
- The Beacon communication guard is optional. It must be disarmed for every home, probe, Z tilt, and mesh operation.

## Upstream references

- [Beacon documentation](https://docs.beacon3d.com/)
- [Beacon Klipper module](https://github.com/beacon3d/beacon_klipper)
- [Phaetus DXC2 models and adapters](https://github.com/Phaetus/DXC-2-Extruder)
- [Creality CFS loading/unloading guide](https://wiki.creality.com/en/k2-flagship-series/k2-plus/cfs-filament)
- [Creality Community: DXC2 setup values and `cut_pos_offset: 0.2`](https://forum.creality.com/t/please-help-with-the-dxc2/50837)
- [Creality Community: incomplete-cut tail and cutter-rod spacer findings](https://forum.creality.com/t/k2-pro-dxc2-filament-sensor-issues/51178)
- [Creality Community: stock cutter blade and DXC2 installation findings](https://forum.creality.com/t/how-to-install-the-dxc2-extruder-on-creality-k2-plus/49894?page=2)
- [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging)

## License and attribution

Original work in this repository is released under GPL-3.0. Beacon-derived runtime code retains its upstream copyright and GPL-3.0 terms. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
