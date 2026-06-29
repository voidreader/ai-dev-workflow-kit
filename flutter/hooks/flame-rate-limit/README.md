# flame-rate-limit 훅

flame-harness **Phase A 파이프라인**이 rate limit(429)에 걸렸을 때, 작업을
`state.md`에서 **paused(`pause_reason: rate_limit`)로 자동 표시**하는 `Stop` 훅이다.
긴 generator↔evaluator 루프가 rate limit으로 끊겨도 상태가 보존되므로, 한도가 풀린 뒤
[`flame-harness-resume`](../../skills/flame-harness-resume/SKILL.md) 스킬로 이어서 진행할 수 있다.

Phase A(상태머신 유지) 전용이다. 독립 실행하는 `ship-*` 스킬은 상태머신을 쓰지 않으므로 이 훅과
무관하다.

## 동작

세션이 멈출(`Stop`) 때 stdin 페이로드를 읽어 `rate limit` / `429` 문자열이 있으면:

1. `docs/harness/state.md`의 `status`를 `paused`, `pause_reason`을 `rate_limit`으로 설정.
2. `docs/harness/pipeline-log.md`에 PAUSE 행을 추가.
3. (macOS) 알림을 띄운다.

`docs/harness/state.md`가 없으면(= harness 프로젝트가 아니면) **아무것도 하지 않고 조용히 종료**한다.

## 설치

대상 프로젝트에서 플랫폼에 맞게 설정을 합치고 스크립트를 복사한다.

### Claude Code

1. `flame-rate-limit.sh`를 프로젝트 `.claude/hooks/flame-rate-limit.sh`로 복사.
2. `install.claude.json`의 `hooks` 블록을 프로젝트 `.claude/settings.json`에 병합.

### Codex

1. `flame-rate-limit.sh`를 프로젝트 `.codex/hooks/flame-rate-limit.sh`로 복사.
2. `install.codex.json`의 `hooks` 블록을 Codex 설정에 병합.

> `scripts/install-flutter.sh`가 위 복사·병합 안내를 자동으로 처리한다.

## 검증

`scripts/test-hook.sh`(kit 루트)로 동작을 확인한다 — state.md가 없으면 조용히 exit 0,
rate limit 페이로드가 오면 paused로 표시되는지 점검한다.
