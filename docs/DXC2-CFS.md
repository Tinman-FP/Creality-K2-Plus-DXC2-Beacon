# DXC2 and CFS findings

## Manufacturer-required changes

The DXC2 installation guide changes two values because its filament path differs from the original K2 Plus extruder.

In the existing `QUIT_MATERIAL_RETRUDE_MATERIAL` macro:

```gcode
G0 E-40 F360
```

In `box.cfg`:

```ini
Tn_retrude: -20
```

Keep those as the baseline. The complete small snippets are in [`config/dxc2`](../config/dxc2).

## Reference-machine final values

After repeated observed load/unload tests, the reference machine settled on:

```ini
Tn_retrude: -18
buffer_empty_len: 25.5
check_cut_pos_x_max: -5.0
check_cut_pos_x_min: -9.5
```

`Tn_retrude: -18` is an important final correction made after the main test session. It loaded more smoothly than `-20` on this machine. Treat it as a tested result, not a universal requirement.

The cutter's repeatable contact was approximately X=-5.3 with the extended actuator. The stock maximum of -5.5 rejected that otherwise repeatable result, so the maximum was changed to -5.0. Always watch the cutter calibration and use the smallest window change that contains the repeatable physical trigger point.

## How CFS engagement fails with DXC2

The filament switch can trigger while filament has only entered the first DXC2 drive stage. The CFS then changes behavior based on its expected remaining path. If the extra feed is too short, the filament never reaches the second drive stage and the extruder cannot take over. If it is too long, the CFS can compress the filament path and report a tangle.

On the reference machine:

- `buffer_empty_len: 30` stopped too early for reliable second-stage engagement;
- a large correction to `12` fed far enough but produced an overfeed/tangle condition;
- half the correction returned to `21`;
- half of the remaining correction returned to `25.5`, which became the stable value.

This empirical result means decreasing `buffer_empty_len` made the CFS feed farther in this firmware. Change it in 1-2 mm steps once you are close. Do not jump straight to `12`.

## PTFE path findings

Measured segments during troubleshooting were:

- CFS to buffer: 570 mm;
- buffer to printer: 280 mm; and
- printer inlet to extruder: 760 mm.

Those measurements describe one stage of the installation, not a universal cut list. The final setup replaced the buffer-to-extruder route with one continuous tube and changed tube brand and routing.

The failures were strongly affected by mechanics:

- a printed guide added drag;
- the PTFE rubbed the lid in the loading position;
- filament repeatedly flattened at the same high-resistance location;
- a tight bend near the toolhead caused binding roughly 20 mm before the extruder;
- changing tube brand changed drag substantially;
- removing one cable-chain link improved the entry geometry; and
- replacing the CFS did not fix a downstream PTFE/extruder-entry restriction.

Correct the path before compensating in software. A smooth, large-radius route is more important than reproducing another machine's exact length.

## Tuning procedure

1. Use straight, undamaged filament with the nozzle hot enough for the material.
2. Remove unnecessary guides and verify the tube does not touch the lid through the full XY travel.
3. Confirm the transferred filament switch changes state reliably.
4. Load one CFS slot while watching the final 100 mm of travel.
5. If filament stops before the second gear, reduce `buffer_empty_len` 1-2 mm.
6. If it reaches the second gear but buckles, chatters, or reports a tangle, increase the value 1-2 mm.
7. Unload fully between tests so repeated attempts do not reuse a flattened section.
8. Repeat with at least two CFS slots.
9. Only after engagement is stable, tune `Tn_retrude` around the manufacturer baseline.

## Temperature note

The reference machine currently contains:

```ini
Tn_extrude_temp: 260
```

That was used in a high-temperature-material workflow and is **not** a general DXC2 value. The manufacturer configuration used 220 C. Choose a load/unload temperature appropriate for the installed filament; do not expose PLA or other low-temperature material to an unnecessary 260 C unload cycle.

## End-of-print unload gap

The stock end macro called only:

```gcode
BOX_END
BOX_END_PRINT
```

Those commands completed CFS bookkeeping but did not consistently execute the proven manual unload path. Manual unload worked because `BOX_QUIT_MATERIAL` heats, actuates the cutter, retracts, and parks.

The supplied `DXC2_END_UNLOAD` macro:

1. checks that the CFS is enabled and filament is detected;
2. calls `BOX_QUIT_MATERIAL`;
3. waits for motion completion; and
4. then calls `BOX_END` and `BOX_END_PRINT`.

See [`config/macros/dxc2_end_unload.cfg`](../config/macros/dxc2_end_unload.cfg).

## Cutter calibration

Before changing software, confirm:

- the extended DXC2 actuator/plunger is installed in the correct orientation;
- the plunger moves freely and returns fully;
- the cutter blade is installed and actually cuts rather than cold-pulling filament;
- the cutter sensor PCB and connector are seated;
- the sensor board mounting screws are the correct lengths; and
- the pressure arm and PTFE inlet are aligned.

The calibration can visibly actuate the cutter and still fail if the measured X contact falls just outside the configured acceptance window.
