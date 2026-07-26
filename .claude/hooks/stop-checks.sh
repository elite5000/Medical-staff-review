#!/usr/bin/env bash
# Stop: full quality gate — eslint, prettier --check, tsc --noEmit, ruff, mypy, pytest,
# svelte-check, vitest, playwright test.
# On failure, blocks with the failure output so Claude can fix it before truly stopping.
set -u
fail=0
report=""

check() {
  name="$1"; shift
  out=$("$@" 2>&1)
  status=$?
  if [ $status -ne 0 ]; then
    fail=1
    report="${report}
=== ${name} FAILED ===
${out}
"
  fi
}

check "ESLint" npx --no-install eslint .
check "Prettier" npx --no-install prettier --check .
check "TypeScript" node ./node_modules/typescript7/bin/tsc --noEmit
check "Ruff Format" bash -c "cd backend && uv run ruff format --check ."
check "Ruff Lint" bash -c "cd backend && uv run ruff check ."
check "Mypy" bash -c "cd backend && uv run mypy ."
check "Pytest" bash -c "cd backend && uv run pytest"
check "Svelte Check" npx --no-install --workspace=frontend svelte-check --tsconfig ./tsconfig.json
check "Vitest" npx --no-install --workspace=frontend vitest run
check "Playwright" npx --no-install playwright test

if [ "$fail" -eq 1 ]; then
  REPORT="$report" node -e '
    const reason = (process.env.REPORT || "").slice(-6000);
    process.stdout.write(JSON.stringify({
      decision: "block",
      reason: "Quality checks failed before stopping:\n" + reason,
      stopReason: "Automated lint/typecheck/test gate failed.",
    }));
  '
fi
exit 0
