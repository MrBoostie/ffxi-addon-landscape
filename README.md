# FFXI Addon Landscape

[![GitHub Pages](https://img.shields.io/badge/pages-live-2ea44f?style=flat-square)](https://mrboostie.github.io/ffxi-addon-landscape/)
![GitHub last commit](https://img.shields.io/github/last-commit/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub repo size](https://img.shields.io/github/repo-size/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub stars](https://img.shields.io/github/stars/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub forks](https://img.shields.io/github/forks/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub pull requests](https://img.shields.io/github/issues-pr/MrBoostie/ffxi-addon-landscape?style=flat-square)

Curated FFXI addon index + practical Windower addon suite (TravelRouter, SessionConductor, AddonHealth).

- Live index: <https://mrboostie.github.io/ffxi-addon-landscape/>
- Repo: <https://github.com/MrBoostie/ffxi-addon-landscape>

## 🔥 Why this exists

If you want to build new FFXI addons, the ecosystem is fragmented across many repos, forks, and one-off tools.

This project gives you:
- A cross-repo addon index
- A normalized catalog (JSON + CSV), including source-aware descriptions when available
- A first-pass opportunity/gap analysis
- A shortlist of high-ROI addon ideas
- Two complete addons in this repo (TravelRouter + SessionConductor)

## 📦 Included artifacts

- `ffxi_addons_index_raw.json`  
  Raw first-pass repo scan data (repo metadata + discovered addon directories)

- `ffxi-addon-catalog-normalized.json`  
  Normalized addon catalog with inferred categories + scores

- `ffxi-addon-catalog-normalized.csv`  
  Spreadsheet-friendly version of the normalized catalog

- `ffxi-addon-landscape-2026-04-22.md`  
  Human-readable ecosystem overview and recurring addon patterns

- `ffxi-addon-opportunity-shortlist-2026-04-22.md`  
  Top opportunities to build next

## 🌐 Useful upstream repos

### Multi-addon collections
- ProjectTako — mixed Windower/Ashita addon bundle (utility + combat helpers): <https://github.com/ProjectTako/ffxi-addons>
- Ivaar — automation-heavy Windower collection (Auto job helpers, trading/inventory QoL): <https://github.com/Ivaar/Windower-addons>
- Icydeath — large historical bundle/fork set spanning many popular addons: <https://github.com/Icydeath/ffxi-addons>
- lili-ffxi — modern, actively maintained Windower QoL addon set: <https://github.com/lili-ffxi/FFXI-Addons>
- DiscipleOfEris — era/private-server oriented Windower variants and utility tweaks: <https://github.com/DiscipleOfEris/Windower4Addons>

### Notable focused addons/tools
- superwarp — travel/warp command helper: <https://github.com/AkadenTK/superwarp>
- Skillchains — live skillchain display/timing aid: <https://github.com/Ivaar/Skillchains>
- parse — combat parser and output tracking: <https://github.com/flippant/parse>
- HealBot — automated healing support logic: <https://github.com/lorand-ffxi/HealBot>
- autoAssist — party assist targeting automation helper: <https://github.com/ekrividus/autoAssist>

### Official docs
- Windower docs: <https://docs.windower.net/>

## 🧠 Initial findings (TL;DR)

Recurring "core ecosystem" addons across repos include:
- GearSwap
- FastCS
- SellNPC
- Skillchains
- AuctionHelper
- DressUp
- InvSpace
- Treasury

Gaps worth building:
1. Better onboarding for returning/new players
2. Cross-addon observability/health dashboard
3. Safer automation policy controls + auditability
4. Better party coordination UX
5. Portable profile/config sync tooling

## 🗂️ Repository layout

- `addons/` — complete Windower addons included with this project
- `specs/` — implementation specs and command surfaces
- `docs/` — roadmap and reference links used during the landscape scan
- catalog/index files in the repo root — generated research artifacts for analysis and filtering

## ▶️ Using the addons

Copy each addon folder into your Windower `addons/` directory, then load them in game:

```text
//lua load TravelRouter
//lua load SessionConductor
```

Suggested smoke test:

```text
//troute list
//troute search je
//troute plan jeuno
//conductor ping
//conductor travel jeuno
//addonhealth check
//addonhealth export json
```

If you only load `SessionConductor`, the `travel` command will still broadcast, but actual route execution expects `TravelRouter` to be present on the receiving instance.

## 🧪 Addons included

- `addons/TravelRouter` — content-aware travel route planner/executor
- `addons/SessionConductor` — multi-character command coordinator
  - integrates with TravelRouter via `//conductor travel <destination>`
  - includes v1.1 event/rule automation engine (`rules.default.lua` + overrides)
- `addons/AddonHealth` — health/diagnostics dashboard for addon stack, with optional user-extended monitoring catalog via `data/addons.user.lua`

See specs:
- `specs/travelrouter-v1.0.md`
- `specs/sessionconductor-v1.0.md`
- `specs/sessionconductor-v1.1-triggers.md` (event-driven automation model)

## ✅ Production checklist

### TravelRouter
- Copy `addons/TravelRouter` into Windower `addons/`
- Load: `//lua load TravelRouter`
- Verify routes: `//troute list`
- Verify planner: `//troute plan jeuno`
- Verify route scoring detail: `//troute explain jeuno`
- Verify route preflight: `//troute audit jeuno`
- Verify execution: `//troute run jeuno`
- (Optional) Configure unlock tokens: `//troute unlock add hp|sg|warp`
- (Optional) Add typo-friendly shortcuts: `//troute alias add <alias> <destination>`
- (Optional) Persist custom routes: `//troute add <dest> <step1> ; <step2>` then `//troute save`

### SessionConductor
- Copy `addons/SessionConductor` into Windower `addons/`
- Load: `//lua load SessionConductor`
- Confirm roster: `//conductor roster list`
- Add peers: `//conductor roster add <group> <name>`
- Set active target: `//conductor target <group|all>`
- Connectivity check: `//conductor ping`
- Verify travel orchestration: `//conductor travel jeuno`
- Review ACK/timeouts: `//conductor status`

### AddonHealth
- Copy `addons/AddonHealth` into Windower `addons/`
- Load: `//lua load AddonHealth`
- Run diagnostics: `//addonhealth check`
- Export text report: `//addonhealth export`
- Export JSON report (automation-friendly): `//addonhealth export json`

### Safety defaults
- Remote command execution is disabled by default.
- Enable only for trusted groups: `//conductor remotecmd on`
- Disable again when done: `//conductor remotecmd off`

## 🔧 Regenerate source-aware descriptions

```bash
python3 scripts/enrich_descriptions.py
```

This pulls README text from indexed repos and assigns best-effort description sources per addon.

## ✅ Local validation

```bash
./scripts/validate_addons.sh
```

Runs Lua syntax checks for addon files plus JSON parse validation for generated artifacts.

## 🚀 Next steps

- Expand scan from 19 repos → full ecosystem crawl
- Add richer metadata per addon (maintainer activity, dependencies, compatibility)
- Generate a public web view (filters: category, recency, popularity)
- Keep improving addon behavior/tests and operational docs for TravelRouter + SessionConductor

## ⚠️ Notes

- This is a practical, heuristic index (not perfect classification).
- Some repos include both Windower and Ashita content.
- Categories are inferred from names/description and should be refined over time.

---

PRs welcome. Bring weird FFXI archaeology.
