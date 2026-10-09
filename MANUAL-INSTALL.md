# Manual Install — New/Standalone Machine

For installing the player on a machine by hand (no USB needed — download
straight from the distribution repo's GitHub Release), independent of the
CDN auto-update channel. Use this for new machines, or any machine that
needs a specific staged version ahead of the rest of the fleet.

## 1. Download the installer

On the target machine, open a browser and download the installer from the
relevant release on `ubiquo-techs/ubox-distribution`, e.g.:

```
https://github.com/ubiquo-techs/ubox-distribution/releases/download/installer-v1.29/ubox-setup.exe
```

Check the repo's [Releases page](https://github.com/ubiquo-techs/ubox-distribution/releases)
for the latest `installer-v*` tag if this link has been superseded.

## 2. Unblock it before running

Downloaded files carry a "Mark of the Web" flag that makes Windows
SmartScreen stricter about unsigned executables. In an elevated
PowerShell/cmd:

```powershell
powershell -Command "Unblock-File 'C:\Users\<user>\Downloads\ubox-setup.exe'"
```

(Or right-click the file → Properties → check "Unblock" → OK.)

## 3. Run the installer as Administrator

Double-click `ubox-setup.exe`. If SmartScreen still shows a blue "Windows
protected your PC" screen, click **More info → Run anyway**.

This installs everything, stamps the version sidecar (`ubox.exe.version`),
points shortcuts/autostart at `ubox-start.bat`, and adds the Windows
Defender exclusion automatically.

## 4. Configure whichever sensor nodes this machine needs

Edit `%LocalAppData%\Ubox Physical Player\config.yaml`. For the esp32
device line, find the `esp32-01` entry and:

- Change `enabled: false` → `enabled: true`
- Replace `REPLACE_WITH_SHARED_SECRET` with the device's real secret
- If this machine has multiple network adapters, add
  `"--local-ip", "<this machine's IP>"` to `args`

Enable/configure any other node entries the same way as needed.

## 5. If Chrome won't launch automatically (single-instance handoff)

Some locked-down/managed machines have Chrome configured (or a background
service keeps it alive) such that a new automated Chrome instance always
hands off to an existing session instead of actually starting — the
symptom is `viewer: could not open browser  error=chrome failed to start:`
with no further detail in the player's log, or a Chrome window that opens
but shows a blank/white page unrelated to the player. Confirmed on one
real machine even with a brand-new, never-used Chrome profile directory —
so it isn't a chromedp bug or a stale-profile issue, it's something about
that machine's Chrome itself (most likely a persistent/managed background
instance).

**Confirm this is actually happening before applying the workaround** — it
is machine-specific, not a general fix.

### Option A — fully automatic (recommended)

`ubox-update.ps1` (already installed, no download needed) supports an
opt-in **auto-start sequence** that sidesteps the handoff bug entirely by
never letting chromedp launch Chrome in the first place:

1. Starts the player headless (`--no-browser`).
2. **Waits** until the player's own HTTP server actually answers
   (`http://127.0.0.1:<port>`, polling every 500ms, 30s timeout) — this is
   the check that has to happen before opening a browser, so it never
   opens one against a server that isn't ready yet, and never opens one at
   all if the player failed to start.
3. Opens a **plain, non-automated** Chrome window (a fresh kiosk profile,
   fullscreen, pointed at the dashboard) — since this Chrome isn't
   chromedp-controlled, the handoff bug doesn't apply to it.
4. **Supervises**: stays running in the background for as long as the
   player does, and closes that Chrome window the moment the player exits,
   for any reason (crash, manual stop, update). Without this, the browser
   would be orphaned, since only chromedp's own browser gets the player's
   Job Object cleanup.

To turn it on, create an empty file named `external-browser.flag` next to
`ubox.exe` in the install directory:

```powershell
New-Item -ItemType File "$env:LOCALAPPDATA\Ubox Physical Player\external-browser.flag"
```

That's the entire setup — no script editing needed. Delete that file to go
back to the normal (chromedp-automated) browser launch.

**Trade-off**: the player's own activation-driven auto-navigation can't
reach a browser it doesn't control. If the active app changes while
running this way, re-open `http://127.0.0.1:8080` manually to see it.

### Option B — no browser at all

If Option A still doesn't produce a usable browser window on a given
machine (e.g. Chrome is blocked outright, not just handed off), fall back
to pure headless mode: edit `ubox-update.ps1`'s last line from
`"--via-launcher"` to `"--via-launcher", "--no-browser"`, and open the
dashboard manually yourself each time.

## 6. Launch

Use the Desktop/Start Menu shortcut (or `ubox-start.bat` directly). On this
first run:

- **Player version check**: compares the local sidecar against
  `manifests/player/manifest.json` on the CDN. If the CDN is intentionally
  pinned at an older version than what this installer shipped (the normal
  state during a staged rollout), the player correctly **stays at the
  newer, installed version** — it will not downgrade.
- **Enabled nodes with a `manifest_url`**: downloaded straight from the
  CDN on first run if no local copy/version sidecar exists yet (e.g. a
  freshly-enabled `esp32-01` fetches `esp32-sensor.zip` from
  `ubiquo-techs/ubox-distribution` automatically).

## 7. Verify

Open `http://127.0.0.1:8080` and confirm every node you enabled shows as
registered/connected on the dashboard.

From here on, this machine self-updates each enabled node (not
necessarily the player — see the note in step 6) on every launch, picking
up whatever the CDN manifests point to.
