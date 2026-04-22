# FFXI Addon Landscape

![GitHub last commit](https://img.shields.io/github/last-commit/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub repo size](https://img.shields.io/github/repo-size/MrBoostie/ffxi-addon-landscape?style=flat-square)
![GitHub stars](https://img.shields.io/github/stars/MrBoostie/ffxi-addon-landscape?style=flat-square)

A curated GitHub index + gap analysis for Final Fantasy XI addons (primarily Windower, with some Ashita mentions).

Live searchable index (GitHub Pages): <https://mrboostie.github.io/ffxi-addon-landscape/>

## 🔥 Why this exists

If you want to build new FFXI addons, the ecosystem is fragmented across many repos, forks, and one-off tools.

This project gives you:
- A cross-repo addon index
- A normalized catalog (JSON + CSV)
- A first-pass opportunity/gap analysis
- A shortlist of high-ROI addon ideas

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

## 🚀 Next steps

- Expand scan from 19 repos → full ecosystem crawl
- Add richer metadata per addon (maintainer activity, dependencies, compatibility)
- Generate a public web view (filters: category, recency, popularity)
- Start v0.1 implementation for one gap candidate:
  - `AddonHealth` (recommended)
  - or `OnboardingPilot`

## ⚠️ Notes

- This is a practical, heuristic index (not perfect classification).
- Some repos include both Windower and Ashita content.
- Categories are inferred from names/description and should be refined over time.

---

PRs welcome. Bring weird FFXI archaeology.
