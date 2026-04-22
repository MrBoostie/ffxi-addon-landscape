# TravelRouter v0.2 (implemented prototype)

## Delivered
- Destination registry + candidate model
- Plan output with simple scoring rationale
- Route execution
- Persistence for user routes/state
- IPC v2 (`TR2`/`TR2R`) with v1 compatibility

## Commands
- `//troute list`
- `//troute plan <destination>`
- `//troute run <destination>`
- `//troute add <destination> <step1> ; <step2> ; ...`
- `//troute reset <destination>`
- `//troute unlock list|add|remove <token>`
- `//troute save`

## Remaining gaps
- richer unlock detection (currently token-based)
- deeper zone/context intelligence
- dependency discovery from loaded addons
