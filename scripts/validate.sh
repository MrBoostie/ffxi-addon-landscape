#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXIT_CODE=0
PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); EXIT_CODE=1; echo "  FAIL: $1"; }
warn() { WARN=$((WARN+1)); echo "  WARN: $1"; }

echo "=== FFXI Addon Landscape Validation ==="
echo ""

# 1. Lua syntax check
echo "[1/5] Lua syntax check"
LUA_CMD=""
if command -v luac >/dev/null 2>&1; then
    LUA_CMD="luac"
elif command -v luac5.1 >/dev/null 2>&1; then
    LUA_CMD="luac5.1"
fi

if [ -n "$LUA_CMD" ]; then
    while IFS= read -r -d '' f; do
        if $LUA_CMD -p "$f" 2>/dev/null; then
            pass "$(basename "$f") syntax OK"
        else
            fail "$(basename "$f") syntax error"
        fi
    done < <(find "$REPO_ROOT/addons" "$REPO_ROOT/libs" -name '*.lua' -print0 2>/dev/null)
else
    warn "luac not found, skipping Lua syntax checks"
fi

# 2. JSON catalog validation
echo ""
echo "[2/5] JSON catalog validation"
CATALOG="$REPO_ROOT/ffxi-addon-catalog-normalized.json"
if [ -f "$CATALOG" ]; then
    if python3 -c "
import json, sys
with open('$CATALOG') as f:
    data = json.load(f)
if not isinstance(data, list):
    print('catalog is not a list', file=sys.stderr); sys.exit(1)
missing = []
for i, entry in enumerate(data):
    for field in ['addon_name', 'addon_key', 'category']:
        if field not in entry:
            missing.append(f'entry {i} missing {field}')
if missing:
    for m in missing[:10]:
        print(m, file=sys.stderr)
    sys.exit(1)
print(f'{len(data)} entries validated')
" 2>&1; then
        pass "catalog JSON valid"
    else
        fail "catalog JSON validation failed"
    fi
else
    warn "catalog file not found"
fi

# 3. Rule validation
echo ""
echo "[3/5] Rule file validation"
RULES_FILE="$REPO_ROOT/addons/SessionConductor/data/rules.default.lua"
if [ -f "$RULES_FILE" ]; then
    if python3 -c "
import re, sys

with open('$RULES_FILE') as f:
    content = f.read()

ids = re.findall(r\"id\s*=\s*['\\\"]([^'\\\"]+)\", content)
if not ids:
    print('no rule IDs found', file=sys.stderr); sys.exit(1)
seen = set()
for rid in ids:
    if rid in seen:
        print(f'duplicate rule id: {rid}', file=sys.stderr); sys.exit(1)
    seen.add(rid)

required_fields = ['enabled', 'priority', 'when', 'then_actions']
for field in required_fields:
    if field not in content:
        print(f'missing field pattern: {field}', file=sys.stderr); sys.exit(1)

print(f'{len(ids)} rules with unique IDs')
" 2>&1; then
        pass "rules.default.lua valid"
    else
        fail "rules.default.lua validation failed"
    fi
else
    fail "rules.default.lua not found"
fi

# 4. Route validation
echo ""
echo "[4/5] Route file validation"
ROUTES_FILE="$REPO_ROOT/addons/TravelRouter/data/routes.lua"
if [ -f "$ROUTES_FILE" ]; then
    if python3 -c "
import re, sys

with open('$ROUTES_FILE') as f:
    content = f.read()

dests = re.findall(r'^\s*(\w+)\s*=\s*\{', content, re.MULTILINE)
if not dests:
    print('no destinations found', file=sys.stderr); sys.exit(1)

steps_count = len(re.findall(r\"(say|cmd|wait):\", content))
if steps_count == 0:
    print('no step patterns found', file=sys.stderr); sys.exit(1)

print(f'{len(dests)} destinations, {steps_count} steps')
" 2>&1; then
        pass "routes.lua valid"
    else
        fail "routes.lua validation failed"
    fi
else
    fail "routes.lua not found"
fi

# 5. Unit tests
echo ""
echo "[5/5] Unit tests"
if command -v lua >/dev/null 2>&1 || command -v lua5.1 >/dev/null 2>&1; then
    LUA_RUN=""
    if command -v lua5.1 >/dev/null 2>&1; then
        LUA_RUN="lua5.1"
    elif command -v lua >/dev/null 2>&1; then
        LUA_RUN="lua"
    fi

    if [ -n "$LUA_RUN" ]; then
        cd "$REPO_ROOT/tests"
        if $LUA_RUN test_common.lua 2>&1; then
            pass "test_common.lua"
        else
            fail "test_common.lua"
        fi
        cd "$REPO_ROOT"
    fi
else
    warn "lua not found, skipping unit tests"
fi

# Summary
echo ""
echo "=== Summary ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"
echo ""

exit $EXIT_CODE
