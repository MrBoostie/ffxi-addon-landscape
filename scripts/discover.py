#!/usr/bin/env python3
"""Discover Windower addons on GitHub that are not in the catalog yet.

Windower only: Ashita addons are detected and skipped (existing Ashita
entries in the catalog are left alone).

Pipeline:
  1. search  - GitHub repo search + code search, auto-sliced past the
               1000-result cap (repo search by created date, code search by
               file size).
  2. scan    - for every repo found, fetch the full git tree, find addon entry
               points (<dir>/<dir>.lua, or a root-level .lua), download them and
               keep those that declare `_addon.name` and are not Ashita.
  3. report  - compare against the catalog and write
               discovery/candidates.json + discovery/report-<date>.md.
  4. apply   - (separate, after review) merge chosen candidates into the
               catalog JSON/CSV and the raw index.

Subcommands:
  run      search + scan + report (resumable; results cached in discovery/.cache)
  report   rebuild the report from cache without hitting GitHub
  resolve  look up specific addon names (e.g. forum leads)
  apply    merge reviewed candidates into the catalog

Needs an authenticated `gh` CLI. Repo/code search and tree calls are rate
limited by GitHub; the script throttles itself and sleeps through resets.
"""
import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ffxi-addon-catalog-normalized.json'
CSV_OUT = ROOT / 'ffxi-addon-catalog-normalized.csv'
RAW = ROOT / 'ffxi_addons_index_raw.json'
OUT_DIR = ROOT / 'discovery'
CACHE = OUT_DIR / '.cache'
IGNORE_FILE = OUT_DIR / 'ignore.txt'

OFFICIAL_REPO = 'Windower/Lua'

REPO_QUERIES = [
    'windower language:lua',
    'windower addon',
    'windower4',
    'topic:windower',
    'topic:windower-addon',
    'topic:windower4',
    'topic:ffxi language:lua',
    'ffxi language:lua',
    '"final fantasy xi" language:lua',
    'ffxi addon',
    'ffxi addons',
]

# Addons whose repos never say "windower"/"ffxi" and aren't in GitHub's code index
# still tend to be named after FFXI content. Swept as `<term> in:name,description language:lua`.
CONTENT_TERMS = [
    'sortie', 'odyssey', 'sheol', 'ambuscade', 'dynamis', 'abyssea', 'omen', 'limbus', 'salvage',
    'nyzul', 'vagary', 'reive', 'voidwatch', 'unity', 'delve', 'escha', 'gearswap', 'skillchain',
    'vanadiel', "vana'diel", 'jeuno', 'bastok', 'sandoria', 'windurst', 'adoulin', 'mog house',
    'moghouse', 'empyrean', 'trusts', 'checkparam', 'xivbar', 'xivparty', 'treasury', 'superwarp',
]
REPO_QUERIES += [f'"{t}" in:name,description language:lua' for t in CONTENT_TERMS]

CODE_QUERIES = [
    '"_addon.name" language:lua',
    '"_addon.commands" language:lua',
    '"windower.register_event" "addon command" language:lua',
]

# Path segments that never hold an addon entry point.
SKIP_SEGMENTS = {'libs', 'lib', 'data', '.github', 'test', 'tests', 'spec', 'specs',
                 'examples', 'example', 'resources', 'res', 'node_modules', 'docs',
                 'vendor', 'third_party', 'thirdparty', 'reference_addons', 'backup', 'old', 'archive'}
# Keys that are never real addon names.
GENERIC_KEYS = {'init', 'main', 'test', 'tests', 'example', 'template', 'addon', 'myaddon',
                'sample', 'sampleaddon', 'exampleaddon', 'skeleton', 'boilerplate', 'helloworld', 'hello', 'new', 'untitled'}
MAX_ROOT_LUA = 8

