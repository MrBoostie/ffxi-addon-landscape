# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two things in one repo:

1. **A research catalog** of the FFXI addon ecosystem: the raw repo scan (`ffxi_addons_index_raw.json`), the normalized catalog (`ffxi-addon-catalog-normalized.json` + `.csv`), and the markdown analysis/shortlist. `index.html` is a static GitHub Pages viewer that `fetch()`es the normalized JSON at runtime (live at https://mrboostie.github.io/ffxi-addon-landscape/).
2. **A Windower 4 addon suite** (Lua 5.1) in `addons/`: TravelRouter, SessionConductor, AddonHealth. `specs/` holds the design spec for each one. Read the spec before changing an addon's command surface or behavior.

## Commands

```bash
./scripts/validate.sh          # full check: Lua syntax, catalog schema, rule/route data checks, unit tests
./scripts/validate_addons.sh   # lighter: Lua syntax + JSON parse only

# Run a single test. Tests use paths relative to tests/, so run them from there:
cd tests && ODIN_TEST_REPO_ROOT=.. lua5.1 test_travelrouter.lua

python3 scripts/discover.py run                 # find Windower addons on GitHub not yet in the catalog (slow first run; cached + resumable)
python3 scripts/discover.py resolve <Name>...   # look up specific addon names (e.g. forum leads)
python3 scripts/discover.py apply --dry-run     # merge reviewed candidates into catalog JSON/CSV + raw index
python3 scripts/enrich_descriptions.py          # rebuild catalog descriptions from upstream READMEs (uses `gh api`, needs network + gh auth)
python3 scripts/refine_descriptions_chunk.py    # description quality pass over the catalog
```

Both Python scripts rewrite the catalog JSON **and** the CSV together. Keep the two in sync if you edit them by hand. `validate.sh` requires every catalog entry to have `addon_name`, `addon_key`, and `category`.

## Catalog discovery

Discovery is **Windower only**. Don't search for Ashita addons. Existing Ashita entries stay in the catalog. `scripts/discover.py` works like this:

- It runs GitHub repo search and code search for `_addon.name` and similar strings. Both are split into smaller date or file-size ranges to get past the 1,000-result cap.
- For each repo it lists every file and treats `<dir>/<dir>.lua`, or a `.lua` file at the repo root, as an addon's main file.
- It downloads each main file and keeps it if it declares `_addon.name` and isn't Ashita code.
- It writes `discovery/candidates.json` and `discovery/report-<date>.md`.
- `discovery/.cache/` (gitignored) holds search results and per-repo scans, so `report` can rebuild the report offline.
- Review decisions go in `discovery/ignore.txt`.
- `apply` sorts the catalog by `addon_key`. It writes the JSON with indent 2, no ASCII escaping and no trailing newline, and the CSV `repos` column as a Python list repr. That matches the existing files so diffs stay minimal.

## Addon architecture

- **Single-file addons.** Each addon is one `<name>.lua` with `_addon.name/version/commands`, registering Windower events (`addon command`, `ipc message`, `prerender`, `load`/`unload`). Data lives in `data/*.lua` files that `return` a table.
- **Default and user data layering.** Shipped defaults (`data/routes.lua`, `data/rules.default.lua`) are merged at runtime with user files under `windower.addon_path .. 'data/*.user.lua'` (routes, state, roster, rules). User rules override defaults by `id`. Persisted state is written back as `return <serialized table>`.
- **`lib/common.lua` is not loaded by the addons.** Windower addons have to be self-contained, so TravelRouter and SessionConductor each keep their own copies of `enc`/`pack`/`unpack_payload` and similar helpers. `lib/common.lua` is the reference copy and is unit-tested by `tests/test_common.lua`. If you change a shared helper, update every copy.
- **Cross-addon IPC.** Instances talk over `windower.send_ipc_message` using a `PREFIX|k=v&k=v` URL-encoded payload format:
  - `SC2` is a SessionConductor request (`op=travel|command|ping`, with `target` group and `req` id). `SC2R` is the ack/pong reply.
  - `TR2R` is TravelRouter's reply to plan/run requests. `//conductor travel <dest>` broadcasts `SC2`, and the receiving instance's TravelRouter executes the route.
  - Legacy pipe formats (`SESSION_CONDUCTOR_REPLY|...`, `TRAVEL_ROUTER_REPLY|...`) are still emitted for backward compatibility.
- **SessionConductor rule engine (v1.1).** Rules have `id`, `enabled`, `priority`, `cooldown_sec`, `lockout_group`/`lockout_sec`, `when = {event, where = {{field, op, value}}}`, and `then_actions = {{kind, ...}}`. `validate.sh` enforces unique rule IDs. See `specs/sessionconductor-v1.1-triggers.md`.
- **Safety default.** Remote command execution in SessionConductor is off by default (`//conductor remotecmd on|off`). Keep it that way.
- **TravelRouter routes.** Each destination has `candidates`, and each candidate has `name`, `score`, `requires` (unlock tokens such as `hp`, `sg`, `warp`), and `steps`. Steps are prefixed `say:`, `cmd:`, or `wait:`. The planner picks the highest-scoring candidate whose requirements are unlocked.

## Tests

Tests are plain Lua scripts with no framework. Each defines a local `check(label, cond)`, prints a pass/fail summary, and exits non-zero on failure. `tests/mock_windower.lua` installs a fake global `windower` (chat log, IPC, sent commands, events, player/party/info). Tests `dofile` the real addon source and then drive it with `mock.fire_event('addon command', ...)`. Call `mock.reset()` and `mock.install()` before each reload. To add coverage for a new Windower API call, extend the mock first.
