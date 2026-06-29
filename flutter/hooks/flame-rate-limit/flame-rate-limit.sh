#!/usr/bin/env bash
# flame-harness rate-limit Stop 훅.
# Stop 페이로드(stdin)에서 rate limit/429 신호를 감지하면 Phase A 파이프라인을
# state.md에서 paused(pause_reason: rate_limit)로 표시한다. harness 프로젝트가 아니면
# (state.md 없음) 조용히 종료한다.
set -euo pipefail
STATE="docs/harness/state.md"
[ -f "$STATE" ] || exit 0           # harness 프로젝트가 아님
payload="$(cat 2>/dev/null || true)"
echo "$payload" | grep -qiE 'rate.?limit|429' || exit 0
# paused 표시 (portable sed)
tmp="$(mktemp)"
sed -e 's/^status:.*/status: paused/' \
    -e 's/^pause_reason:.*/pause_reason: rate_limit/' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
grep -q '^status:' "$STATE" || printf 'status: paused\n' >> "$STATE"
grep -q '^pause_reason:' "$STATE" || printf 'pause_reason: rate_limit\n' >> "$STATE"
printf '| %s | PAUSE | - | rate_limit |\n' "$(date '+%H:%M')" >> docs/harness/pipeline-log.md 2>/dev/null || true
command -v osascript >/dev/null && osascript -e 'display notification "flame-harness 일시정지 (rate limit)"' 2>/dev/null || true
exit 0
