-- Optional user overrides.
-- Any rule with the same `id` as a default rule will replace it.

return {
  -- Example:
  -- {
  --   id = 'rule.party.heal_low_hp',
  --   enabled = true,
  --   priority = 75,
  --   cooldown_sec = 6,
  --   when = {
  --     event = 'party.member.hp_low',
  --     where = {
  --       { field = 'payload.hp_pct', op = '<=', value = 45 },
  --     },
  --   },
  --   then_actions = {
  --     { kind = 'broadcast.command', cmd = 'input /ma "Cure IV" <t>' },
  --   },
  -- },
}