CATEGORY_RULES = [
    ('travel_navigation', r'warp|travel|route|teleport|home ?point|waypoint|survival guide|\bmaps?\b|navigat'),
    ('economy_inventory', r'inventor|\bbags?\b|sell|auction|\bah\b|\bgil\b|loot|treasure|storage|porter|\bitems?\b|trade|craft'),
    ('combat_automation', r'skillchain|magic burst|weapon ?skill|\bws\b|nuke|rotation|auto.?(attack|ws|sc|mb|nuke|skill)'),
    ('automation', r'\bauto|\bbot\b|macro|automat|follow|assist|multibox'),
    ('ui_gear', r'gear|equip|\bhud\b|\bbar\b|\bui\b|display|overlay|hotbar|crossbar|wardrobe'),
    ('diagnostics', r'debug|packet|\blogs?\b|parse|monitor|diagnos|inspect|memory'),
]


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def norm(s):
    return re.sub(r'[^a-z0-9]+', '', (s or '').lower())


def today():
    return dt.date.today()


# --------------------------------------------------------------------------- GitHub


class GH:
    """Thin `gh api` wrapper with per-bucket throttling and rate-limit sleeps."""

    MIN_INTERVAL = {'search': 2.2, 'code': 6.5, 'core': 0.0}
    RESOURCE = {'search': 'search', 'code': 'code_search', 'core': 'core'}

    def __init__(self):
        self.last = {}
        self.locks = {b: threading.Lock() for b in self.MIN_INTERVAL}
        self.calls = {b: 0 for b in self.MIN_INTERVAL}

    def _throttle(self, bucket):
        with self.locks[bucket]:
            wait = self.MIN_INTERVAL[bucket] - (time.time() - self.last.get(bucket, 0))
            if wait > 0:
                time.sleep(wait)
            self.last[bucket] = time.time()

    def _sleep_for_reset(self, bucket):
        with self.locks[bucket]:
            try:
                rl = json.loads(subprocess.check_output(['gh', 'api', 'rate_limit'], text=True))
                res = rl['resources'][self.RESOURCE[bucket]]
                if res['remaining'] > 0:
                    secs = 60  # secondary (abuse) limit
                else:
                    secs = max(1, res['reset'] - int(time.time()) + 2)
            except Exception:
                secs = 60
            log(f'  rate limited ({bucket}); sleeping {secs}s')
            time.sleep(secs)

    def get(self, endpoint, params=None, bucket='core'):
        args = ['gh', 'api', '-X', 'GET', endpoint]
        for k, v in (params or {}).items():
            args += ['-f', f'{k}={v}']
        for attempt in range(8):
            self._throttle(bucket)
            self.calls[bucket] += 1
            p = subprocess.run(args, capture_output=True, text=True)
            if p.returncode == 0:
                return json.loads(p.stdout) if p.stdout.strip() else None
            err = (p.stderr + p.stdout).lower()
            if 'rate limit' in err or 'http 429' in err or ('http 403' in err and 'abuse' in err):
                self._sleep_for_reset(bucket)
                continue
            if any(c in err for c in ('http 404', 'http 409', 'http 422', 'http 451', 'http 403')):
                return None  # missing, empty, past the 1000 cap, blocked
            time.sleep(3 * (attempt + 1))  # 5xx / network: back off and retry
        raise RuntimeError(f'gh api failed repeatedly: {endpoint} {params}')


def fetch_raw(repo, ref, path):
    url = f'https://raw.githubusercontent.com/{repo}/{ref}/{urllib.parse.quote(path)}'
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=20) as r:
                data = r.read()
            for enc in ('utf-8', 'cp932'):  # many JP addon READMEs are Shift-JIS
                try:
                    return data.decode(enc)
                except UnicodeDecodeError:
                    pass
            return data.decode('utf-8', errors='replace')
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(2 * (attempt + 1))
        except Exception:
            time.sleep(2 * (attempt + 1))
    return None


# --------------------------------------------------------------------------- cache


def cache_path(kind, key):
    safe = re.sub(r'[^A-Za-z0-9_.-]+', '__', key)
    if len(safe) > 120:
        safe = safe[:80] + '-' + hashlib.sha1(key.encode()).hexdigest()[:16]
    return CACHE / kind / f'{safe}.json'


def cache_get(kind, key, max_age_hours=None):
    p = cache_path(kind, key)
    if not p.exists():
        return None
    data = json.loads(p.read_text())
    if max_age_hours is not None and time.time() - data.get('_cached_at', 0) > max_age_hours * 3600:
        return None
    return data


