# Rollback and firmware updates

## Runtime rollback

The runtime installer prints a backup directory such as:

```text
/mnt/UDISK/root/backups/k2_dxc2_beacon_YYYYMMDD_HHMMSS
```

To restore it:

```sh
cd /mnt/UDISK/root/Creality-K2-Plus-DXC2-Beacon
sh scripts/rollback-runtime.sh /mnt/UDISK/root/backups/k2_dxc2_beacon_YYYYMMDD_HHMMSS
```

The rollback helper restores runtime files and service state recorded by the installer. It does not automatically replace `printer.cfg`, `sensorless.cfg`, `box.cfg`, or `gcode_macro.cfg`, because those files may have changed after installation.

Restore configuration files manually from the dated backup you made immediately before editing them, then restart Klipper.

## Emergency recovery

If Klipper will not start:

1. do not home or move the machine;
2. SSH to the printer;
3. inspect the end of `/mnt/UDISK/printer_data/logs/klippy.log`;
4. remove only the new include lines if the error names a missing/invalid section;
5. restore the exact pre-change `homing.py` and config backups; and
6. restart Klipper.

Do not delete the whole printer configuration or `SAVE_CONFIG` block.

## After every Creality firmware update

Record the new firmware version, then verify:

- `/etc/init.d/beacon` exists, is enabled, and points to the correct binary;
- `/mnt/UDISK/bin/beacon_usb_bridge` retains the published checksum;
- `/usr/share/klipper/klippy/extras/beacon.py` points to the version-pinned module;
- `beacon_guard.py` still exists;
- `homing.py` still contains the `BEACON` branch;
- `printer.cfg` still includes the Beacon/KAMP files;
- `[prtouch_v3]` has not been re-enabled alongside Beacon;
- `sensorless.cfg` still uses the two-stage Z reference flow;
- `box.cfg` retains the intended DXC2 values;
- `gcode_macro.cfg` retains staged start and physical end unload; and
- Klipper reaches `ready` with no warnings.

Do not automatically copy a `1.1.6.1` runtime file over a newer firmware. Diff the new vendor file and reapply only the small compatibility changes.
