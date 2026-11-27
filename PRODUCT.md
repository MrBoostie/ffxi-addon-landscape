# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Single static HTML for the GitHub Pages site: one `index.html` with inline CSS and JS that fetches `ffxi-addon-catalog-normalized.json` at runtime. No build step.

## Users

Final Fantasy XI players who use Windower and are picking addons to install, for their job, the content they run (Sortie, Odyssey, Dynamis, Abyssea, Limbus and so on), or their playstyle (solo, multibox, crafting, gil-making).

## Product Purpose

A searchable index of community Windower addons gathered from across GitHub. The ecosystem is fragmented across hundreds of personal repos, forks and bundles; this site lets a player find what exists, what it does, and where to get it. Success: a player finds an addon that fits their need and reaches its repo.

## Positioning

The only cross-repo index: about 1,300 addons from roughly 940 repos, found by a reproducible GitHub discovery script (`scripts/discover.py`) rather than a hand-kept list, with a plain one-sentence description of what each addon does.

## Operating Context

Players usually browse outside the game (second monitor or alt-tab), with a goal like "something for Sortie" or "a better party list". They search by name, by content keyword, or by category, then open the GitHub repo to install the addon into their Windower `addons/` folder.

## Capabilities and Constraints

- Data per addon: name, key, one-sentence description, description source (a URL or a pass label), description confidence (high/medium/low), category (8 inferred categories, `general_qol` the default), source repos, best repo stars, last-pushed date (`freshness_max`, mixed date formats), and `opportunity_score` (not shown to players).
- Must keep: the recommended starter packs (Beginner QoL, Advanced optimization/multibox, and the tongue-in-cheek "Trying to get Banned" risky pack); a link to each description's source plus its confidence; links to the research material (forum sweep, discovery report, landscape writeups).
- Discovery is Windower-only; older Ashita entries remain in the data.

## Brand Commitments

Name: "FFXI Addon Landscape". Voice is practical and a little playful (the "Trying to get Banned" pack, "Bring weird FFXI archaeology").

## Evidence on Hand

- `ffxi-addon-catalog-normalized.json` (1,298 entries), the raw repo index, and `discovery/report-2026-11-27.md`.
- No screenshots, logos, testimonials or usage numbers exist; none may be invented.
- Not affiliated with Square Enix or Windower; game art and logos are not available to use.

## Product Principles

1. Finding beats browsing: a player with a goal should reach a matching addon in seconds.
2. Say what an addon does in plain words; show where the claim came from.
3. Be honest about risk: automation and packet-level addons are flagged, not hidden.
4. The index is the product; research and process material stays one click away, not in the way.
