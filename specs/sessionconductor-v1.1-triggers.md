# SessionConductor v1.1 Trigger Spec

## Goal
Shift SessionConductor from primarily command-broadcast tooling to **event-driven party automation orchestration**.

The design centers on:
- deterministic event detection
- declarative trigger rules
- bounded/safe automation actions
- explicit operator override

---

## 1) Event model

All triggers consume normalized events from a shared event bus.

### Event envelope

```lua
{
  id = "evt-<timestamp>-<seq>",
  type = "party.member.hp_low",   -- see catalog below
  ts = 1712345678,                 -- unix epoch seconds
  source = "local|remote|system",
  actor = "CharacterName",        -- who emitted / detected
  zone = 230,
  party = {
    leader = "LeaderName",
    size = 6,
  },
  payload = { ... }                -- event-specific fields
}
```

### Event categories

#### A) Party-state events
- `party.member.hp_low`
- `party.member.hp_critical`
- `party.member.ko`
- `party.member.raised`
- `party.member.debuff_added`
- `party.member.debuff_removed`
- `party.member.distance_exceeded`

Payload examples:
```lua
{ member = "Bob", hp_pct = 28, threshold = 30 }
{ member = "Alice", debuff = "silence" }
{ member = "Cara", distance = 32.5, max_distance = 20 }
```

#### B) Combat lifecycle events
- `combat.engaged`
- `combat.disengaged`
- `combat.target_changed`
- `combat.target_died`
- `combat.idle_timeout`

Payload examples:
```lua
{ target = "Apex Crab", target_id = 123456 }
{ prev_target_id = 123456, target_id = 123457 }
```

#### C) Skillchain/burst events
- `combat.ws_used`
- `combat.skillchain_open`
- `combat.skillchain_close`
- `combat.mb_window_open`
- `combat.mb_window_close`

Payload examples:
```lua
{ actor = "Leader", ws = "Savage Blade", target_id = 123456 }
{ chain = "Light", window_ms = 8000 }
```

#### D) Zone/content events
- `world.zone_changed`
- `world.instance_entered`
- `world.instance_exited`
- `world.cutscene_end`

Payload examples:
```lua
{ zone_id = 230, zone_name = "Western Adoulin" }
{ content = "Omen" }
```

#### E) Reliability/safety events
- `system.ack_timeout`
- `system.peer_unreachable`
- `system.retry_exhausted`
- `system.emergency_mode_entered`
- `system.emergency_mode_cleared`

Payload examples:
```lua
{ req = "1712-9931", peer = "Bob", timeout_sec = 10 }
{ reason = "party_hp_collapse" }
```

---

## 2) Trigger rule DSL

Rules are user-configurable and evaluated in priority order.

### Rule shape

```lua
{
  id = "rule.emergency.hp_collapse",
  enabled = true,
  priority = 100,              -- higher first
  cooldown_sec = 20,
  max_fires = 999,
  lockout_group = "emergency", -- prevents conflicting rules firing simultaneously

  when = {
    event = "party.member.hp_critical",
    where = {
      { field = "payload.hp_pct", op = "<=", value = 25 },
      { field = "party.size", op = ">=", value = 3 },
    },
    for_sec = 2,               -- condition stability window
  },

  then_actions = {
    { kind = "mode.set", mode = "emergency" },
    { kind = "broadcast.command", cmd = "input /ja \"Divine Seal\" <me>" },
    { kind = "notify", text = "Emergency mode activated" },
  }
}
```

### Supported operators
- `==`, `!=`, `>`, `>=`, `<`, `<=`
- `in`, `not_in`
- `contains`, `not_contains`
- `matches` (Lua pattern)

### Rule files
- `addons/SessionConductor/data/rules.default.lua` (shipped baseline)
- `addons/SessionConductor/data/rules.user.lua` (user overrides)

Merge behavior:
- same `id` in user rules overrides default rule
- missing ids from defaults remain active

---

## 3) Action catalog

Actions are explicit and typed (no arbitrary eval).

