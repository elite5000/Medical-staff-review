#!/usr/bin/env bash
# Stop: full quality gate — ruff, mypy, pytest (backend), flutter analyze + test (app).
# On failure, blocks with the failure output so Claude can fix it before truly stopping.
set -u
export PATH="$HOME/flutter/bin:$PATH"
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

check "Ruff Format" bash -c "cd backend && uv run ruff format --check ."
check "Ruff Lint" bash -c "cd backend && uv run ruff check ."
check "Mypy" bash -c "cd backend && uv run mypy ."
check "Pytest" bash -c "cd backend && uv run pytest"
check "Flutter Analyze" bash -c "cd app && flutter analyze"
check "Flutter Test" bash -c "cd app && flutter test"

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
