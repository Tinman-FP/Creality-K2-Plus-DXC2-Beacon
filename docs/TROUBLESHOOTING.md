# Troubleshooting

| Symptom | Likely cause | Correction |
|---|---|---|
| Beacon is visible in `lsusb` but no serial device exists | K2 kernel lacks usable `cdc_acm` path | Start the included USB bridge and verify `/dev/cartographer` |
| `/dev/cartographer` disappears after reconnect | Bridge/service stopped or failed to reclaim USB | Restart `/etc/init.d/beacon`; inspect `logread` |
| Multi-MCU homing timeout | Userspace bridge latency or an excessively long synchronized Z move | Use `trsync_timeout: 0.25`, establish Z with `ZDOWN`, stage at Z=20/5, and avoid a full-height Contact move |
| K2 host load spikes during mesh | Full-rate Beacon stream position reconstruction | Use `stream_sample_decimation: 8`; leave accelerometer disabled initially |
| `Cannot arm Beacon MCU guard until a bed mesh is active` | Mesh was cleared after a stale prepare/mesh check | Install the two-stage start macro; do not disable the guard |
| Start skips adaptive mesh | `PRINT_PREPARED`/mesh state was evaluated before CFS preflight, or slicer omitted object definitions | Use staged start; confirm `EXCLUDE_OBJECT_DEFINE` precedes `START_PRINT` |
| Filament trips switch but DXC2 cannot pull | Filament reached only the first gear | Reduce `buffer_empty_len` gradually and remove PTFE drag |
| CFS reports tangle after filament reaches second gear | Extra feed is too long or path is binding | Increase `buffer_empty_len` 1-2 mm and inspect tube geometry |
| Failure repeats at same filament location | Filament was flattened by earlier attempts | Fully unload, cut off damaged filament, then retry |
| Load changes when lid is installed | PTFE rubs lid or bend radius collapses | Reroute tube, add appropriate clearance/riser, and retest full XY travel |
| New CFS behaves exactly like old CFS | Restriction is downstream of CFS | Inspect buffer, PTFE, printer inlet, cable chain, and extruder entry |
| Cutter visibly moves but calibration fails | Extended actuator contact is just outside stock X window | Verify mechanics, observe repeatable contact, then adjust `check_cut_pos_x_max` minimally |
| K2 reports cutter contact/return OK but filament remains continuous or leaves a tail | Contact feedback confirms actuator/X contact, not filament severance; cutter travel may be insufficient | Do not tune `Tn_retrude` first. Verify cutter mechanics, lower `cut_pos_offset` in 0.1 mm steps, restart, recalibrate, and inspect the cut after every test. The reference machine is currently at `0.2` |
| Tail remains in the barrel and blocks the next load | Incomplete severance followed by CFS retraction folded the tail into the filament path | Clear the remnant, verify blade/cover/actuator travel, use the corrected cutter offset, add `G4 P300` after `G0 E-40 F360`, then run a watched unload before printing |
| Homing says motor parameters are still initializing | One or more closed-loop motor controllers did not finish the startup handshake; address `0x85` is the extruder controller on the reference machine | Do not command motion. Fully power-cycle the printer; if `0x85` remains absent, reseat and inspect the DXC2 extruder-motor/board connection |
| Filament remains after print but manual unload works | End macro only ran `BOX_END` bookkeeping | Install `DXC2_END_UNLOAD` before `BOX_END`/`BOX_END_PRINT` |
| Cancel cleanup previously said `no CFS filament detected` after a failed retract | The toolhead switch cleared before cleanup even though the CFS still owned the path | Install the bounded `DXC2_END_UNLOAD` recovery. It forces the cut/retract path from CFS ownership and verifies fresh state before bookkeeping |
| Filament sensor is disabled after a failed unload/cancel | Stock error path did not restore the sensor | Install the delayed restore supplied with `DXC2_END_UNLOAD`; verify `QUERY_FILAMENT_SENSOR SENSOR=filament_sensor` before another print |
| Recovery homing fails or the head travels into a rear obstruction | The toolhead was physically outside normal travel before homing, or its path is obstructed | Power down if needed, place the head inside the valid work area, clear the obstruction, then home X/Y. Never spoof coordinates |
| CFS shows disconnected for several minutes after a host restart although its serial link is present | Creality's aggregate CFS state can lag the T1 connection during startup | Wait for the aggregate state to become connected before testing. If it never does, inspect logs and restart the printer service once |
| Cold pull instead of clean unload | Cutter blade/actuator did not fully sever filament | Stop software tuning and repair cutter mechanics first |
| Klipper fails after Creality firmware update | Update replaced Klipper extras, homing, init service, or config | Compare against the dated backup and follow [`ROLLBACK.md`](ROLLBACK.md) |

## Useful read-only commands

```sh
cat /mnt/UDISK/creality/userdata/config/system_version.json
uname -a
lsusb | grep -i '04d8:e72b'
ls -l /dev/cartographer
ps | grep '[b]eacon_usb_bridge'
logread | grep -Ei 'beacon|cartographer|usb bridge' | tail -n 100
```

Klipper console:

```gcode
BEACON_QUERY
BEACON_MCU_GUARD
QUERY_FILAMENT_SENSOR SENSOR=filament_sensor
```

If the guard reports that it ignored a Beacon timeout, finish or cancel the active print as appropriate, then restart Klipper before any homing, Z tilt, or mesh command.
