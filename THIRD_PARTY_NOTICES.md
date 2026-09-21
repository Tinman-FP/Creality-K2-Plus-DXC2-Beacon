# Third-party notices

## Beacon Klipper

`runtime/firmware-1.1.6.1/beacon.py` is derived from the Beacon Klipper module and retains its copyright header and GPL-3.0 licensing terms.

Upstream: https://github.com/beacon3d/beacon_klipper

The K2-tested copy adds compatibility for Creality's Klipper fork, the userspace USB bridge timing path, host-side stream decimation, and the K2 bed-mesh constructor.

## Klipper / Creality homing

`runtime/firmware-1.1.6.1/homing.py` is a version-pinned compatibility copy based on the Klipper-derived file shipped in Creality firmware 1.1.6.1. Its header identifies the original Klipper authors and GPLv3 distribution terms. Use it only on the matching firmware/hash.

Upstream Klipper: https://github.com/Klipper3d/klipper

## KAMP

`config/KAMP/Adaptive_Meshing.cfg` is based on Klipper Adaptive Meshing and Purging.

Upstream: https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging

## DXC2

DXC2, Phaetus, D3vil Design, and Creality names belong to their respective owners. This repository does not include the manufacturer's installation PDF or product artwork. It links to the public DXC2 model/adaptor repository instead:

https://github.com/Phaetus/DXC-2-Extruder

## USB bridge binary

`bin/armv7l/beacon_usb_bridge` is the exact ARMv7 deployment artifact tested on the reference K2 Plus. Its SHA-256 is published in `SHA256SUMS`. It dynamically uses the K2 host's libusb runtime and is supplied without warranty. The historical build source was not retained with the deployed artifact; the binary is included so the tested installation is reproducible rather than silently depending on an unavailable file.
