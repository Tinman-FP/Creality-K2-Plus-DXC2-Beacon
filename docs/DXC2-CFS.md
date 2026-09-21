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

With `cut_pos_offset: 0.6`, the extended actuator made repeatable calibration
contact at X=-6.00 and saved `cut_pos_x: -5.40`. The earlier `0.4` offset had
saved `cut_pos_x: -5.30`, so the final setting added 0.10 mm of physical cutter
travel. The stock maximum of -5.5 rejected the earlier otherwise-repeatable
result, so the maximum remains -5.0. Always watch cutter calibration and use
the smallest window change that contains the repeatable physical trigger.

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

1. preserves CFS ownership even if the late toolhead switch clears;
2. uses the normal `BOX_QUIT_MATERIAL` path when filament is detected;
3. directly forces the cutter move before retracting when the CFS path is
   active but the toolhead switch is already clear;
4. waits for movement and freshly evaluates filament/error state;
5. permits no more than two attempts;
6. delays `BOX_END` and `BOX_END_PRINT` until verification succeeds; and
7. restores the filament sensor on complete, cancel, and error paths.

See [`config/macros/dxc2_end_unload.cfg`](../config/macros/dxc2_end_unload.cfg).

## Captured abort and cutter failure

A later real-world abort exposed a second, distinct gap.  The reference K2 was
printing without extrusion because of a mechanical fault.  After that fault
was corrected, the print was aborted and the unload failed.  The operator
observed that the filament was not cut.

The Klipper/CFS log established this sequence (printer log clock):

| Time | Event |
|---|---|
| 19:44:58 | `DXC2_END_UNLOAD` began the heat/cut/retract sequence |
| 19:45:05 | K2 reported `[box] cut sensor detected` |
| 19:45:08 | K2 reported `[box] cut to return OK` |
| 19:45:14, 19:45:20, 19:45:27 | CFS repeatedly attempted the configured `-18 mm` retract |
| 19:45:46 | CFS reported `RETRUDE_ERR6` |
| 19:46:05 | Fault `key865`: `retrude error, failed to exit connections` |
| 19:46:57 | Toolhead filament-switch state finally changed to false |
| 19:47:12 | Cancel cleanup skipped the physical unload because the switch was already false |

The cutter messages confirm X-axis contact with the cutter actuator and a
successful return move.  They do **not** sense or prove that filament was
severed.  The saved contact position was `cut_pos_x: -5.30`, while the stock
`motor_control.cfg` cutter-depth compensation remained:

```ini
cut_pos_offset: 0.4
```

The reference machine was changed to:

```ini
cut_pos_offset: 0.6
```

`CALIBRATE_CUT_POS` then completed at contact X=-6.00 and saved the compensated
`cut_pos_x: -5.40`. Compared with the previous saved -5.30 value, this produced
0.10 mm more physical cutter travel. Do not increase the offset indefinitely;
verify blade, plunger, pressure arm, and sensor-board mechanics first.

The software-recovery gap is also now explicit.  The published macro requires
all of these states before calling `BOX_QUIT_MATERIAL`:

```text
CFS enabled AND CFS filament state active AND toolhead filament switch true
```

After a failed retract, the toolhead switch can become false while filament is
still mechanically retained in the DXC2.  The second cleanup then performs
only CFS bookkeeping.  In this captured failure, the filament switch was also
left disabled after cancellation.

The replacement recovery logic now:

1. preserves CFS-path ownership rather than relying only on the late switch;
2. distinguishes normal completion from a failed/incomplete retract;
3. permits one controlled recovery after the first attempt;
4. directly calls `BOX_MOVE_TO_CUT` because the vendor wrapper can skip the
   cut when the toolhead switch is already clear;
5. limits automatic attempts to two;
6. restores the filament sensor on every terminal path; and
7. delays `BOX_END`/`BOX_END_PRINT` until fresh post-unload evaluation.

The watched forced-recovery test homed X/Y, heated to 250 C, completed the
explicit cutter motion, retracted the CFS path, parked at X225/Y345, verified
no resume/tangle fault, and restored the filament sensor. It produced no
`RETRUDE_ERR6` or `key865`. Because filament was probably already absent after
the earlier recovery attempt, this validates the forced-actuation, retraction,
verification, and cleanup path; the first installed real-filament cancel/end
cycle must still be watched to verify actual severance.

Recovery homes only X and Y. If the toolhead has physically been moved outside
normal travel, power down and place it inside the valid work area before
homing. Do not spoof coordinates. On the reference machine, centering the head
resolved the homing failure and the recovery test then completed normally.

`Tn_retrude: -18` should not be changed on the evidence from this event alone.
The cutter failure occurred first, so the repeated retracts were acting on
continuous, uncut filament.

## Cutter calibration

Before changing software, confirm:

- the extended DXC2 actuator/plunger is installed in the correct orientation;
- the plunger moves freely and returns fully;
- the cutter blade is installed and actually cuts rather than cold-pulling filament;
- the cutter sensor PCB and connector are seated;
- the sensor board mounting screws are the correct lengths; and
- the pressure arm and PTFE inlet are aligned.

The calibration can visibly actuate the cutter and still fail if the measured X contact falls just outside the configured acceptance window.

The inverse is also true: a calibration or cut cycle can report successful
contact and return without proving the blade actually severed the filament.
