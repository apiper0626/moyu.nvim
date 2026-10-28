#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
export PYTHONDONTWRITEBYTECODE=1
run() { nvim --headless -u NONE -i NONE -n -l "tests/$1.lua"; }
for test in smoke restore stealth stealth_restore; do run "$test"; done
export XDG_DATA_HOME="$test_root/history"
run history
run history_restore
for test in mode formats; do
  export XDG_DATA_HOME="$test_root/$test"
  run "$test"
done
python3 tests/test_formats.py
if command -v fzf >/dev/null 2>&1; then
  export XDG_DATA_HOME="$test_root/picker"
  run picker
fi
if [ "${1:-}" = '--integrations' ]; then
  export XDG_DATA_HOME="$test_root/lazy"
  run lazy
  export XDG_DATA_HOME="$test_root/lualine"
  run mode_lualine
fi