### Core actions
- `mode.set` — set conductor mode (`normal|recovery|emergency|travel`)
- `broadcast.travel` — invoke `TravelRouter` across target scope
- `broadcast.command` — send command (subject to remote command safety policy)
- `roster.target_set` — change active target group
- `retry.schedule` — schedule retriable operation
- `notify` — local chat/log notification
- `rule.disable` — temporary disable a rule by id

### TravelRouter integration action

```lua
{ kind = "broadcast.travel", destination = "jeuno" }
```

Execution behavior:
1. local TravelRouter run
2. SC2 dispatch to peers in current target group
3. ACK tracking + timeout handling

---

## 4) Priority / lockout model

### Evaluation flow
1. Ingest event
2. Find matching enabled rules
3. Sort by `priority` descending
4. Skip rules in active lockout groups
5. Enforce cooldown and max_fires
6. Execute actions

### Lockout groups
Use lockouts to avoid contradictory automations:
- `combat_rotation`
- `recovery`
- `emergency`
- `travel`

Example:
- if `emergency` lockout active, suppress lower-priority rotation rules.

---

## 5) Safety rails (required)

### A) Cooldowns and burst limits
- per-rule cooldown (`cooldown_sec`)
- global action rate limit (e.g., max 5 actions / 10 sec)

### B) Retry limits
- default `max_retries = 2`
- exponential backoff: 1s, 2s
- emit `system.retry_exhausted` event on failure

### C) Human override
Operator commands:
- `//conductor auto on|off`
- `//conductor mode <normal|recovery|emergency|travel>`
- `//conductor pause <seconds>`
- `//conductor rule enable <id>`
- `//conductor rule disable <id>`

### D) Remote command policy
- default: remote raw command execution disabled
- allowlist mode for trigger-driven command actions
- reject actions from untrusted senders

### E) Safe-zone guard
Rules may define zone allow/deny filters:

```lua
zones = { allow = {230, 231}, deny = {256} }
```

---

## 6) Suggested baseline rules (ship in defaults)

1. `rule.party.heal_low_hp`
- on `party.member.hp_low` (<=40)
- action: broadcast role-appropriate heal command

2. `rule.party.raise_on_ko`
- on `party.member.ko`
- action: recovery mode + raise flow

3. `rule.combat.reengage_on_target_change`
- on `combat.target_changed`
- action: assist/follow target sync

4. `rule.sc.mb_followup`
- on `combat.skillchain_open`
- action: MB queue for caster subgroup

5. `rule.world.recover_after_zone`
- on `world.zone_changed`
- action: resync follow/assist + buff check

6. `rule.safety.emergency_hp_collapse`
- multiple `hp_critical` events in short window
- action: emergency mode + suspend offensive rules

---

## 7) Observability and debugging

### Runtime introspection commands
- `//conductor events tail [N]`
- `//conductor rules list`
- `//conductor rules explain <eventType>`
- `//conductor trace on|off`

### Event history
Persist short rolling history:
- `addons/SessionConductor/data/events.log` (or `.jsonl`)
- include: event id, matched rules, fired actions, result

---

## 8) Compatibility and migration

- Keep current SC2/SC2R transport.
- Trigger engine is an internal layer above SC2.
- Legacy command paths remain functional.

Migration order:
1. event normalization layer
2. rule evaluator (read-only dry-run)
3. action execution with safety rails
4. enable selected default rules

---

## 9) Acceptance criteria for v1.1

1. Event bus supports at least 12 event types across 4 categories.
2. Rules from default+user files merge and evaluate deterministically.
3. At least 5 default rules execute actions with cooldown/lockout safeguards.
4. Human override commands can pause/disable automation instantly.
5. ACK timeout/retry emits corresponding system events.
6. Debug commands can explain why a rule fired or was skipped.

---

## 10) Out of scope (v1.1)

- ML-driven prediction
- full strategy planner UI
- automatic role inference without user config

These can be layered in v1.2+ once event/rule reliability is proven.
