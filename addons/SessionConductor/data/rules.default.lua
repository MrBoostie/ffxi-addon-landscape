return {
  {
    id = 'rule.safety.emergency_hp_collapse',
    enabled = true,
    priority = 100,
    cooldown_sec = 20,
    lockout_group = 'emergency',
    lockout_sec = 10,
    when = {
      event = 'party.member.hp_critical',
      where = {
        { field = 'payload.hp_pct', op = '<=', value = 25 },
      },
    },
    then_actions = {
      { kind = 'mode.set', mode = 'emergency' },
      { kind = 'notify', text = 'Emergency mode entered due to critical HP event.' },
    },
  },
  {
    id = 'rule.party.heal_low_hp',
    enabled = true,
    priority = 70,
    cooldown_sec = 8,
    lockout_group = 'recovery',
    lockout_sec = 3,
    when = {
      event = 'party.member.hp_low',
      where = {
        { field = 'payload.hp_pct', op = '<=', value = 40 },
      },
    },
    then_actions = {
      { kind = 'broadcast.command', cmd = 'input /ma "Cure IV" <t>' },
    },
  },
  {
    id = 'rule.party.raise_on_ko',
    enabled = true,
    priority = 80,
    cooldown_sec = 15,
    lockout_group = 'recovery',
    lockout_sec = 5,
    when = {
      event = 'party.member.ko',
    },
    then_actions = {
      { kind = 'mode.set', mode = 'recovery' },
      { kind = 'notify', text = 'KO detected, recovery flow triggered.' },
    },
  },
  {
    id = 'rule.world.recover_after_zone',
    enabled = true,
    priority = 60,
    cooldown_sec = 20,
    lockout_group = 'travel',
    lockout_sec = 3,
    when = {
      event = 'world.zone_changed',
    },
    then_actions = {
      { kind = 'notify', text = 'Zone changed, resyncing follow.' },
      { kind = 'broadcast.command', cmd = 'input /follow <me>' },
    },
  },
  {
    id = 'rule.system.retry_exhausted_alert',
    enabled = true,
    priority = 95,
    cooldown_sec = 4,
    when = {
      event = 'system.retry_exhausted',
    },
    then_actions = {
      { kind = 'notify', text = 'Retry exhausted for remote request.' },
    },
  },
}
