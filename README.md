# ubox-distribution

CDN manifests and release assets for the Ubox Physical Player platform.

## Manifests

| Component | Manifest | Notes |
|---|---|---|
| Player | `manifests/player/manifest.json` | **Deliberately pinned to the last fully-migrated version** — the physical player's launcher architecture changed (see `ubox-start.bat`/`ubox-update.ps1`); only bump this after every installed player has been migrated, or un-migrated installs will fail to start on update. |
| Astra Pro sensor | `manifests/sensors/astraPro/manifest.json` | |
| Button sensor | `manifests/sensors/button/manifest.json` | |
| DMX (Art-Net) sensor | `manifests/sensors/dmx/manifest.json` | |
| ESP32 sensor | `manifests/sensors/esp32/manifest.json` | Bridges a line of simple ESP32-class hardware (buttons, distance sensors, device-local LEDs) to the `realityos.soc.*` namespace — see `nodes/esp32/CLAUDE.md` and `docs/realityos-protocol.md` in the `ubox-physical-player` repo for the full protocol. |
| Kinect2 sensor | `manifests/sensors/kinect2/manifest.json` | |
| Lidar sensor | `manifests/sensors/lidar/manifest.json` | |
| MIDI sensor | `manifests/sensors/midi/manifest.json` | |

Each manifest is `{"version": "...", "url": "..."}`, where `url` points to a GitHub Release asset in this repo. Published by each sensor's own `build.ps1 -Publish` in the `ubox-physical-player` repo.
