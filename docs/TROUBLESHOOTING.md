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
| K2 reports cutter contact/return OK but filament remains continuous | Contact feedback confirms actuator/X contact, not filament severance; cutter overtravel may be insufficient | Do not tune `Tn_retrude` first. Verify the blade and plunger, retain the calibrated `cut_pos_x`, then test `cut_pos_offset` in watched 0.2 mm increments |
| Filament remains after print but manual unload works | End macro only ran `BOX_END` bookkeeping | Install `DXC2_END_UNLOAD` before `BOX_END`/`BOX_END_PRINT` |
| Cancel cleanup says `no CFS filament detected` after a failed retract | The toolhead switch cleared before cleanup even though filament may remain in the DXC2 | Do not assume unload succeeded. Inspect the extruder and CFS path; use the tracked open recovery issue before changing the macro |
| Filament sensor is disabled after a failed unload/cancel | Error path did not restore the sensor | Re-enable and verify the sensor before another print; the replacement cancel path must restore it unconditionally |
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
