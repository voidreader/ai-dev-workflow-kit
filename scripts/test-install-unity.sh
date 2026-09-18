#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install-unity.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# set -e 아래에서는 `[[ 조건 ]] && fail ...` 를 쓰지 않는다 — 조건이 거짓이면
# AND 리스트가 1을 돌려주고 스크립트가 조용히 죽는다. 부정 검사는 if 로 쓴다.

make_unity_project() {
  local path="$1"
  mkdir -p "$path/ProjectSettings" "$path/Assets"
  printf 'm_EditorVersion: 6000.3.18f1\n' > "$path/ProjectSettings/ProjectVersion.txt"
}

# --- both 레이아웃 ---
both="$TEST_ROOT/both"
make_unity_project "$both"
bash "$INSTALLER" --both "$both" > "$TEST_ROOT/both.log"

[[ -f "$both/.claude/skills/plan-writer/SKILL.md" ]] || fail "common 스킬이 복사되지 않았습니다."
[[ -f "$both/.claude/skills/implement-spec/SKILL.md" ]] || fail "unity 스킬이 복사되지 않았습니다."
[[ -f "$both/.claude/skills/_shared/unity-mcp-bridge.md" ]] || fail "_shared 브리지가 복사되지 않았습니다."
[[ -L "$both/.agents/skills" ]] || fail ".agents/skills 가 심링크가 아닙니다."
[[ -f "$both/.agents/skills/plan-writer/SKILL.md" ]] || fail "심링크 너머로 스킬이 읽히지 않습니다."
if [[ -e "$both/.claude/skills/google-sheets-safe-edit" ]]; then fail "google-sheets-safe-edit 가 제외되지 않았습니다."; fi
if [[ -e "$both/.claude/skills/implement-agent/adapters" ]]; then fail "common implement-agent 의 adapters 잔재가 남았습니다."; fi
[[ -f "$both/.claude/skills/implement-agent/SKILL.md" ]] || fail "unity implement-agent 가 없습니다."
grep -q 'planner → coder → verifier' "$both/.claude/skills/implement-agent/SKILL.md" \
  || fail "implement-agent 가 unity 버전이 아닙니다."
[[ -f "$both/.claude/agents/planner.md" ]] || fail "Claude 에이전트가 없습니다."
[[ -f "$both/.claude/agents/unity-perf-reviewer.md" ]] || fail "unity 전용 에이전트가 없습니다."
[[ -f "$both/.codex/agents/planner.toml" ]] || fail "Codex 에이전트가 없습니다."
[[ -f "$both/.claude/hooks/unity-pattern-guard/check_patterns.py" ]] || fail "Claude 훅이 없습니다."
[[ -f "$both/.codex/hooks/unity-pattern-guard/check_patterns.py" ]] || fail "Codex 훅이 없습니다."

# --- claude 단독 레이아웃: 심링크를 만들지 않는다 ---
claude_only="$TEST_ROOT/claude"
make_unity_project "$claude_only"
bash "$INSTALLER" "$claude_only" > "$TEST_ROOT/claude.log"
[[ -f "$claude_only/.claude/skills/plan-writer/SKILL.md" ]] || fail "claude 레이아웃 스킬 누락."
if [[ -e "$claude_only/.agents" ]]; then fail "claude 단독 설치가 .agents 를 만들었습니다."; fi
if [[ -e "$claude_only/.codex" ]]; then fail "claude 단독 설치가 .codex 를 만들었습니다."; fi

# --- codex 단독 레이아웃: spec-pipeline 경로 보정 ---
codex_only="$TEST_ROOT/codex"
make_unity_project "$codex_only"
bash "$INSTALLER" --codex "$codex_only" > "$TEST_ROOT/codex.log"
[[ -f "$codex_only/.agents/skills/plan-writer/SKILL.md" ]] || fail "codex 레이아웃 스킬 누락."
if [[ -L "$codex_only/.agents/skills" ]]; then fail "codex 단독 설치에서 .agents/skills 는 실체여야 합니다."; fi
grep -q '\.agents/skills' "$codex_only/.agents/skills/spec-pipeline/SKILL.md" \
  || fail "codex 경로 보정이 적용되지 않았습니다."

# --- dry-run: 아무것도 만들지 않는다 ---
dry="$TEST_ROOT/dry"
make_unity_project "$dry"
bash "$INSTALLER" --both --dry-run "$dry" > "$TEST_ROOT/dry.log"
if [[ -e "$dry/.claude" ]]; then fail "dry-run 이 .claude 를 생성했습니다."; fi
grep -q 'dry-run' "$TEST_ROOT/dry.log" || fail "dry-run 출력에 표시가 없습니다."

# --- Unity 프로젝트가 아니면 경고 ---
notunity="$TEST_ROOT/notunity"
mkdir -p "$notunity"
bash "$INSTALLER" --both "$notunity" > "$TEST_ROOT/notunity.log"
grep -q 'ProjectVersion.txt' "$TEST_ROOT/notunity.log" || fail "Unity 프로젝트 점검 경고가 없습니다."

echo "PASS: Unity 설치 스크립트 동작"
