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
### Core dispatch
- `//conductor travel <destination>`
- `//conductor command <raw command>`
- `//conductor follow <leader>`
- `//conductor ping`

### Targeting / roster
- `//conductor target <group|all>`
- `//conductor roster add <group> <name>`
- `//conductor roster remove <group> <name>`
- `//conductor roster list`

### Reliability / safety
- `//conductor timeout <seconds>`
- `//conductor status`
- `//conductor remotecmd on|off`

### Event/rule automation (v1.1)
- `//conductor auto on|off`
- `//conductor mode <normal|recovery|emergency|travel>`
- `//conductor pause <seconds>`
- `//conductor rule enable <id>`
- `//conductor rule disable <id>`
- `//conductor rules list`
- `//conductor rules explain <eventType>`
- `//conductor rules reload`
- `//conductor events tail [N]`
- `//conductor trace on|off`
- `//conductor emit <eventType>`
- `//conductor sensor distance <yards>`

## Persistence
- `data/roster.user.lua` stores groups, target selection, timeout, and automation toggles.
- `data/rules.default.lua` shipped baseline trigger rules.
- `data/rules.user.lua` optional user overrides (same rule ids override defaults).
- `data/events.log` rolling append-only event trail for debugging.

## Integration behavior
When `travel` is used:
1. SessionConductor executes TravelRouter locally.
2. Sends IPC event containing request id + target scope.
3. Peers matching scope execute route and ACK result.

## Built-in event detectors
Current runtime detectors emit events for:
- combat status transitions (`combat.engaged`, `combat.disengaged`, `combat.idle_timeout`)
- target changes (`combat.target_changed`)
- weapon-skill action events (`combat.ws_used`, synthetic `combat.skillchain_open`)
- party HP/KO thresholds (`party.member.hp_low`, `party.member.hp_critical`, `party.member.ko`)
- distance separation (`party.member.distance_exceeded`)
- watched self debuffs (`party.member.debuff_added`, `party.member.debuff_removed`)
- zone changes + ACK timeout/retry exhaustion system events

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
