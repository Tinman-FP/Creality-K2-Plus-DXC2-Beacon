# DXC2/CFS lessons learned

This is the complete troubleshooting record behind the reference K2 Plus
configuration. It is deliberately longer than the install guide so another
owner can distinguish a mechanical feed restriction, incomplete cutter stroke,
and software sequencing failure instead of changing unrelated values.

## Original symptom

The printer could load or unload from the user interface, but an in-print
filament change sometimes left filament in the DXC2. Canceling the print then
moved to the cutter, severed the same filament, and retracted it successfully.
In a separate failure the CFS tripped the toolhead switch and entered the first
DXC2 drive stage, but stopped before the second stage. The printer then moved
as though it were printing without extruding.

Those observations matter:

- a true filament-switch state proves only that filament reached the switch;
- cutter contact/return messages prove actuator contact, not severance;
- a successful cancel unload does not prove the in-print toolchange calls the
  same heat/cut/retract sequence; and
- a CFS tangle can be genuine drag, overfeed, or an attempt to retract
  continuous filament that the cutter never severed.

## Hardware and path work completed first

The following were inspected or changed before accepting a software fix:

- correct DXC2 hardware and extended cutter actuator/plunger were verified;
- cutter plunger, pressure arm, blade path, sensor PCB, and PCB screw lengths
  were checked;
- PTFE was replaced and routed with larger bend radii;
- one printed guide that created resistance was removed;
- lid contact in the loading position was eliminated;
- one cable-chain link was removed to improve the toolhead entry angle;
- a repeatedly flattened section of filament was discarded;
- the CFS was temporarily replaced for isolation;
- the extruder motor and harness were replaced; and
- a dummy-motor/`STEPPER_BUZZ` isolation test confirmed the final motor,
  harness, toolboard step/dir path, and gears moved.

Measured PTFE segments at one stage were 570 mm CFS-to-buffer, 280 mm
buffer-to-printer, and 760 mm printer-inlet-to-extruder. They are diagnostic
history, not a cut list. The final route used one continuous buffer-to-extruder
tube. Tube drag and geometry mattered more than matching those lengths.

## Settings that were easy to misdiagnose

### `Tn_retrude`

The DXC2 guide starts at `-20`. The reference machine was smoother at `-18`,
which remains the validated value. Do not use this to compensate for an
incomplete cut: the CFS cannot retract unsevered filament cleanly regardless of
the retraction distance.

### `cut_pos_offset`

On Creality firmware 1.1.6.1, reducing the value adds post-contact cutter
travel. An early move to `0.6` was in the wrong direction and left a tail.
The reference machine was recalibrated at `0.1`. Change by only 0.1 mm,
recalibrate every time, and inspect the actual filament cut. Never copy the
saved `cut_pos_x` from another printer.

### `buffer_empty_len`

Lowering this value made the CFS feed farther on the tested firmware:

| Value | Observed result |
|---:|---|
| 30 | Stopped too early for reliable second-stage engagement |
| 12 | Fed far enough but overfed/reported a tangle |
| 21 | Intermediate recovery step |
| 25.5 | Appeared stable, but later could stop short of reliable pickup |
| **23.25** | Visible +40 mm extrusion and ten successful A/B print changes |

The correct number depends on the complete PTFE path. Approach it in 1–2 mm
steps, unload completely between attempts, and never reuse a section flattened
by a failed CFS drive attempt.

## Software gaps found

### In-print cutter ran before the nozzle reached the unload target

The failed sliced file held the nozzle at 240 C, then called the vendor tool
command. That command selected 250 C but started the cutter path without first
waiting at temperature. Cancel/unload heated first and then succeeded. The
wrapper now calls `BOX_SET_TEMP` and waits until the nozzle is within 2 C of
the selected target before cutting.

### A single stroke was not consistently severing filament

Every normal CFS cut is now two complete cutter strokes with a 50 mm X
clearance move between them. A 400 ms dwell follows the second stroke before
retraction. The forced recovery version uses the raw cutter move because the
vendor wrapper can skip a cut after the toolhead switch becomes clear.

### Retraction recovery needed to be bounded

The wrapper arms one watchdog around the vendor retraction. If and only if the
print is paused with filament still detected and a resume error present, it
invokes Creality's native recovery once. A second failure remains paused for
inspection. It never creates an unlimited retry loop.

### Tool aliases needed explicit physical-slot mapping

The slicer's `T0`–`T3` commands map to CFS 1 bays A–D. The wrapper skips a
duplicate request only when the requested physical bay is already active and
the toolhead sensor still detects filament. It also requires a positive sensor
state before purge/printing can continue.

The deployed implementation is
[`config/macros/dxc2_cfs_tool_alias.cfg`](../config/macros/dxc2_cfs_tool_alias.cfg).

## Final reference configuration

```ini
# box.cfg
Tn_retrude: -18
Tn_retrude_velocity: 600
buffer_empty_len: 23.25
check_cut_pos_x_min: -9.5
check_cut_pos_x_max: -5.0

# motor_control.cfg
cut_pos_offset: 0.1
```

The macro changes add:

- pre-cut temperature selection and wait;
- two cutter strokes separated by 50 mm;
- a 400 ms post-second-stroke dwell;
- physical T-command-to-CFS-slot mapping;
- a post-load sensor gate; and
- one bounded retraction recovery attempt.

These are reference-machine results, not universal defaults. Do not copy a
saved cutter contact position, CFS identity table, PID result, or material
temperature from another machine.

## Proof sequence used on 2026-09-24

1. Home the machine with the nozzle/purge area clear.
2. Use the vendor CFS load path for slot A.
3. Require the toolhead sensor to be true.
4. Heat to 250 C.
5. Command a relative +40 mm extrusion at 5 mm/s.
6. Physically verify filament exits the nozzle. The operator confirmed it.
7. Run the supplied five-layer qualification chip, which performs ten actual
   alternating `T0`/`T1` changes.
8. Watch every cut, retract, load, purge, and deposition event.
9. Require a verified final unload and safe heater shutdown.

The completed run recorded:

- print state `complete`;
- eleven pre-cut temperature waits (the initial duplicate-tool request plus
  ten changes);
- eleven double-cut sequences (ten changes plus the final unload);
- ten CFS A/B load transitions;
- zero watchdog retries;
- no pause or error;
- no `RETRUDE_ERR6` or `key865` in the qualification window;
- final unload attempt 1 verified;
- toolhead filament sensor false at completion; and
- nozzle and bed targets both 0 C.

The exact test is
[`tests/DXC2_double_cut_ten_swap_test.gcode`](../tests/DXC2_double_cut_ten_swap_test.gcode).
It assumes compatible material in CFS 1 slots A and B, a 0.4 mm nozzle, 250 C
nozzle target, and 80 C bed. Review it before use and stay at the printer.

## Recovery cautions

- Do not issue a second CFS command while a load/retract sequence is active.
  A concurrent RFID/info refresh caused a vendor `BOX_GET_RFID` exception
  during diagnostics even though it was unrelated to the mechanical fix.
- Do not accept sensor state as proof of extrusion. Watch a purge or inspect a
  printed two-color result.
- If the toolhead has been moved outside valid travel, power down and place it
  inside the work area before homing. Do not spoof coordinates.
- Keep an untouched backup of every edited file and re-verify after every
  Creality firmware update.
