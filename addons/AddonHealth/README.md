# AddonHealth v0.1

Unified health dashboard for your Windower addon stack.

## What it does

- Reports which addons are loaded
- Checks for missing dependencies between addons
- Validates that expected config files exist
- Periodic background watch mode for ongoing monitoring
- Export diagnostic snapshots to file

## Commands

| Command | Description |
|---------|-------------|
| `//addonhealth` | Show help |
| `//addonhealth check` | Run diagnostics and display results |
| `//addonhealth watch on [interval]` | Enable periodic health checks (default 30s) |
| `//addonhealth watch off` | Disable periodic checks |
| `//addonhealth export` | Export last report to `data/` directory |
| `//addonhealth status` | Show last report without re-running |

## Setup

```
1. Copy AddonHealth/ to your Windower addons/ directory
2. //lua load AddonHealth
3. //addonhealth check
```

## Output

The check displays addon load status, dependency issues, and file validation results:

```
[AddonHealth] --- Health Check @ 14:23:05 ---
[AddonHealth] Player: MyChar | Zone: 230
[AddonHealth] Addon Status:
[AddonHealth]   [+] TravelRouter
[AddonHealth]   [+] SessionConductor
[AddonHealth]   [-] GearSwap
[AddonHealth] Dependency Issues:
[AddonHealth]   SessionConductor requires TravelRouter (not loaded)
[AddonHealth] All checks passed.
[AddonHealth] ---
```


## Notes

- Windower builds can expose loaded addons in different shapes. AddonHealth now tolerates string lists, keyed tables, and addon descriptor tables when detecting loaded addons.
