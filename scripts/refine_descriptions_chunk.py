#!/usr/bin/env python3
import csv
import json
import math
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ffxi-addon-catalog-normalized.json'
CSV_OUT = ROOT / 'ffxi-addon-catalog-normalized.csv'


def now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def run(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


def gh_json(path: str):
    return json.loads(run(['gh', 'api', path]))


def gh_raw(path: str) -> str:
    return run(['gh', 'api', path, '-H', 'Accept: application/vnd.github.raw+json'])


def clean(s: str) -> str:
    s = re.sub(r'```[\s\S]*?```', ' ', s)
    s = re.sub(r'!\[[^\]]*\]\([^\)]*\)', ' ', s)
    s = re.sub(r'\[([^\]]+)\]\([^\)]*\)', r'\1', s)
    s = re.sub(r'`([^`]+)`', r'\1', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()


def infer_from_lua(repo: str, addon_dir: str):
    try:
        listing = gh_json(f'repos/{repo}/contents/{addon_dir}')
    except Exception:
        return '', ''

    lua_files = [x['path'] for x in listing if isinstance(x, dict) and x.get('type') == 'file' and str(x.get('name', '')).lower().endswith('.lua')]
    lua_files = lua_files[:5]

    for path in lua_files:
        try:
            txt = gh_raw(f'repos/{repo}/contents/{path}')
        except Exception:
            continue

        m = re.search(r"_addon\.description\s*=\s*['\"]([^'\"]{12,220})['\"]", txt)
        if m:
            return clean(m.group(1))[:220], f'https://github.com/{repo}/blob/HEAD/{path}'

        comment_lines = []
        for ln in txt.splitlines()[:140]:
            s = ln.strip()
            if s.startswith('--'):
                s = re.sub(r'^--+\s*', '', s)
                if len(s) >= 20 and not s.lower().startswith(('copyright', 'license', 'todo')):
                    comment_lines.append(s)
        if comment_lines:
            return clean(' '.join(comment_lines[:2]))[:220], f'https://github.com/{repo}/blob/HEAD/{path}'

    return '', ''


def infer_from_readme(repo: str, addon_name: str):
    for readme in ['README.md', 'Readme.md', 'readme.md', 'README.txt']:
        try:
            md = gh_raw(f'repos/{repo}/contents/{readme}')
        except Exception:
            continue
        txt = clean(md)
        sents = [s.strip() for s in re.split(r'(?<=[.!?])\s+', txt) if len(s.strip()) >= 35]
        for s in sents[:40]:
            if addon_name.lower() in s.lower():
                return s[:220], f'https://github.com/{repo}/blob/HEAD/{readme}'
        if sents:
            return sents[0][:220], f'https://github.com/{repo}/blob/HEAD/{readme}'
    return '', ''


def write_csv(catalog):
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


def main():
    catalog = json.loads(CATALOG.read_text())
    total = len(catalog)
    chunk = max(1, math.ceil(total * 0.10))

    pending = [a for a in catalog if not a.get('description_reviewed_at')]
    target = pending[:chunk]

    for a in target:
        addon = a.get('addon_name', '')
        repos = a.get('repos', [])
        desc, src = '', ''

        for repo in repos[:4]:
            addon_dir = addon
            cand, cand_src = infer_from_lua(repo, addon_dir)
            if cand:
                desc, src = cand, cand_src
                a['description_confidence'] = 'high'
                break

        if not desc:
            for repo in repos[:4]:
                cand, cand_src = infer_from_readme(repo, addon)
                if cand:
                    desc, src = cand, cand_src
                    a['description_confidence'] = 'medium'
                    break

        if desc:
            a['description'] = desc
            a['description_source'] = src
        a['description_reviewed_at'] = now_iso()

    CATALOG.write_text(json.dumps(catalog, indent=2))
    write_csv(catalog)

    remaining = len([a for a in catalog if not a.get('description_reviewed_at')])
    print(f'refined={len(target)} total={total} remaining={remaining}')
    if remaining == 0:
        print('DONE_ALL_DESCRIPTIONS')


if __name__ == '__main__':
    main()
