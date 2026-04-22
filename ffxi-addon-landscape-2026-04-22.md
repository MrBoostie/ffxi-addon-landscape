# FFXI Addon Landscape (GitHub scan)

Date: 2026-04-22
Scope: Windower/Ashita addon repos + notable single-addon repos for FFXI.

## 1) Repos scanned (first pass)

- ProjectTako/ffxi-addons (99★, updated 2022)
- Ivaar/Windower-addons (79★, updated 2023)
- Icydeath/ffxi-addons (69★, updated 2022)
- lili-ffxi/FFXI-Addons (35★, updated 2026)
- mverteuil/windower4-addons (17★, updated 2016)
- Lygre/addons (18★, updated 2017)
- ValokAsura/WindowerAddons (14★, updated 2023)
- DiscipleOfEris/Windower4Addons (12★, updated 2024)
- AkadenTK/superwarp (55★, updated 2026)
- AkadenTK/enemybar2 (19★, updated 2021)
- Ivaar/Skillchains (50★, updated 2024)
- lorand-ffxi/HealBot (28★, updated 2018)
- flippant/parse (15★, updated 2023)
- ekrividus/autoAssist (13★, updated 2022)
- plus crossbar/hotbar repos (XIVHotbar, XIVHotbar2, xivcrossbar)

Raw data file: `ffxi_addons_index_raw.json`

## 2) Cross-repo index (high-signal, recurring addons)

These showed up repeatedly across different repos (good candidates for “core ecosystem”):

- AuctionHelper
- AutoRA
- battlemod
- cancel
- DressUp
- FastCS
- GearSwap
- HealBot
- InvSpace
- Logger
- organizer
- pointwatch
- Pouches
- shortcuts
- Skillchains / Skillchain
- Sparks
- TParty
- Trade
- Treasury
- zonetimer
- SellNPC

Most repeated names (3+ repos):
- SellNPC, GearSwap, FastCS (4 repos each)
- then the list above (3 repos each)

## 3) Specialized/high-value addons spotted

### Travel / movement
- superwarp
- RunicPortal
- WarpMenu
- OpenSesame
- Sprint

### Combat / jobs / automation
- AutoCOR, AutoDNC, AutoGEO, AutoPUP
- AutoWS, AutoSkillchain
- SimpleAssist, autoAssist
- Singer, MagicAssistant
- Skillchains (dedicated repo still active)

### UI / readability
- enemybar2
- XIVHotbar / XIVHotbar2 / xivcrossbar
- PartyBuffs / partybuffs
- TargetPlus / targetinfo variants

### Economy / inventory
- AuctionHelper
- SellNPC
- porter / PorterPacker
- Pouches
- InvSpace
- CrystalTrader

### Debugging / packet / parser
- PacketViewer
- PacketViewerLogViewer (external viewer)
- parse
- Logger

## 4) Maintenance signals (where to borrow from first)

More recently active repos worth prioritizing for reference code:
- lili-ffxi/FFXI-Addons (2026)
- AkadenTK/superwarp (2026)
- HealsCodes/statustimers (Ashita, 2026)
- Ivaar/Skillchains (2024)
- DiscipleOfEris/Windower4Addons (2024)

Older repos are still useful for patterns, but likely contain stale assumptions:
- mverteuil/windower4-addons (2016)
- Lygre/addons (2017)
- lorand-ffxi/HealBot (2018)

## 5) Gap analysis (what seems under-served)

Based on discovered addon themes, likely gaps to build against:

1. **Modern onboarding / UX glue**
   - Many power-user tools, fewer “new/returning player helper” flows.
   - Opportunity: guided setup addon (commands, gearswap checks, travel shortcuts, reminders).

2. **Cross-addon observability**
   - Lots of isolated tools, not much unified health dashboard.
   - Opportunity: one addon that reports status of major addons, packet lag hints, recast/engage state, and failures.

3. **Safer automation controls**
   - Automation exists, but guardrails and transparent state are inconsistent.
   - Opportunity: policy layer (safe zones, anti-spam, cooldown caps, manual override hotkey, action audit log).

4. **Party coordination tooling**
   - Assist exists, but richer multi-role orchestration appears fragmented.
   - Opportunity: lightweight party plan sync (skillchain windows, role prompts, buff responsibility map).

5. **Data sync + profile portability**
   - Configs are scattered across addon-specific files.
   - Opportunity: profile manager addon/companion schema for portable setups across characters.

6. **Era/private-server compatibility abstraction**
   - Several era-specific forks indicate repeated compatibility work.
   - Opportunity: compatibility shim library for packet/resource differences.

## 6) Suggested next step (for us)

Build a proper machine-readable catalog:

- `repo`
- `addon_name`
- `type/category`
- `windower/ashita/both`
- `last_commit`
- `stars`
- `active_maintainer?`
- `dependencies`
- `known_conflicts`

Then rank candidates by:
- active maintenance
- uniqueness (not duplicate of existing)
- user pain solved
- implementation complexity

---

If you want, I’ll do phase 2 next: produce a **normalized CSV/JSON index** of addon names mapped to repos + categories + freshness score, then shortlist 5 addon ideas with best ROI.