def cache_put(kind, key, data):
    p = cache_path(kind, key)
    p.parent.mkdir(parents=True, exist_ok=True)
    data = dict(data, _cached_at=time.time())
    tmp = p.with_suffix('.tmp')
    tmp.write_text(json.dumps(data))
    tmp.replace(p)


# --------------------------------------------------------------------------- search


def _repo_summary(item):
    return {
        'repo': item['full_name'],
        'stars': item.get('stargazers_count', 0),
        'pushed_at': item.get('pushed_at'),
        'created_at': item.get('created_at'),
        'description': item.get('description') or '',
        'fork': item.get('fork', False),
        'archived': item.get('archived', False),
        'default_branch': item.get('default_branch') or 'HEAD',
        'size': item.get('size', 1),
    }


def _paged(gh, endpoint, q, bucket, total, first):
    yield from first.get('items', [])
    pages = min(10, -(-min(total, 1000) // 100))
    for page in range(2, pages + 1):
        r = gh.get(endpoint, {'q': q, 'per_page': 100, 'page': page}, bucket)
        if not r or not r.get('items'):
            break
        yield from r['items']


def search_repos(gh, q, lo=dt.date(2008, 1, 1), hi=None):
    hi = hi or today()
    full = f'{q} created:{lo.isoformat()}..{hi.isoformat()}'
    first = gh.get('search/repositories', {'q': full, 'per_page': 100, 'page': 1}, 'search')
    if not first:
        return
    total = first.get('total_count', 0)
    if total > 1000 and lo < hi:
        mid = lo + (hi - lo) // 2
        yield from search_repos(gh, q, lo, mid)
        yield from search_repos(gh, q, mid + dt.timedelta(days=1), hi)
        return
    log(f'  repo search: {full} -> {total}')
    for item in _paged(gh, 'search/repositories', full, 'search', total, first):
        yield _repo_summary(item)


def search_code(gh, q, lo=0, hi=400_000):
    full = f'{q} size:{lo}..{hi}'
    first = gh.get('search/code', {'q': full, 'per_page': 100, 'page': 1}, 'code')
    if not first:
        return
    total = first.get('total_count', 0)
    if total > 1000 and hi - lo > 1:
        mid = (lo + hi) // 2
        yield from search_code(gh, q, lo, mid)
        yield from search_code(gh, q, mid + 1, hi)
        return
    log(f'  code search: {full} -> {total}')
    for item in _paged(gh, 'search/code', full, 'code', total, first):
        yield {'repo': item['repository']['full_name'], 'path': item['path'],
               'fork': item['repository'].get('fork', False)}


def cached_search(gh, kind, q, refresh, fn):
    hit = None if refresh else cache_get('search', f'{kind}:{q}', max_age_hours=24)
    if hit:
        log(f'  (cached) {kind}: {q} -> {len(hit["items"])}')
        return hit['items']
    items = list(fn(gh, q))
    cache_put('search', f'{kind}:{q}', {'items': items})
    return items


def collect(gh, repo_queries, code_queries, refresh):
    """Return {repo: summary-or-None} and {repo: set(code-hit paths)}."""
    repos, hits = {}, {}
    for q in repo_queries:
        for r in cached_search(gh, 'repo', q, refresh, search_repos):
            if r['fork'] or not r['size']:
                continue
            repos[r['repo']] = r
    for q in code_queries:
        for h in cached_search(gh, 'code', q, refresh, search_code):
            if h['fork']:
                continue
            hits.setdefault(h['repo'], set()).add(h['path'])
            repos.setdefault(h['repo'], None)
    return repos, hits


# --------------------------------------------------------------------------- scan

STR_RE = r"""(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"|\[\[(.*?)\]\])"""
FIELD_RE = re.compile(r'_addon\.(name|author|version|desc|description|language)\s*=\s*' + STR_RE, re.S)
COMMANDS_RE = re.compile(r'_addon\.commands\s*=\s*\{([^}]*)\}', re.S)


def parse_header(src):
    out = {}
    for m in FIELD_RE.finditer(src):
        key = m.group(1)
        if key == 'description':
            key = 'desc'
        if key not in out:
            out[key] = next(g for g in m.groups()[1:] if g is not None).strip()
    m = COMMANDS_RE.search(src)
    if m:
        out['commands'] = [a or b or c for a, b, c in re.findall(STR_RE, m.group(1), re.S)]
    return out


def ecosystem(src):
    if not re.search(r'_addon\.name\s*=', src):
        return None
    ashita = len(re.findall(r'\bashita\.|AshitaCore|ashita_core|AshitaCore:', src))
    windower = len(re.findall(r'\bwindower\.', src))
    if ashita and ashita >= windower:
        return 'ashita'
    return 'windower'


def entry_points(paths, repo):
    repo_name = repo.split('/')[1].lower()
    lua = [p for p in paths if p.lower().endswith('.lua')]
    out, root = [], []
    for p in lua:
        parts = p.split('/')
        if any(s.lower() in SKIP_SEGMENTS for s in parts[:-1]):
            continue
        stem = parts[-1][:-4].lower()
        if len(parts) >= 2 and stem == parts[-2].lower():
            out.append(p)
        elif len(parts) == 1:
            root.append(p)
    if len(root) > MAX_ROOT_LUA:
        root = [p for p in root if norm(p[:-4]) in (norm(repo_name), norm(repo_name.replace('ffxi', '')))]
    return out + root


def readme_for(paths, directory):
    prefix = f'{directory}/' if directory else ''
    for p in paths:
        rest = p[len(prefix):] if p.startswith(prefix) else None
        if rest and '/' not in rest and re.match(r'readme(\.(md|txt|markdown|rst))?$', rest, re.I):
            return p
    return None


def summarize_readme(md, name):
    md = re.sub(r'```[\s\S]*?```', ' ', md.replace('\r\n', '\n'))
    md = re.sub(r'<[^>]+>', ' ', md)
    for para in re.split(r'\n\s*\n', md):
        s = para.strip()
        if not s or s.startswith(('#', '|', '!', '[!', '>', '---', '===')):
            continue
        s = re.sub(r'!\[[^\]]*\]\([^)]*\)', ' ', s)
        s = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', s)
        s = re.sub(r'[`*_]+', '', s)
        s = re.sub(r'\s+', ' ', s).strip()
        if len(s) < 30 or re.match(r'^(install|usage|commands?|copy|//|load|requires?|create|place|download|extract|unzip|put|author|version)\b', s, re.I):
            continue
        if s.lower().replace(' ', '') == norm(name):
            continue
        return s[:240].rsplit(' ', 1)[0] + '…' if len(s) > 240 else s
    return ''


def get_meta(gh, repo, summary):
    if summary:
        return summary
    cached = cache_get('meta', repo, max_age_hours=24 * 7)
    if cached:
        return cached['meta']
    r = gh.get(f'repos/{repo}')
    meta = _repo_summary(r) if r else None
    cache_put('meta', repo, {'meta': meta})
    return meta


def scan_repo(gh, repo, summary, code_paths, max_age_days):
    """Return cached-or-fresh scan record for one repo."""
    cached = cache_get('scan', repo)
    if cached and summary and cached.get('pushed_at') == summary.get('pushed_at'):
        return cached
    if cached and not summary and time.time() - cached['_cached_at'] < max_age_days * 86400:
        return cached

    meta = get_meta(gh, repo, summary)
    rn = repo.split('/')[1].lower()
    if meta and 'ashita' in rn and 'windower' not in rn:
        rec = {'repo': repo, 'pushed_at': meta.get('pushed_at'), 'meta': meta,
               'entries': [], 'ashita': 0, 'skipped': 'ashita-repo'}
        cache_put('scan', repo, rec)
        return rec
    if not meta or meta.get('fork'):
        rec = {'repo': repo, 'pushed_at': meta and meta.get('pushed_at'), 'meta': meta,
               'entries': [], 'ashita': 0, 'skipped': 'fork' if meta else 'missing'}
        cache_put('scan', repo, rec)
        return rec

    ref = meta.get('default_branch') or 'HEAD'
    tree = gh.get(f'repos/{repo}/git/trees/{urllib.parse.quote(ref)}', {'recursive': 1})
    paths = [t['path'] for t in (tree or {}).get('tree', []) if t.get('type') == 'blob']
    cands = entry_points(paths, repo)
    cands += [p for p in code_paths if p not in cands and p in entry_points([p], repo)]

    entries, ashita = [], 0
    single = len(cands) == 1
    for path in cands:
        src = fetch_raw(repo, ref, path)
        if not src:
            continue
        eco = ecosystem(src)
        if eco == 'ashita':
            ashita += 1
            continue
        if eco != 'windower':
            continue
        hdr = parse_header(src)
        directory = path.rsplit('/', 1)[0] if '/' in path else ''
        # _addon.name may be a variable; fall back to the folder Windower would load it from
        name = hdr.get('name') or (directory.rsplit('/', 1)[-1] if directory else repo.split('/')[1])
        desc, desc_src = hdr.get('desc', ''), f'https://github.com/{repo}/blob/HEAD/{path}'
        rd = readme_for(paths, directory) or (readme_for(paths, '') if single else None)
        if not desc and rd:
            md = fetch_raw(repo, ref, rd) or ''
            desc = summarize_readme(md, name)
            if desc:
                desc_src = f'https://github.com/{repo}/blob/HEAD/{rd}'
        if not desc and single and meta.get('description'):
            desc, desc_src = meta['description'], f'https://github.com/{repo}'
        entries.append({
            'name': name, 'key': norm(name), 'path': path, 'dir': directory,
            'author': hdr.get('author', ''), 'version': hdr.get('version', ''),
            'commands': hdr.get('commands', []), 'description': desc.strip(),
            'description_source': desc_src,
        })
    rec = {'repo': repo, 'pushed_at': meta.get('pushed_at'), 'meta': meta, 'entries': entries,
           'ashita': ashita, 'truncated': bool((tree or {}).get('truncated')),
           'skipped': None if tree else 'no-tree'}
    cache_put('scan', repo, rec)
    return rec


def scan_all(gh, repos, hits, workers, max_age_days, limit=None):
    names = sorted(repos)
    if limit:
        names = names[:limit]
    log(f'scanning {len(names)} repos with {workers} workers')
    results, done = [], 0
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(scan_repo, gh, r, repos[r], hits.get(r, set()), max_age_days): r for r in names}
        for f in as_completed(futs):
            done += 1
            try:
                results.append(f.result())
            except Exception as e:  # keep going; the repo is retried next run
                log(f'  ! {futs[f]}: {e}')
            if done % 100 == 0:
                log(f'  {done}/{len(names)} scanned (core calls so far: {gh.calls["core"]})')
    return results


# --------------------------------------------------------------------------- report


def load_catalog():
    return json.loads(CATALOG.read_text())


def load_ignore():
    keys, repos = set(GENERIC_KEYS), set()
    if IGNORE_FILE.exists():
        for ln in IGNORE_FILE.read_text().splitlines():
            ln = ln.split('#', 1)[0].strip()
            if not ln:
                continue
            (repos if '/' in ln else keys).add(ln if '/' in ln else norm(ln))
    return keys, repos


def all_scans():
    d = CACHE / 'scan'
    return [json.loads(p.read_text()) for p in d.glob('*.json')] if d.exists() else []


def build_candidates(scans):
    catalog = load_catalog()
    by_key = {a['addon_key']: a for a in catalog}
    ign_keys, ign_repos = load_ignore()
    groups = {}
    for s in scans:
        if s['repo'] in ign_repos or not s.get('meta'):
            continue
        for e in s['entries']:
            if not e['key'] or e['key'] in ign_keys:
                continue
            if any(seg.lower() in SKIP_SEGMENTS for seg in e['path'].split('/')[:-1]):
                continue
            if '\ufffd' in e['description']:
                e = dict(e, description='')
            groups.setdefault(e['key'], []).append((s['meta'], e))

    def rank(item):
        meta, _ = item
        return (meta['repo'] != OFFICIAL_REPO, -(meta.get('stars') or 0), meta.get('created_at') or '')

    out = []
    for key, items in groups.items():
        items.sort(key=rank)
        known = by_key.get(key)
        known_repos = set(known['repos']) if known else set()
        new_repos = sorted({m['repo'] for m, _ in items} - known_repos)
        if known and not new_repos:
            continue
        best_meta, best = items[0]
        out.append({
            'key': key,
            'name': best['name'],
            'status': 'new_source' if known else 'new',
            'official': any(m['repo'] == OFFICIAL_REPO for m, _ in items),
            'repo': best_meta['repo'],
            'url': f'https://github.com/{best_meta["repo"]}/tree/HEAD/{best["dir"]}'.rstrip('/'),
            'path': best['path'],
            'author': best['author'],
            'version': best['version'],
            'commands': best['commands'],
            'description': next((e['description'] for _, e in items if e['description']), ''),
            'description_source': next((e['description_source'] for _, e in items if e['description']),
                                       best['description_source']),
            'stars': max(m.get('stars') or 0 for m, _ in items),
            'created_at': min((m.get('created_at') or '') for m, _ in items),
            'pushed_at': max((m.get('pushed_at') or '') for m, _ in items),
            'repos': sorted({m['repo'] for m, _ in items}),
            'new_repos': new_repos,
            'repo_dirs': {m['repo']: e['dir'] for m, e in items},
        })
    out.sort(key=lambda c: (c['status'] != 'new', c['key']))
    return out


def md_escape(s):
    return (s or '').replace('|', '\\|').replace('\n', ' ')


def write_report(cands, scans, stats=None):
    OUT_DIR.mkdir(exist_ok=True)
    (OUT_DIR / 'candidates.json').write_text(json.dumps(cands, indent=2, ensure_ascii=False) + '\n')
    new = [c for c in cands if c['status'] == 'new']
    official = [c for c in new if c['official']]
    community = sorted((c for c in new if not c['official']),
                       key=lambda c: c['created_at'] or '', reverse=True)
    sources = [c for c in cands if c['status'] == 'new_source']
    since = '2026-04-22'
    recent = [c for c in community if (c['created_at'] or '') >= since]

    L = [f'# Windower addon discovery — {today().isoformat()}', '',
         'Generated by `scripts/discover.py`. Windower only; Ashita addons are skipped.', '',
         '## Summary', '',
         f'- Repos scanned: {len(scans)}',
         f'- Repos with at least one Windower addon: {sum(1 for s in scans if s["entries"])}',
         f'- Windower addon entry points verified: {sum(len(s["entries"]) for s in scans)}',
         f'- Ashita entry points skipped: {sum(s.get("ashita", 0) for s in scans)}',
         f'- **New addons not in the catalog: {len(new)}** '
         f'({len(official)} official `Windower/Lua`, {len(community)} community; '
         f'{len(recent)} in repos created since {since})',
         f'- Known addons found in additional repos: {len(sources)}']
    if stats:
        L.append(f'- API calls this run: {stats}')
    L += ['', 'Review the lists below, add anything that is not a real addon to `discovery/ignore.txt` '
          '(one addon name or `owner/repo` per line), then apply with '
          '`python3 scripts/discover.py apply --status new`.', '']

    def table(rows):
        out = ['| Addon | Repo | Created | Pushed | ★ | Description |', '|---|---|---|---|---|---|']
        for c in rows:
            extra = f' (+{len(c["repos"]) - 1})' if len(c['repos']) > 1 else ''
            out.append(f'| [{md_escape(c["name"])}]({c["url"]}) | {c["repo"]}{extra} | '
                       f'{(c["created_at"] or "")[:10]} | {(c["pushed_at"] or "")[:10]} | {c["stars"]} | '
                       f'{md_escape(c["description"])[:160]} |')
        return out

    L += ['## New community addons (newest repos first)', ''] + table(community) + ['']
    if official:
        L += ['## New official addons (`Windower/Lua`)', '',
              ', '.join(f'[{c["name"]}]({c["url"]})' for c in sorted(official, key=lambda c: c['key'])), '']
    if sources:
        L += ['## Known addons with new source repos', '']
        for c in sorted(sources, key=lambda c: -len(c['new_repos'])):
            shown = ', '.join(c['new_repos'][:6]) + (f' … +{len(c["new_repos"]) - 6}' if len(c['new_repos']) > 6 else '')
            L.append(f'- `{c["key"]}`: {shown}')
        L.append('')
    path = OUT_DIR / f'report-{today().isoformat()}.md'
    path.write_text('\n'.join(L))
    log(f'wrote {path.relative_to(ROOT)} and discovery/candidates.json '
        f'({len(new)} new, {len(sources)} new-source)')
    return path


# --------------------------------------------------------------------------- apply


def infer_category(text):
    t = (text or '').lower()
    for cat, pat in CATEGORY_RULES:
        if re.search(pat, t):
            return cat
    return 'general_qol'


def write_catalog(catalog):
    catalog.sort(key=lambda a: a['addon_key'])
    CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False))
    cols = next(csv.reader(CSV_OUT.open(newline='')))
    with CSV_OUT.open('w', newline='') as f:
        w = csv.writer(f)
        w.writerow(cols)
        for a in catalog:
            w.writerow([str(a.get(k, '')) if k == 'repos' else a.get(k, '') for k in cols])


