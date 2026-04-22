# SessionConductor

Multi-character session conductor addon for Windower.

## Install
- Copy `addons/SessionConductor` into your Windower `addons/` directory.
- Load with `//lua load SessionConductor`.
- For coordinated travel, also load `TravelRouter` on each participating instance.

## What it does
- Broadcasts coordinated travel/command operations over IPC.
- Integrates with **TravelRouter** for synchronized destination routing.
- Supports roster groups and target scoping (`all` or specific group).
- Tracks ACK replies per dispatch and reports timeout state.

## Commands
- `//conductor travel <destination>`
- `//conductor command <raw command>`
- `//conductor follow <leader>`
- `//conductor ping`
- `//conductor target <group|all>`
- `//conductor roster add <group> <name>`
- `//conductor roster remove <group> <name>`
- `//conductor roster list`
- `//conductor timeout <seconds>`
- `//conductor status`
- `//conductor remotecmd on|off`

## Persistence
- `data/roster.user.lua` stores groups, target selection, and timeout value.

## Integration behavior
When `travel` is used:
1. SessionConductor executes TravelRouter locally.
2. Sends IPC event containing request id + target scope.
3. Peers matching scope execute route and ACK result.

## IPC
### v2 (preferred, robust payload encoding)
- `SC2|op=travel&dest=jeuno&from=Alice&target=farm&req=...`
- `SC2|op=command&raw=input+/heal+Bob&from=Alice&target=all&req=...`
- `SC2|op=ping&from=Alice&target=all`
- `SC2R|op=ack&req=...&from=Bob&status=ok`
- `SC2R|op=pong&from=Bob`

### v1 (legacy compatibility during migration)
- `SESSION_CONDUCTOR|travel|...`
- `SESSION_CONDUCTOR|command|...`
- `SESSION_CONDUCTOR|ping|...`
- `SESSION_CONDUCTOR_REPLY|pong|...`

## Safety / scope notes
- This is trusted-party tooling, not a hardened remote-control framework.
- Remote command execution is OFF by default; enable only for trusted groups (`//conductor remotecmd on`).
- ACK/timeout reporting is lightweight and intentionally simple.
