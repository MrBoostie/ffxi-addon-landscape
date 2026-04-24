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
RAW = ROOT / 'ffxi_addons_index_raw.json'
CSV_OUT = ROOT / 'ffxi-addon-catalog-normalized.csv'

BAD_PATTERNS = [
    r'welcome to my ffxi github',
    r'various ffxi projects',
    r'^source$',
    r'^unknown$',
    r'^n/?a$',
    r'collection of addons',
]


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


def norm(s: str) -> str:
    return re.sub(r'[^a-z0-9]+', '', (s or '').lower())


def is_weak(desc: str) -> bool:
    d = (desc or '').strip().lower()
    if len(d) < 24:
        return True
    for p in BAD_PATTERNS:
        if re.search(p, d):
            return True
    return False


def infer_from_lua_file(repo: str, path: str):
    try:
        txt = gh_raw(f'repos/{repo}/contents/{path}')
    except Exception:
        return '', ''

    m = re.search(r"_addon\.description\s*=\s*['\"]([^'\"]{12,260})['\"]", txt)
    if m:
        d = clean(m.group(1))[:220]
        if not is_weak(d):
            return d, f'https://github.com/{repo}/blob/HEAD/{path}'

    comment_lines = []
    for ln in txt.splitlines()[:180]:
        s = ln.strip()
        if s.startswith('--'):
            s = re.sub(r'^--+\s*', '', s)
            if len(s) >= 24 and not s.lower().startswith(('copyright', 'license', 'todo', 'usage')):
                comment_lines.append(s)
    if comment_lines:
        d = clean(' '.join(comment_lines[:2]))[:220]
        if not is_weak(d):
            return d, f'https://github.com/{repo}/blob/HEAD/{path}'

    return '', ''


def infer_from_dir_readme(repo: str, dir_path: str, addon_name: str):
    candidate_dirs = [dir_path]
    if not dir_path.startswith('addons/'):
        candidate_dirs.append(f'addons/{dir_path}')

    for readme in ['README.md', 'Readme.md', 'readme.md', 'README.txt']:
        md = None
        used_path = None
        for d in candidate_dirs:
            path = f'{d}/{readme}'
            try:
                md = gh_raw(f'repos/{repo}/contents/{path}')
                used_path = path
                break
            except Exception:
                continue
        if md is None:
            continue

        txt = clean(md)
        sents = [s.strip() for s in re.split(r'(?<=[.!?])\s+', txt) if len(s.strip()) >= 35]
        for s in sents[:60]:
            if addon_name.lower() in s.lower() and not is_weak(s):
                return s[:220], f'https://github.com/{repo}/blob/HEAD/{used_path}'

        for s in sents[:20]:
            if not is_weak(s):
                return s[:220], f'https://github.com/{repo}/blob/HEAD/{used_path}'

    return '', ''


def infer_from_repo_readme(repo: str, addon_name: str):
    for readme in ['README.md', 'Readme.md', 'readme.md', 'README.txt']:
        try:
            md = gh_raw(f'repos/{repo}/contents/{readme}')
        except Exception:
            continue
        txt = clean(md)
        sents = [s.strip() for s in re.split(r'(?<=[.!?])\s+', txt) if len(s.strip()) >= 35]
        for s in sents[:60]:
            if addon_name.lower() in s.lower() and not is_weak(s):
                return s[:220], f'https://github.com/{repo}/blob/HEAD/{readme}'
    return '', ''


def list_candidate_lua_paths(repo: str, addon_dir: str):
    out = []
    candidate_dirs = [addon_dir]
    if not addon_dir.startswith('addons/'):
        candidate_dirs.append(f'addons/{addon_dir}')

    for root_dir in candidate_dirs:
        try:
            listing = gh_json(f'repos/{repo}/contents/{root_dir}')
        except Exception:
            continue

        for e in listing:
            if not isinstance(e, dict):
                continue
            p = e.get('path', '')
            t = e.get('type', '')
            name = str(e.get('name', '')).lower()

            if t == 'file' and name.endswith('.lua'):
                out.append(p)
            elif t == 'dir' and name in {'data', 'docs', 'images', 'assets'}:
                continue
            elif t == 'dir':
                try:
                    sub = gh_json(f'repos/{repo}/contents/{p}')
                except Exception:
                    continue
                for se in sub:
                    if isinstance(se, dict) and se.get('type') == 'file' and str(se.get('name', '')).lower().endswith('.lua'):
                        out.append(se.get('path', ''))

    seen, uniq = set(), []
    for p in out:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq[:10]


def build_dir_map(raw_rows):
    # key: (repo, normalized-dir)
    m = {}
    for row in raw_rows:
        repo = row.get('repo')
        for d in row.get('addon_dirs', []) or []:
            k = (repo, norm(d))
            m.setdefault(k, []).append(d)
    return m


def candidate_dirs_for_addon(repo: str, addon_name: str, addon_key: str, dir_map):
    out = []
    keys = [norm(addon_key or ''), norm(addon_name or '')]
    for k in keys:
        if not k:
            continue
        out.extend(dir_map.get((repo, k), []))

    # Fuzzy fallback: near matches in same repo.
    if not out:
        target = norm(addon_name or '')
        for (r, dk), dirs in dir_map.items():
            if r != repo:
                continue
            if target and (target in dk or dk in target):
                out.extend(dirs)

    # Preserve order + unique
    seen, uniq = set(), []
    for d in out:
        if d not in seen:
            seen.add(d)
            uniq.append(d)
    return uniq[:4]


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
    raw_rows = json.loads(RAW.read_text())
    dir_map = build_dir_map(raw_rows)

    total = len(catalog)
    chunk = max(1, math.ceil(total * 0.10))

    weak = [a for a in catalog if is_weak(a.get('description', ''))]
    pending = [a for a in catalog if not a.get('description_reviewed_at')]

    target = []
    seen = set()
    for a in weak + pending:
        aid = a.get('addon_key') or a.get('addon_name')
        if aid in seen:
            continue
        seen.add(aid)
        target.append(a)
        if len(target) >= chunk:
            break

    refined = 0
    for a in target:
        addon = a.get('addon_name', '')
        key = a.get('addon_key', '')
        repos = a.get('repos', [])
        desc, src, conf = '', '', 'low'

        for repo in repos[:5]:
            dirs = candidate_dirs_for_addon(repo, addon, key, dir_map)
            for d in dirs:
                for lua_path in list_candidate_lua_paths(repo, d):
                    cand, cand_src = infer_from_lua_file(repo, lua_path)
                    if cand:
                        desc, src, conf = cand, cand_src, 'high'
                        break
                if desc:
                    break

                cand, cand_src = infer_from_dir_readme(repo, d, addon)
                if cand:
                    desc, src, conf = cand, cand_src, 'medium'
                    break
            if desc:
                break

        if not desc:
            for repo in repos[:5]:
                cand, cand_src = infer_from_repo_readme(repo, addon)
                if cand:
                    desc, src, conf = cand, cand_src, 'medium'
                    break

        if desc and not is_weak(desc):
            a['description'] = desc
            a['description_source'] = src
            a['description_confidence'] = conf
            refined += 1

        a['description_reviewed_at'] = now_iso()

    CATALOG.write_text(json.dumps(catalog, indent=2))
    write_csv(catalog)

    remaining = len([a for a in catalog if not a.get('description_reviewed_at') or is_weak(a.get('description', ''))])
    print(f'refined={refined} targeted={len(target)} total={total} remaining={remaining}')
    if remaining == 0:
        print('DONE_ALL_DESCRIPTIONS')


if __name__ == '__main__':
    main()
