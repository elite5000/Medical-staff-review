#!/usr/bin/env bash
# PostToolUse (Write|Edit): auto-fix the touched file with prettier + eslint, or ruff for
# Python files. Never blocks.
set -u
dir=$(dirname "$0")
f=$(node "$dir/extract-path.mjs")

[ -z "$f" ] && exit 0
case "$f" in
  *node_modules*|*dist*|*build*|*playwright-report*|*test-results*) exit 0 ;;
esac
[ -f "$f" ] || exit 0

case "$f" in
  *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.css|*.svelte)
    npx --no-install prettier --write "$f" >/dev/null 2>&1
    ;;
esac
case "$f" in
  *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.cjs|*.svelte)
    npx --no-install eslint --fix "$f" >/dev/null 2>&1
    ;;
esac
case "$f" in
  *.py)
    uv run --project backend ruff format "$f" >/dev/null 2>&1
    uv run --project backend ruff check --fix "$f" >/dev/null 2>&1
    ;;
esac
exit 0
