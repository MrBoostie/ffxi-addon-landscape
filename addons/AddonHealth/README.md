# AddonHealth

In-game health dashboard for your Windower addon stack.

## Install
- Copy `addons/AddonHealth` into your Windower `addons/` directory.
- Load with `//lua load AddonHealth`.

## What it does
- Detects installed addons by scanning your Windower `addons/` directory.
- Flags duplicate addon names (case-insensitive).
- Detects known addon conflicts (e.g. GearSwap + GearSwap2).
- Reports player state, zone, and party size.
- Notes addons missing a `data/` directory (potential config issues).
- Supports periodic background watch mode with alert suppression.
- Exports diagnostic snapshots to timestamped report files.

## Commands
- `//addonhealth check` — run diagnostics and print report
- `//addonhealth list` — list detected addons
- `//addonhealth watch on|off [interval]` — toggle periodic checks (default 60s)
- `//addonhealth export` — dump report to `data/addonhealth-report-<timestamp>.txt`
- `//addonhealth status` — show watch state and last report time
- `//addonhealth suppress [seconds]` — suppress watch alerts temporarily

## Report contents
- Player info (job, zone, party size)
- Addon count and full list
- Duplicate addon warnings
- Known conflict detection
- Missing data directory notes

## Persistence
- `data/` — exported report snapshots
