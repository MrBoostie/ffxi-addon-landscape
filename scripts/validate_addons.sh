#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[validate] checking Lua syntax"
LUA_CHECK_MODE=""
if command -v luac >/dev/null 2>&1; then
  LUA_CHECK_MODE="luac"
elif command -v lua >/dev/null 2>&1; then
  LUA_CHECK_MODE="lua"
else
  echo "[validate] warning: neither luac nor lua found; skipping Lua syntax checks"
fi

if [[ -n "$LUA_CHECK_MODE" ]]; then
  while IFS= read -r -d '' file; do
    if [[ "$LUA_CHECK_MODE" == "luac" ]]; then
      luac -p "$file"
    else
      lua -e "assert(loadfile(arg[1]))" "$file"
    fi
    echo "  ok: $file"
  done < <(find addons -type f -name '*.lua' -print0)
fi

echo "[validate] checking generated JSON artifacts"
python3 -m json.tool ffxi_addons_index_raw.json >/dev/null
python3 -m json.tool ffxi-addon-catalog-normalized.json >/dev/null
echo "  ok: JSON parse checks"

echo "[validate] all checks passed"