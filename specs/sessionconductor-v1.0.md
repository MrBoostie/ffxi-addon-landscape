# SessionConductor v1.0

## Delivered
- Broadcast travel/command operations
- TravelRouter integration
- Roster/group scoping + active target selection
- ACK collection and timeout visibility (`status`)
- IPC v2 (`SC2`/`SC2R`) with v1 compatibility
- Persistent roster config

## Commands
- `//conductor travel <destination>`
- `//conductor command <raw command>`
- `//conductor follow <leader>`
- `//conductor ping`
- `//conductor target <group|all>`
- `//conductor roster add|remove|list ...`
- `//conductor timeout <seconds>`
- `//conductor status`

## Remaining gaps
- authenticated sender/roster trust model
- retry/backoff for failed peers
- richer execution telemetry per operation type
