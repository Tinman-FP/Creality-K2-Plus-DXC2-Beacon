"""Permit an active print to survive an idle post-mesh Beacon dropout.

Beacon remains critical while Klipper is homing or probing.  The print-start
macro explicitly arms this guard only after a bed mesh has completed.  This
module supports both current Klipper's MCU connection timeout path and the
older Qidi Plus 4 MCU.check_active() path.
"""

import logging


class BeaconMCUGuard:
    cmd_BEACON_MCU_GUARD_help = (
        "Arm or disarm the post-mesh Beacon communication guard"
    )

    def __init__(self, config):
        self.printer = config.get_printer()
        self.gcode = self.printer.lookup_object("gcode")
        self.mcu_name = config.get("mcu", "beacon").strip()
        self.require_mesh = config.getboolean("require_mesh", True)
        self.require_active_print = config.getboolean(
            "require_active_print", True
        )
        self.armed = False
        self.timeout_ignored = False
        self.timeout_ignored_at = 0.0
        self.mcu = None
        self.conn = None
        self.beacon = None
        self.patch_mode = ""
        self.original_check_timeout = None
        self.original_check_active = None
        self.printer.register_event_handler("klippy:ready", self._handle_ready)
        self.gcode.register_command(
            "BEACON_MCU_GUARD",
            self.cmd_BEACON_MCU_GUARD,
            desc=self.cmd_BEACON_MCU_GUARD_help,
        )

    def _handle_ready(self):
        object_name = "mcu " + self.mcu_name
        self.mcu = self.printer.lookup_object(object_name)
        self.beacon = self.printer.lookup_object(self.mcu_name, None)

        # Klipper v0.13 and newer place timeout handling on the shared MCU
        # connection helper.  Qidi's older v0.12 fork handles it directly in
        # MCU.check_active().  Patch only the selected Beacon MCU instance.
        candidate = getattr(self.mcu, "_conn_helper", None)
        if candidate is not None and hasattr(candidate, "check_timeout"):
            owner = getattr(candidate, "_codex_beacon_guard_owner", None)
            if owner is not None and owner is not self:
                raise self.printer.config_error(
                    "Beacon MCU connection already has a communication guard"
                )
            if owner is None:
                self.original_check_timeout = candidate.check_timeout
                candidate.check_timeout = self._check_timeout
                candidate._codex_beacon_guard_owner = self
            self.conn = candidate
            self.patch_mode = "connection"
        elif hasattr(self.mcu, "check_active"):
            owner = getattr(self.mcu, "_codex_beacon_guard_owner", None)
            if owner is not None and owner is not self:
                raise self.printer.config_error(
                    "Beacon MCU already has a communication guard"
                )
            if owner is None:
                self.original_check_active = self.mcu.check_active
                self.mcu.check_active = self._check_active
                self.mcu._codex_beacon_guard_owner = self
            self.patch_mode = "mcu"
        else:
            raise self.printer.config_error(
                "Unsupported Klipper MCU timeout implementation for Beacon guard"
            )

        self.armed = False
        self.timeout_ignored = False
        self.timeout_ignored_at = 0.0
        logging.info(
            "Beacon MCU guard installed for '%s' using %s timeout path; "
            "startup state is disarmed",
            self.mcu_name,
            self.patch_mode,
        )

    def _mcu_connected(self):
        if self.patch_mode == "connection":
            return bool(
                self.conn is not None
                and self.conn.get_clocksync().is_active()
                and not self.conn._is_timeout
            )
        return bool(
            self.mcu is not None
            and self.mcu._clocksync.is_active()
            and not self.mcu._is_timeout
        )

    def _record_ignored_timeout(self, eventtime):
        self.timeout_ignored = True
        self.timeout_ignored_at = eventtime
        message = (
            "Beacon MCU communication was lost after the post-mesh guard was "
            "armed; continuing the active print without Beacon. Restart "
            "Klipper before the next home or mesh."
        )
        logging.error(message)
        self.gcode.respond_info(message)

    def _check_timeout(self, eventtime):
        if not self.armed:
            return self.original_check_timeout(eventtime)
        if (
            self.conn.get_clocksync().is_active()
            or self.mcu.is_fileoutput()
            or self.conn._is_timeout
        ):
            return
        self.conn._is_timeout = True
        self._record_ignored_timeout(eventtime)

    def _check_active(self, print_time, eventtime):
        if not self.armed:
            return self.original_check_active(print_time, eventtime)
        if self.mcu._steppersync is None:
            return self.original_check_active(print_time, eventtime)
        if (
            self.mcu._clocksync.is_active()
            or self.mcu.is_fileoutput()
            or self.mcu._is_timeout
        ):
            return self.original_check_active(print_time, eventtime)

        # Preserve the old Qidi/Klipper clock-to-stepper synchronization that
        # normally runs immediately before its whole-printer timeout action.
        offset, freq = self.mcu._clocksync.calibrate_clock(
            print_time, eventtime
        )
        self.mcu._ffi_lib.steppersync_set_time(
            self.mcu._steppersync, offset, freq
        )
        self.mcu._is_timeout = True
        logging.info(
            "Ignored timeout with guarded MCU '%s' (eventtime=%f)",
            self.mcu_name,
            eventtime,
        )
        self._record_ignored_timeout(eventtime)

    def _status_values(self, eventtime):
        mesh = self.printer.lookup_object("bed_mesh", None)
        mesh_profile = ""
        if mesh is not None:
            mesh_profile = mesh.get_status(eventtime).get("profile_name", "")
        print_stats = self.printer.lookup_object("print_stats", None)
        print_state = "unknown"
        if print_stats is not None:
            print_state = print_stats.get_status(eventtime).get(
                "state", "unknown"
            )
        return mesh_profile, print_state

    def get_status(self, eventtime):
        mesh_profile, print_state = self._status_values(eventtime)
        return {
            "armed": self.armed,
            "mcu_connected": self._mcu_connected(),
            "timeout_ignored": self.timeout_ignored,
            "timeout_ignored_at": self.timeout_ignored_at,
            "mesh_profile": mesh_profile,
            "print_state": print_state,
            "patch_mode": self.patch_mode,
        }

    def cmd_BEACON_MCU_GUARD(self, gcmd):
        enable = gcmd.get_int("ENABLE", None, minval=0, maxval=1)
        eventtime = self.printer.get_reactor().monotonic()
        mesh_profile, print_state = self._status_values(eventtime)
        if enable is None:
            gcmd.respond_info(
                "Beacon MCU guard: armed=%d connected=%d timeout_ignored=%d "
                "mesh=%s print_state=%s mode=%s"
                % (
                    self.armed,
                    self._mcu_connected(),
                    self.timeout_ignored,
                    mesh_profile or "none",
                    print_state,
                    self.patch_mode,
                )
            )
            return

        if not enable:
            self.armed = False
            if self.timeout_ignored:
                gcmd.respond_info(
                    "Beacon MCU guard disarmed; Beacon was previously lost, "
                    "so restart Klipper before homing or meshing."
                )
            else:
                gcmd.respond_info("Beacon MCU guard disarmed")
            return

        force = gcmd.get_int("FORCE", 0, minval=0, maxval=1)
        if not self._mcu_connected():
            raise gcmd.error("Cannot arm Beacon MCU guard: Beacon is not connected")
        if self.beacon is not None and getattr(self.beacon, "_stream_en", False):
            raise gcmd.error(
                "Cannot arm Beacon MCU guard while Beacon is streaming"
            )
        if self.require_mesh and not mesh_profile and not force:
            raise gcmd.error(
                "Cannot arm Beacon MCU guard until a bed mesh is active"
            )
        if (
            self.require_active_print
            and print_state not in ("printing", "paused")
            and not force
        ):
            raise gcmd.error(
                "Cannot arm Beacon MCU guard without an active print"
            )
        self.armed = True
        gcmd.respond_info(
            "Beacon MCU guard armed after mesh '%s'; an idle Beacon dropout "
            "will no longer stop this print" % (mesh_profile or "forced")
        )


def load_config(config):
    return BeaconMCUGuard(config)
