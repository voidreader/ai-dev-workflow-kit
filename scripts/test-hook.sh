#!/usr/bin/env bash
# flame-rate-limit Stop 훅의 동작을 검증한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/flutter/hooks/flame-rate-limit/flame-rate-limit.sh"
tmp="$(mktemp -d)"; cd "$tmp"
# state.md 없음 → 훅은 조용히 exit 0
out=$(echo '{"reason":"429 rate limit"}' | bash "$HOOK"); rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: no-state should exit 0 (got $rc)"; exit 1; }
[ -z "$out" ] || { echo "FAIL: no-state should be silent (got: $out)"; exit 1; }
echo "PASS: no-state silent exit 0"
# state.md + rate limit → paused로 표시되어야 함
mkdir -p docs/harness; printf 'status: running\npause_reason: ""\n' > docs/harness/state.md
echo '{"reason":"429 rate limit reached"}' | bash "$HOOK" || true
grep -q 'status: paused' docs/harness/state.md && echo "PASS: paused set" || { echo "FAIL: not paused"; exit 1; }
grep -q 'pause_reason: rate_limit' docs/harness/state.md && echo "PASS: reason set" || { echo "FAIL: reason"; exit 1; }
