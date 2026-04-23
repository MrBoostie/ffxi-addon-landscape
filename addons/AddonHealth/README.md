# AddonHealth v0.2

Unified health dashboard for your Windower addon stack.

## What it does

- Reports loaded status for a curated addon catalog with critical vs optional coverage
- Surfaces unknown loaded addons so the report is explicit about what it does not model
- Checks known addon dependencies
- Validates expected cross-addon files exist
- Periodic background watch mode for ongoing monitoring
- Export diagnostic snapshots to file
- Cleans up its watch event on unload

## Commands

| Command | Description |
|---------|-------------|
| `//addonhealth` | Show help |
| `//addonhealth check` | Run diagnostics and display results |
| `//addonhealth watch on [interval]` | Enable periodic health checks (default 30s, minimum 5s) |
| `//addonhealth watch off` | Disable periodic checks |
| `//addonhealth export` | Export last report to `data/` directory |
| `//addonhealth status` | Show current summary |
| `//addonhealth summary` | Alias for `status` |

## Setup

```text
1. Copy AddonHealth/ to your Windower addons/ directory
2. //lua load AddonHealth
3. //addonhealth check
```

## Output

The check displays severity, known-vs-unknown addon coverage, dependency issues, and file validation results:

```text
[AddonHealth] --- Health Check @ 14:23:05 ---
[AddonHealth] Player: MyChar | Zone: 230 | Severity: warn
[AddonHealth] Coverage: 2 known loaded, 1 unknown loaded
[AddonHealth] Addon Status:
[AddonHealth]   [+] TravelRouter
[AddonHealth]   [+] SessionConductor
[AddonHealth]   [-] GearSwap
[AddonHealth] Unknown Loaded Addons: utility
[AddonHealth] Summary: ok=2 warn=1 alert=0
[AddonHealth] ---
```

## Notes

- Loaded-addon detection tolerates string lists, keyed tables, and addon descriptor tables.
- Path inference uses basename extraction with safe slash handling instead of malformed escape patterns.
- The report is intentionally explicit that it is a curated catalog, not a full source of truth for every loaded addon.
