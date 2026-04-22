# TravelRouter (prototype)

Content-aware travel routing addon for Windower.

## What it does
- Maps a destination keyword to a multi-hop route plan.
- Prints a step-by-step route in chat (`//troute plan <dest>`).
- Can execute helper commands for each step (`//troute run <dest>`).
- Exposes a tiny IPC protocol that other addons (like SessionConductor) can call.

## Commands
- `//troute list` — list known destinations
- `//troute plan <destination>` — print route plan
- `//troute run <destination>` — execute mapped command steps
- `//troute add <destination> <step1> ; <step2> ; ...` — add/update route at runtime

## Route step format
Each step is one of:
- `say:<text>` — prints instruction text
- `cmd:<windower command>` — executes command (without leading `//`)

Example step list:
- `say:Warp to Jeuno HP #1`
- `cmd:hp #1`
- `say:Take Survival Guide to Western Adoulin`

## IPC (v1)
Inbound message type: `TRAVEL_ROUTER|plan|<destination>`

Reply message type:
`TRAVEL_ROUTER_REPLY|plan|<destination>|ok|<0/1>|steps|<N>`

---

This is an MVP scaffold. Next iteration should include real zone/state awareness and unlock-aware route scoring.
