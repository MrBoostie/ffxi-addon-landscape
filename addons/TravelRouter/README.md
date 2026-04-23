# TravelRouter

Content-aware travel planner and executor for Windower with persistent custom routes, explainable scoring, route introspection, and execution history.

## Install
- Copy `addons/TravelRouter` into your Windower `addons/` directory.
- Load with `//lua load TravelRouter`.

## What it does
- Plans travel using scored route candidates and unlock-aware selection.
- Explains why a route was selected, including unlock/zone rationale.
- Executes routes with chat, wait, and command steps.
- Persists custom routes and player unlock state.
- Records recent execution history for debugging and iteration.
- Responds to SessionConductor IPC travel requests.

## Commands
- `//troute list` — list all known destinations
- `//troute listuser` — list persisted custom route overrides
- `//troute search <term>` — fuzzy-match destinations
- `//troute plan <destination>` — print the selected plan
- `//troute explain <destination>` — show all candidates and the winning rationale
- `//troute dump <destination>` — dump candidate metadata and full step lists
- `//troute run <destination>` — execute the selected plan
- `//troute history [N]` — show recent route executions
- `//troute add <dest> <step1> ; <step2> ; ...` — save a custom route
- `//troute reset <dest>` — remove a persisted custom override
- `//troute unlock list|add|remove <token>` — manage unlock hints used for scoring
- `//troute save` — write user route/state files immediately
- `//troute where` — print current zone id
- `//troute version` — print addon version

## Persistence
- `data/routes.user.lua` — saved custom routes as structured route definitions
- `data/state.user.lua` — unlock state and recent route execution history

## Notes
- Route selection stays bounded and explainable; it does not attempt hidden automation or unsafe inference.
- Custom routes are stored as scored route objects so future metadata can be added cleanly.
