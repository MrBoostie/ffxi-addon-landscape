# Odin end-to-end addon sweep — 2026-04-28

Scope: full repository validation, Lua prototype sweep, catalog/schema consistency checks, and a targeted public GitHub discovery pass for FFXI Windower/Ashita addons that were not present in the normalized catalog.

## Validation commands

- `./scripts/validate_addons.sh`
- `./scripts/validate.sh`
- JSON/CSV parity check for catalog row counts and addon keys
- Manual GitHub discovery using searches for Windower, Ashita, HorizonXI, and FFXI addon repositories

## Bug fixed

`addons/SessionConductor/sessionconductor.lua` used Lua 5.2+ `goto` syntax in the rule loop. Windower-era Lua is Lua 5.1, and the repository's local `lua5.1`/`luac5.1` validation failed with:

```text
luac: addons/SessionConductor/sessionconductor.lua:430: '=' expected near 'continue_rule'
```

The rule loop now uses normal Lua 5.1-compatible control flow while preserving cooldown, max-fire, action execution, and lockout behavior.

## Catalog additions

The following documented public addons were missing from the normalized catalog and were added to both JSON and CSV artifacts:

| Addon | Repository | Loader/ecosystem evidence | Why included |
| --- | --- | --- | --- |
| GearInfo | `sebyg666/GearInfo` | Repository description: FFXI Windower addon; Lua addon files present | Widely referenced GearSwap support addon for gear/buff/combat state |
| xivpetbar | `Icydeath/ffxi-xivpetbar-addon` | README describes a Windower addon and install path | Pet HP/MP/TP status bar addon distinct from existing xivbar/xivparty entries |
| TimeTrigger | `Icydeath/FFXI-TimeTrigger` | README documents Windower addon install and commands | Runs commands at configured Vana'diel times |
| RandoMount | `erkamerf/RandoMount` | README documents Windower addon load command | Quality-of-life random mount selector |
| CTimers | `murrain/ctimers` | README documents Windower commands | Custom timer addon with countdown and HNM-style alarm support |
| STFU | `aravikusu/stfu` | README identifies FFXI Windower addon | Chat spam/harassment blacklist automation |
| WeatherWatch | `cocosolos/WeatherWatch` | README identifies Windower addon | Weather tracking/search and logging |
| HasteInfo | `shastaxc/HasteInfo` | README identifies Windower addon and GearSwap integration | Haste/dual-wield calculation support for gear logic |
| CampBuddy | `JamesAnBo/CampBuddy` | README identifies Ashita addon | Placeholder/repop timer management for camps |
| Grimoire | `glitchv0/grimoire` | README identifies Ashita addon | Searchable spell compendium and acquisition tracker |
| Limbox | `Quenala/Limbox` | README identifies a Windower addon and `//lua load limbox` install | Limbus/Temenos/Apollyon progress, key-item, floor, and point tracker |
| Hivemind | `Broguypal/Addons` | README identifies a Windower 4 addon | Relays tell and linkshell chat across multiboxed characters |
| TrueTargetLock | `Broguypal/Addons` | README identifies a Windower addon and `//lua load TrueTargetLock` install | Keeps melee characters facing current combat target |
| Wardrobe9 | `Broguypal/Addons` | README identifies a Windower 4 addon | GearSwap wardrobe analysis and inventory placement assistant |

## Deferred candidates

Several additional public repositories looked relevant but need deeper loader/API review before catalog inclusion. They were intentionally not added in this pass because the goal was clean, documented, defensible catalog entries rather than stuffing the tree like a panicked quartermaster.

- `DFPercush/Transmission`
- `ekrividus/autoNukes`
- `ekrividus/Attendance`
- `ekrividus/Sublimator`
- `xurion/ffxi-gil-ledger`
- `CRGorman/Facing`
- `Icydeath/FFXI-CurrentJobText`
- `garyfromwork/mp3`
- `garyfromwork/AutoJob`
- `lpelosi/topbar`
- `JamesAnBo/ForceAutoTarget`
- `ggVGsVivi/spellsea`
- `Applesmmmmmmmm/TreasureTimer`

## Notes

The catalog still contains pre-existing weak descriptions harvested from README/code fragments. This pass focused on discovered missing addons plus one blocking Lua compatibility bug. A follow-up cleanup should rewrite remaining noisy descriptions such as entries beginning with Markdown headings, copyright banners, or raw Lua snippets.
