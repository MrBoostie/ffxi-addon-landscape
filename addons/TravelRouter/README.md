# TravelRouter

Content-aware travel routing addon for Windower.

## Install
- Copy `addons/TravelRouter` into your Windower `addons/` directory.
- Load with `//lua load TravelRouter`.

## What it does
- Maps destination keywords to route candidates.
- Scores candidates based on lightweight unlock/state signals.
- Prints route rationale and selected step plan (`//troute plan <dest>`).
- Executes selected route steps (`//troute run <dest>`).
- Persists user-added route overrides across reloads/restarts.
- Exposes IPC endpoints used by SessionConductor.

## Commands
- `//troute list` — list known destinations
- `//troute search <text>` — find destinations by prefix/substring (e.g. typo recovery)
- `//troute plan <destination>` — print best route + scoring rationale
- `//troute explain <destination>` — show ranked candidate scores and selection reasons
- `//troute run <destination>` — execute selected route
- `//troute add <destination> <step1> ; <step2> ; ...` — persist user route override
- `//troute reset <destination>` — remove user override for destination
- `//troute unlock list` — list unlock tokens used for scoring
- `//troute unlock add <token>` — mark unlock available (e.g. `hp`, `sg`, `warp`)
- `//troute unlock remove <token>` — clear unlock token
- `//troute alias list` — list destination aliases
- `//troute alias add <alias> <destination>` — add an alias (e.g. `jueno` => `jeuno`)
- `//troute alias remove <alias>` — delete an alias
- `//troute save` — force-save user routes/state files

## Persistence files
- `data/routes.user.lua` — user route overrides
- `data/state.user.lua` — unlock/state tokens + aliases

## Route data model
`data/routes.lua` supports either:
1) legacy simple route (list of steps), or
2) candidate model:

```lua
jeuno = {
  candidates = {
    { name = 'home-point-direct', score = 15, requires = {'hp'}, steps = {...} },
    { name = 'warp-fallback', score = 8, requires = {'warp'}, steps = {...} },
  }
}
```

## Route step format
Each step is one of:
- `say:<text>` — prints instruction text
- `cmd:<windower command>` — executes command (leading `//` optional)

## IPC
### v2 (preferred, robust payload encoding)
- request: `TR2|op=plan&dest=jeuno`
- request: `TR2|op=run&dest=jeuno`
- reply: `TR2R|op=plan&dest=jeuno&ok=1&steps=3&by=TravelRouter`
- reply: `TR2R|op=run&dest=jeuno&ok=1&by=TravelRouter`

### v1 (legacy compatibility)
- `TRAVEL_ROUTER|plan|<destination>`
- `TRAVEL_ROUTER|run|<destination>`
- replies via `TRAVEL_ROUTER_REPLY|...`

## Current behavior notes
- Unlock/state signals are token-driven (`//troute unlock ...`) and can be extended.
- Destination aliases are applied before route lookup (`//troute alias ...`).
- Unknown destination lookups now include best-effort suggestions.
- Capability checks for third-party addon commands are not auto-detected yet.
