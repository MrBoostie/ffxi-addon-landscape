# SessionConductor v0.1

## Purpose
Coordinate multi-character sessions through IPC broadcasts.

## MVP
- broadcast raw commands
- broadcast travel requests
- local + remote execution model
- ping/pong connectivity check

## Commands
- `//conductor travel <destination>`
- `//conductor command <raw command>`
- `//conductor follow <leader>`
- `//conductor ping`

## TravelRouter integration
`travel` command calls local `//troute run <destination>` and broadcasts the same request to peers.
