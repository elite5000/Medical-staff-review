#!/usr/bin/env bash
# PostToolUse (Write|Edit): auto-fix the touched file with ruff (Python) or dart format
# (Dart). Never blocks.
set -u
export PATH="$HOME/flutter/bin:$PATH"
dir=$(dirname "$0")
f=$(node "$dir/extract-path.mjs")

[ -z "$f" ] && exit 0
case "$f" in
  *node_modules*|*dist*|*build*|*.dart_tool*) exit 0 ;;
esac
[ -f "$f" ] || exit 0

case "$f" in
  *.py)
    uv run --project backend ruff format "$f" >/dev/null 2>&1
    uv run --project backend ruff check --fix "$f" >/dev/null 2>&1
    ;;
  *.dart)
    dart format "$f" >/dev/null 2>&1
    ;;
esac
exit 0