def cmd_apply(args):
    cands = json.loads((OUT_DIR / 'candidates.json').read_text())
    ign_keys, ign_repos = load_ignore()
    keys = {norm(k) for k in args.keys.split(',')} if args.keys else None
    exclude = {norm(k) for k in (args.exclude or '').split(',') if k}
    chosen = [c for c in cands
              if (keys is None or c['key'] in keys)
              and c['key'] not in exclude and c['key'] not in ign_keys
              and (args.status == 'all' or c['status'] == args.status)
              and (args.official or not c['official'])]
    if not chosen:
        log('nothing to apply')
        return
    catalog = load_catalog()
    by_key = {a['addon_key']: a for a in catalog}
    raw = json.loads(RAW.read_text())
    raw_by_repo = {r['repo']: r for r in raw}
    metas = {s['repo']: s['meta'] for s in all_scans() if s.get('meta')}
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    added = extended = 0

    for c in chosen:
        repos = [r for r in c['repos'] if r not in ign_repos]
        if not repos:
            continue
        if c['key'] in by_key:
            a = by_key[c['key']]
            a['repos'] = sorted(set(a['repos']) | set(repos), key=str.lower)
            extended += 1
        else:
            a = {
                'addon_key': c['key'], 'addon_name': c['name'],
                'category': infer_category(f'{c["name"]} {c["description"]}'),
                'repos': sorted(repos, key=str.lower),
                'description': c['description'],
                'description_source': c['description_source'] if c['description'] else 'discover.py (no description found)',
                'description_confidence': 'low',
                'description_reviewed_at': now,
                'opportunity_score': 4.0,
            }
            catalog.append(a)
            by_key[c['key']] = a
            added += 1
        a['repo_count'] = len(a['repos'])
        a['best_repo_stars'] = max([a.get('best_repo_stars') or 0] +
                                   [(metas.get(r) or {}).get('stars') or 0 for r in repos])
        a['freshness_max'] = max([a.get('freshness_max') or ''] +
                                 [(metas.get(r) or {}).get('pushed_at') or '' for r in repos])
        for r in repos:
            m = metas.get(r) or {}
            entry = raw_by_repo.get(r)
            if not entry:
                entry = {'repo': r, 'stars': m.get('stars', 0), 'pushed_at': m.get('pushed_at'),
                         'description': m.get('description', ''), 'addon_dirs': []}
                raw.append(entry)
                raw_by_repo[r] = entry
            d = c['repo_dirs'].get(r)
            if d and d not in entry['addon_dirs']:
                entry['addon_dirs'].append(d)

    raw.sort(key=lambda r: r['repo'].lower())
    if args.dry_run:
        log(f'dry run: would add {added} addons and extend {extended} existing entries')
        return
    write_catalog(catalog)
    RAW.write_text(json.dumps(raw, indent=2) + '\n')
    log(f'added {added} addons, extended {extended} existing entries; catalog now {len(catalog)} entries')


