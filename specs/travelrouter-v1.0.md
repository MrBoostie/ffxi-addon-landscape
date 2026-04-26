# TravelRouter v1.0

## Delivered
- Destination registry + candidate model
- Plan output with simple scoring rationale
- Route execution
- Persistence for user routes/state
- IPC v2 (`TR2`/`TR2R`) with v1 compatibility

## Commands
- `//troute list`
- `//troute search <text>`
- `//troute plan <destination>`
- `//troute explain <destination>`
- `//troute audit <destination>`
- `//troute run <destination>`
- `//troute add <destination> <step1> ; <step2> ; ...`
- `//troute reset <destination>`
- `//troute alias list|add|remove ...`
- `//troute unlock list|add|remove <token>`
- `//troute save`

## Remaining gaps
- richer unlock detection (currently token-based)
- deeper zone/context intelligence
- dependency discovery from loaded addons
