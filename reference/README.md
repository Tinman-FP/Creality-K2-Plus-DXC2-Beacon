# Version-pinned reference files

`sensorless.cfg.tested` is the complete file from the tested Creality K2 Plus
firmware 1.1.6.1 installation.  It is supplied for review and diffing because
the Beacon Z-homing integration touches Creality's existing homing override.

Do not copy it over a different firmware version.  Merge the `_HOME_Z` and
`[homing_override]` changes described in `docs/INSTALL.md`, preserving any
vendor changes in your installed version.

The file contains no MCU serial numbers, CFS identifiers, network addresses,
passwords, saved probe models, meshes, or other machine identity data.
