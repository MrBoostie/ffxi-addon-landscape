# TravelRouter v0.1

## Purpose
Content-aware travel route planner/executor for FFXI.

## MVP
- destination registry
- plan output
- run execution
- IPC endpoint for plan/run requests

## Commands
- `//troute list`
- `//troute plan <destination>`
- `//troute run <destination>`
- `//troute add <destination> <step1> ; <step2> ; ...`

## Notes
Current prototype uses static route data and command steps. Next iteration should infer best path by unlock state + current zone.
