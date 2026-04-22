# AddonHealth v0.1 Spec (Draft)

## Goal
Provide a single in-game health dashboard for Windower addon stack status, common errors, and quick diagnostics.

## Problem
Players run many addons with fragmented visibility. When things break, root-cause is slow and annoying.

## v0.1 Scope

### Commands
- `//addonhealth` → open summary panel
- `//addonhealth check` → run quick diagnostics
- `//addonhealth watch on|off` → toggle periodic checks
- `//addonhealth export` → dump snapshot to file

### Data surfaced
- loaded addon list
- missing dependencies (best effort)
- last command errors (if hookable)
- packet lag/jitter hints (best effort)
- suspicious state (duplicate loads, conflicts)

### Output modes
- compact HUD text block
- optional log export (`data/addonhealth-report-<timestamp>.txt`)

## Non-goals (v0.1)
- automatic fixing of configs
- deep packet decoding for every addon
- remote telemetry

## Open questions
1. Which Windower APIs expose addon load/error state directly?
2. Best UX for low-noise alerts in combat?
3. Where to persist baseline health snapshots?

## Milestones
1. API feasibility spike
2. command parser + check runner
3. minimal HUD output
4. export + docs