# --------------------------------------------------------------------------- commands


def cmd_run(args):
    gh = GH()
    repo_q = REPO_QUERIES if not args.code_only else []
    code_q = CODE_QUERIES if not args.repos_only else []
    if args.since:
        repo_q = [f'{q} pushed:>={args.since}' for q in repo_q]
    log('searching GitHub…')
    repos, hits = collect(gh, repo_q, code_q, args.refresh)
    if args.include_known:
        for a in load_catalog():
            for r in a['repos']:
                repos.setdefault(r, None)
    repos.setdefault(OFFICIAL_REPO, None)
    log(f'{len(repos)} candidate repos ({len(hits)} from code search)')
    scan_all(gh, repos, hits, args.workers, args.max_age_days, args.limit)
    scans = all_scans()
    write_report(build_candidates(scans), scans, stats=dict(gh.calls))


def cmd_report(args):
    scans = all_scans()
    write_report(build_candidates(scans), scans)


def cmd_resolve(args):
    gh = GH()
    repos, hits = {}, {}
    for name in args.names:
        for h in search_code(gh, f'"_addon.name" "{name}" language:lua'):
            # code search matches the name anywhere in the file; keep hits whose path names it
            if norm(name) not in norm(h['path']):
                continue
            hits.setdefault(h['repo'], set()).add(h['path'])
            repos.setdefault(h['repo'], None)
        for r in search_repos(gh, f'"{name}" in:name language:lua'):
            # repo-name search is fuzzy; keep only repos whose name contains the addon name
            rn, k = norm(r['repo'].split('/')[1]), norm(name)
            if not r['fork'] and (rn == k if len(k) <= 4 else k in rn):  # short names: exact only
                repos[r['repo']] = r
    scans = scan_all(gh, repos, hits, args.workers, args.max_age_days)
    catalog_keys = {a['addon_key'] for a in load_catalog()}
    for name in args.names:
        k = norm(name)
        found = [(s['repo'], e) for s in scans for e in s['entries'] if k in e['key']]
        status = 'IN CATALOG' if k in catalog_keys else ('FOUND' if found else 'not found')
        print(f'{name}: {status}')
        for repo, e in found:
            flag = '' if e['key'] in catalog_keys else '  [new]'
            print(f'    {e["name"]:<24} {repo}/{e["path"]}{flag}')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)

    r = sub.add_parser('run', help='search GitHub, scan repos, write report')
    r.add_argument('--since', help='only repo-search repos pushed on/after YYYY-MM-DD (code search is unaffected)')
    r.add_argument('--refresh', action='store_true', help='ignore cached search results (<24h)')
    r.add_argument('--include-known', action='store_true', help='also rescan every repo already in the catalog')
    r.add_argument('--repos-only', action='store_true', help='skip code search')
    r.add_argument('--code-only', action='store_true', help='skip repo search')
    r.add_argument('--limit', type=int, help='scan at most N repos (testing)')
    r.add_argument('--workers', type=int, default=6)
    r.add_argument('--max-age-days', type=float, default=7, help='rescan code-search-only repos after this long')
    r.set_defaults(fn=cmd_run)

    p = sub.add_parser('report', help='rebuild report from cache (no network)')
    p.set_defaults(fn=cmd_report)

    s = sub.add_parser('resolve', help='look up specific addon names')
    s.add_argument('names', nargs='+')
    s.add_argument('--workers', type=int, default=6)
    s.add_argument('--max-age-days', type=float, default=7)
    s.set_defaults(fn=cmd_resolve)

    a = sub.add_parser('apply', help='merge reviewed candidates into the catalog')
    a.add_argument('--status', choices=['new', 'new_source', 'all'], default='new')
    a.add_argument('--keys', help='comma-separated addon keys to apply (default: all matching --status)')
    a.add_argument('--exclude', help='comma-separated addon keys to skip')
    a.add_argument('--official', action='store_true', help='include official Windower/Lua addons')
    a.add_argument('--dry-run', action='store_true')
    a.set_defaults(fn=cmd_apply)

    args = ap.parse_args()
    args.fn(args)


if __name__ == '__main__':
    main()
