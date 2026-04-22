#!/usr/bin/env python3
import csv
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ffxi-addon-catalog-normalized.json'
RAW = ROOT / 'ffxi_addons_index_raw.json'
CSV_OUT = ROOT / 'ffxi-addon-catalog-normalized.csv'


def norm(s: str) -> str:
    return re.sub(r'[^a-z0-9]+', '', s.lower())


def run(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


def gh_raw(path: str) -> str:
    return run(['gh', 'api', path, '-H', 'Accept: application/vnd.github.raw+json'])


def clean(s: str) -> str:
    s = re.sub(r'```[\s\S]*?```', ' ', s)
    s = re.sub(r'!\[[^\]]*\]\([^\)]*\)', ' ', s)
    s = re.sub(r'\[([^\]]+)\]\([^\)]*\)', r'\1', s)
    s = re.sub(r'`([^`]+)`', r'\1', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()


def extract_bullets(md: str):
    out = []
    for ln in md.replace('\r\n', '\n').split('\n'):
        s = ln.strip()
        if re.match(r'^[-*]\s+', s):
            out.append(clean(re.sub(r'^[-*]\s+', '', s)))
    return [x for x in out if len(x) >= 15]


def bullet_for_addon(md: str, addon_name: str):
    bullets = extract_bullets(md)
    k = norm(addon_name)
    for b in bullets:
        nb = norm(b)
        if k and k in nb:
            return b[:220]
    return ''


def sentence_for_addon(md: str, addon_name: str):
    txt = clean(md)
    sents = [s.strip() for s in re.split(r'(?<=[.!?])\s+', txt) if len(s.strip()) >= 30]
    k = norm(addon_name)
    best = ('', 0)
    for s in sents:
        sc = 0
        ns = norm(s)
        if k and k in ns:
            sc += 3
        if addon_name.lower() in s.lower():
            sc += 2
        if sc > best[1]:
            best = (s, sc)
    return best[0][:220] if best[1] else ''


def addon_local_desc(repo: str, addon_dir: str, addon_name: str):
    for readme in ['README.md', 'Readme.md', 'readme.md', 'README.txt', 'README.MD']:
        try:
            md = gh_raw(f'repos/{repo}/contents/{addon_dir}/{readme}')
            b = bullet_for_addon(md, addon_name)
            if b:
                return b, f'https://github.com/{repo}/blob/HEAD/{addon_dir}/{readme}', 'high'
            # fallback first good sentence
            s = sentence_for_addon(md, addon_name)
            if s:
                return s, f'https://github.com/{repo}/blob/HEAD/{addon_dir}/{readme}', 'high'
            # fallback opening paragraph-ish
            compact = clean(' '.join(md.splitlines()[:20]))
            if len(compact) > 30:
                return compact[:220], f'https://github.com/{repo}/blob/HEAD/{addon_dir}/{readme}', 'high'
        except Exception:
            continue
    return '', '', 'low'


def repo_readme_desc(repo: str, addon_name: str, repo_readme_cache):
    md = repo_readme_cache.get(repo, '')
    if not md:
        return '', '', 'low'
    b = bullet_for_addon(md, addon_name)
    if b:
        return b, f'https://github.com/{repo}#readme', 'medium'
    s = sentence_for_addon(md, addon_name)
    if s:
        return s, f'https://github.com/{repo}#readme', 'medium'
    return '', '', 'low'


def heuristic_desc(name: str, cat: str):
    n = name.lower()
    if 'gearswap' in n: return 'Loads and applies equipment sets automatically based on actions/status changes.'
    if 'fastcs' in n: return 'Skips or accelerates selected cutscene/menu interactions.'
    if 'sellnpc' in n: return 'Sells configured items to NPC vendors via shortcut commands.'
    if 'skillchain' in n: return 'Displays skillchain options/windows and timing during combat.'
    if 'auction' in n: return 'Auction House helper for faster listing/searching workflow.'
    if 'dressup' in n: return 'Applies visual appearance/style overrides.'
    if 'invspace' in n: return 'Monitors free inventory slots and bag pressure.'
    if 'treasury' in n: return 'Automates treasure pool lot/pass/drop decisions.'
    if 'warp' in n or 'portal' in n: return 'Travel/teleport helper for warp routes and NPC interactions.'
    if 'parse' in n: return 'Parses combat logs for damage/performance summaries.'
    if 'healbot' in n: return 'Automates healing/support spell behavior based on party state.'
    if 'assist' in n: return 'Keeps your target synced by assisting a chosen party member.'
    if 'hotbar' in n or 'crossbar' in n: return 'Provides an FFXIV-style hotbar/crossbar action interface.'
    if 'enemybar' in n or 'target' in n: return 'Shows enhanced target/enemy HP or status display overlays.'
    if 'auto' in n: return 'Automates repeated job or combat actions with rule-based logic.'
    if cat == 'economy_inventory': return 'Inventory/economy helper for storage, movement, and selling tasks.'
    if cat == 'diagnostics': return 'Diagnostic utility for logs, packets, or runtime behavior visibility.'
    if cat == 'ui_gear': return 'UI enhancement for combat, targeting, or gear visibility.'
    if cat == 'chat_qol': return 'Chat/communication quality-of-life utility.'
    if cat == 'travel': return 'Travel quality-of-life helper for warps and navigation.'
    if cat == 'combat_automation': return 'Combat helper automating timing, actions, or role behavior.'
    return 'General FFXI quality-of-life utility addon.'


def main():
    catalog = json.loads(CATALOG.read_text())
    raw_rows = json.loads(RAW.read_text())

    dir_map = {}
    repos = set()
    for row in raw_rows:
        repo = row.get('repo')
        repos.add(repo)
        for d in row.get('addon_dirs', []):
            dir_map.setdefault(norm(d), []).append((repo, d))

    repo_readme_cache = {}
    for i, repo in enumerate(sorted(repos), start=1):
        try:
            repo_readme_cache[repo] = gh_raw(f'repos/{repo}/readme')
        except Exception:
            repo_readme_cache[repo] = ''

    stats = {'high': 0, 'medium': 0, 'low': 0}

    for idx, a in enumerate(catalog, start=1):
        addon = a.get('addon_name', '')
        key = a.get('addon_key')
        repos = a.get('repos', [])
        candidates = [x for x in dir_map.get(key, []) if x[0] in repos][:4]

        d, src, conf = '', '', 'low'

        for repo, addon_dir in candidates:
            d, src, conf = addon_local_desc(repo, addon_dir, addon)
            if d:
                break

        if not d:
            for repo in repos[:4]:
                d, src, conf = repo_readme_desc(repo, addon, repo_readme_cache)
                if d:
                    break

        if not d:
            d = heuristic_desc(addon, a.get('category', 'general_qol'))
            src = 'heuristic'
            conf = 'low'

        a['description'] = d
        a['description_source'] = src
        a['description_confidence'] = conf
        stats[conf] += 1

    CATALOG.write_text(json.dumps(catalog, indent=2))

    with open(CSV_OUT, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow([
            'addon_key', 'addon_name', 'description', 'description_source', 'description_confidence',
            'category', 'repo_count', 'best_repo_stars', 'freshness_max', 'opportunity_score', 'repos'
        ])
        for a in catalog:
            w.writerow([
                a.get('addon_key', ''), a.get('addon_name', ''), a.get('description', ''),
                a.get('description_source', ''), a.get('description_confidence', ''),
                a.get('category', ''), a.get('repo_count', ''), a.get('best_repo_stars', ''),
                a.get('freshness_max', ''), a.get('opportunity_score', ''), ';'.join(a.get('repos', []))
            ])

    print(f"Descriptions refreshed. high={stats['high']} medium={stats['medium']} low={stats['low']}")


if __name__ == '__main__':
    main()
