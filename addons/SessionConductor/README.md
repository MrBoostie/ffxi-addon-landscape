# SessionConductor

Event-driven multi-character orchestration for Windower with rule evaluation, ACK tracking, pending request inspection, and safer follow command construction.

## Install
- Copy `addons/SessionConductor` into your Windower `addons/` directory.
- Load with `//lua load SessionConductor`.

## What it does
- Dispatches travel and command actions to trusted peers over IPC.
- Tracks ACK replies per request and retries lightweight peer actions.
- Supports scoped rosters for different teams or play patterns.
- Evaluates trigger rules against local game-state-derived events.
- Records an append-only event log for debugging automation behavior.
- Hardens follow command construction and improves operator introspection.

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
- `//conductor roster show <group>`
- `//conductor roster list`

### Reliability / safety
- `//conductor timeout <seconds>`
- `//conductor status`
- `//conductor status detail`
- `//conductor pending [N]`
- `//conductor remotecmd on|off`
- `//conductor localecho on|off`

### Event/rule automation
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

## Persistence
- `data/roster.user.lua` stores groups, target selection, timeout, and automation toggles.
- `data/rules.default.lua` shipped baseline trigger rules.
- `data/rules.user.lua` optional user overrides.
- `data/events.log` rolling append-only event trail.

## Notes
- This remains trusted-party tooling, not an exposed remote control service.
- Remote command execution is still opt-in and off by default.
- The new pending/status views are there so operators can see what the automation layer thinks is happening instead of guessing.
