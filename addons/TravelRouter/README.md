# TravelRouter (prototype)

Content-aware travel routing addon for Windower.

## What it does
- Maps a destination keyword to a multi-hop route plan.
- Prints a step-by-step route in chat (`//troute plan <dest>`).
- Can execute helper commands for each step (`//troute run <dest>`).
- Exposes a tiny IPC protocol that other addons (like SessionConductor) can call.

## Install
- Copy `addons/TravelRouter` into your Windower `addons/` directory.
- Load with `//lua load TravelRouter`.

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
Inbound message types:
- `TRAVEL_ROUTER|plan|<destination>`
- `TRAVEL_ROUTER|run|<destination>`

Reply message types:
- `TRAVEL_ROUTER_REPLY|plan|<destination>|ok|<0/1>|steps|<N>`
- `TRAVEL_ROUTER_REPLY|run|<destination>|ok|<0/1>`

---

This is an MVP scaffold. Next iteration should include real zone/state awareness and unlock-aware route scoring.

## Known limitations
- Route definitions are static and bundled in `data/routes.lua`.
- `//troute add ...` updates routes only for the current runtime session.
- Route steps are thin wrappers around existing Windower commands; unlock/state validation is not implemented yet.
