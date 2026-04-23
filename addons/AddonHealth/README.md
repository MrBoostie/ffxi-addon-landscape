# AddonHealth

In-game diagnostic dashboard for your Windower addon stack with watch mode, severity grading, and short report history.

## Install
- Copy `addons/AddonHealth` into your Windower `addons/` directory.
- Load with `//lua load AddonHealth`.

## What it does
- Detects installed addons by scanning your Windower addons directory.
- Flags duplicate addon names and known addon conflicts.
- Reports player state, zone, and party size.
- Notes addons missing a `data/` directory.
- Supports periodic watch mode with alert suppression.
- Assigns a simple severity level and keeps a short in-memory history of reports.
- Exports diagnostic snapshots to timestamped text files.

## Commands
- `//addonhealth check` — run diagnostics and print the full report
- `//addonhealth summary` — print a compact severity summary
- `//addonhealth list` — list detected addons
- `//addonhealth history [N]` — show recent in-memory report history
- `//addonhealth watch on|off [interval]` — toggle periodic checks
- `//addonhealth export` — dump report to `data/addonhealth-report-<timestamp>.txt`
- `//addonhealth status` — show watch state and last report time
- `//addonhealth suppress [seconds]` — suppress watch alerts temporarily

## Notes
- Severity is intentionally coarse: `ok`, `warn`, or `alert`.
- History is in-memory only and intended for short-session diagnostics.
