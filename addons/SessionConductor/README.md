# SessionConductor (prototype)

Multi-character session conductor addon for Windower.

## Install
- Copy `addons/SessionConductor` into your Windower `addons/` directory.
- Load with `//lua load SessionConductor`.
- For coordinated travel, also load `TravelRouter` on each participating instance.

## What it does
- Sends coordinated commands across characters via IPC.
- Can orchestrate travel runs for all connected characters.
- Leverages **TravelRouter** to plan/run destination routes.

## Commands
- `//conductor travel <destination>`
  - Runs local `//troute run <destination>` and broadcasts the same request over IPC.

- `//conductor command <raw command>`
  - Broadcasts a raw command for peers to execute.

- `//conductor follow <leader>`
  - Broadcasts a helper assist/follow command pattern.

- `//conductor ping`
  - Broadcasts ping and listens for responses.

## Integration behavior
When `travel` is used:
1. SessionConductor asks TravelRouter to execute locally.
2. Sends IPC event to all peers to do the same.
3. Peers that have SessionConductor + TravelRouter loaded will execute route in sync.

## IPC (v1)
- `SESSION_CONDUCTOR|travel|<destination>|from|<name>`
- `SESSION_CONDUCTOR|command|<raw>|from|<name>`
- `SESSION_CONDUCTOR|ping|from|<name>`
- `SESSION_CONDUCTOR_REPLY|pong|from|<name>`

---

Prototype only. Future version should add team roster, ack tracking, timeout handling, and scoped groups.

## Safety / scope notes
- `command` rebroadcasts arbitrary Windower commands to peers. Treat it as trusted-party tooling, not a hardened remote-control layer.
- The current IPC protocol uses `|` as a delimiter, so payloads containing `|` are intentionally rejected.
- There is no ack/timeout/roster model yet; this is still scaffolding.
