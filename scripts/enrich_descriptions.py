#!/usr/bin/env python3
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ffxi-addon-catalog-normalized.json'
RAW = ROOT / 'ffxi_addons_index_raw.json'


def norm(s: str) -> str:
    return re.sub(r'[^a-z0-9]+', '', s.lower())


def gh_api_raw(path: str) -> str:
    return subprocess.check_output(
        ['gh', 'api', path, '-H', 'Accept: application/vnd.github.raw+json'],
        text=True,
        stderr=subprocess.DEVNULL,
    )


def clean_text(s: str) -> str:
    s = re.sub(r'```[\s\S]*?```', ' ', s)
    s = re.sub(r'!\[[^\]]*\]\([^\)]*\)', ' ', s)
    s = re.sub(r'\[([^\]]+)\]\([^\)]*\)', r'\1', s)
    s = re.sub(r'`([^`]+)`', r'\1', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()


def split_sentences(md: str):
    lines = []
    for ln in md.replace('\r\n', '\n').split('\n'):
        l = ln.strip()
        if not l or l.startswith('#') or l.startswith('>') or l.startswith('|'):
            continue
        if re.match(r'^[-*]\s+', l):
            l = re.sub(r'^[-*]\s+', '', l)
        lines.append(l)
    text = clean_text(' '.join(lines))
    sents = re.split(r'(?<=[.!?])\s+', text)
    return [s.strip() for s in sents if len(s.strip()) >= 30]


def addon_name_tokens(name: str):
    parts = re.findall(r'[a-z0-9]+', name.lower())
    return [p for p in parts if len(p) >= 3]


def score_sentence(sent: str, addon_name: str):
    s = sent.lower()
    score = 0
    if addon_name.lower() in s:
        score += 4
    for t in addon_name_tokens(addon_name):
        if t in s:
            score += 1
    return score


def heuristic_desc(name: str, cat: str):
    n = name.lower()
    if 'gearswap' in n:
        return 'Gear swap automation/rules framework for equipment sets and actions.'
    if 'fastcs' in n:
        return 'Speeds up or skips selected cutscene/menu interactions.'
    if 'sellnpc' in n:
        return 'Quickly sells items to NPC vendors with command-driven flow.'
    if 'skillchain' in n:
        return 'Displays skillchain windows/properties and timing during combat.'
    if 'auction' in n:
        return 'Auction House helper for item lookup/pricing and listing workflow.'
    if 'dressup' in n:
        return 'Appearance/lockstyle-style visual customization helpers.'
    if 'invspace' in n:
        return 'Inventory space tracking and bag pressure visibility.'
    if 'treasury' in n:
        return 'Loot/treasure pool handling and item distribution helpers.'
    if 'warp' in n or 'portal' in n:
        return 'Travel helper for warp/teleport interactions and route shortcuts.'
    if 'parse' in n or 'logger' in n or 'packet' in n:
        return 'Diagnostics/logging tool for combat or packet/event analysis.'
    if 'healbot' in n:
        return 'Automated healing assistant for party support behavior.'
    if 'assist' in n:
        return 'Auto-assist targeting helper for coordinated party combat.'
    if 'hotbar' in n or 'crossbar' in n or 'enemybar' in n or 'target' in n:
        return 'UI overlay component for combat actions, targets, or status visibility.'
    if 'auto' in n:
        return 'Automation helper for repeated combat/job tasks with command controls.'
    if cat == 'travel':
        return 'Travel and teleport quality-of-life helper.'
    if cat == 'combat_automation':
        return 'Combat automation helper for actions, timing, or party flow.'
    if cat == 'economy_inventory':
        return 'Economy/inventory utility for item movement, sales, and storage.'
    if cat == 'diagnostics':
        return 'Debugging, parsing, and runtime observability utility.'
    if cat == 'ui_gear':
        return 'UI/gear overlay or display enhancement.'
    if cat == 'chat_qol':
        return 'Chat and communication quality-of-life helper.'
    return 'General quality-of-life helper addon.'


def main():
    catalog = json.loads(CATALOG.read_text())
    raw = json.loads(RAW.read_text())

    repos = sorted({r['repo'] for r in raw})
    repo_sents = {}
    for repo in repos:
        try:
            md = gh_api_raw(f'repos/{repo}/readme')
            repo_sents[repo] = split_sentences(md)
        except Exception:
            repo_sents[repo] = []

    updated = 0
    sourced = 0

    for a in catalog:
        name = a.get('addon_name', '')
        cat = a.get('category', 'general_qol')
        best = ('', 0, '')  # sentence, score, repo

        for repo in a.get('repos', []):
            for sent in repo_sents.get(repo, []):
                sc = score_sentence(sent, name)
                if sc > best[1]:
                    best = (sent, sc, repo)

        if best[1] >= 2:
            desc = best[0]
            if len(desc) > 220:
                desc = desc[:220].rstrip() + '…'
            a['description'] = desc
            a['description_source'] = f'https://github.com/{best[2]}#readme'
            a['description_confidence'] = 'medium'
            sourced += 1
        else:
            a['description'] = heuristic_desc(name, cat)
            a['description_source'] = 'heuristic'
            a['description_confidence'] = 'low'

        updated += 1

    CATALOG.write_text(json.dumps(catalog, indent=2))
    print(f'Updated {updated} addons, source-aware descriptions for {sourced}')


if __name__ == '__main__':
    main()
