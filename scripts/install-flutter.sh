#!/usr/bin/env bash
#
# install-flutter.sh — ai-dev-workflow-kit의 flutter 스킬·에이전트·훅을 대상 프로젝트에 설치한다.
#
# 사용법:
#   scripts/install-flutter.sh [옵션] <대상-프로젝트-경로>
#
# 옵션:
#   --codex      Codex 레이아웃으로 설치 (.agents/skills, .codex/agents, .codex/hooks). 기본은 Claude.
#   --dry-run    실제로 복사하지 않고 수행할 작업만 출력한다.
#   -h, --help   도움말 출력.
#
# 동작:
#   1. common/skills + flutter/skills → 대상 skills 디렉토리
#      (flame-harness/ 의 protocol.md·game-gotchas.md, generator/ship-* 의 templates/ 동봉 포함)
#   2. common/agents + flutter/agents (Claude=.md / Codex=.toml) → 대상 agents 디렉토리
#   3. implement-agent 어댑터를 flutter.md 만 남기고 정리 (backend/unity 제거)
#   4. Codex 설치 시 spec-pipeline의 .claude/skills 경로를 .agents/skills 로 보정
#   5. flame-rate-limit 훅 스크립트 복사 + settings 병합 안내 출력 (Phase A 전용)
#   6. 전제조건(pubspec.yaml, CLAUDE.md) 점검 후 경고 출력
#
set -euo pipefail

# --- 경로 결정 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"

# --- 옵션 파싱 ---
PLATFORM="claude"
DRY_RUN=0
TARGET=""

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex)   PLATFORM="codex"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    -*)        echo "알 수 없는 옵션: $1" >&2; usage 1 ;;
    *)
      if [[ -n "$TARGET" ]]; then echo "대상 경로는 하나만 지정합니다: '$TARGET', '$1'" >&2; exit 1; fi
      TARGET="$1"; shift ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "오류: 대상 프로젝트 경로가 필요합니다." >&2
  usage 1
fi
if [[ ! -d "$TARGET" ]]; then
  echo "오류: 대상 경로가 디렉토리가 아닙니다: $TARGET" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

# --- 플랫폼별 레이아웃 ---
if [[ "$PLATFORM" == "codex" ]]; then
  SKILLS_DIR="$TARGET/.agents/skills"
  AGENTS_DIR="$TARGET/.codex/agents"
  HOOKS_DIR="$TARGET/.codex/hooks"
  AGENT_EXT="toml"
else
  SKILLS_DIR="$TARGET/.claude/skills"
  AGENTS_DIR="$TARGET/.claude/agents"
  HOOKS_DIR="$TARGET/.claude/hooks"
  AGENT_EXT="md"
fi

# --- 실행 헬퍼 (dry-run 지원) ---
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [dry-run] $*"
  else
    eval "$@"
  fi
}

echo "== ai-dev-workflow-kit · flutter 설치 =="
echo "  kit       : $KIT_ROOT"
echo "  대상      : $TARGET"
echo "  플랫폼    : $PLATFORM (skills=$SKILLS_DIR, agents=$AGENTS_DIR)"
[[ "$DRY_RUN" == "1" ]] && echo "  모드      : DRY-RUN (변경 없음)"
echo ""

# --- 1. 디렉토리 생성 ---
run "mkdir -p '$SKILLS_DIR' '$AGENTS_DIR' '$HOOKS_DIR'"

# --- 2. 스킬 복사 (common + flutter) ---
echo "[1/5] 스킬 복사 (동봉 protocol.md·game-gotchas.md·templates/ 포함)"
run "cp -R '$KIT_ROOT/common/skills/.' '$SKILLS_DIR/'"
run "cp -R '$KIT_ROOT/flutter/skills/.' '$SKILLS_DIR/'"

# --- 3. 에이전트 복사 (common + flutter, 플랫폼 확장자) ---
echo "[2/5] 에이전트 복사 (*.$AGENT_EXT)"
run "cp '$KIT_ROOT/common/agents/'*.$AGENT_EXT '$AGENTS_DIR/' 2>/dev/null || true"
run "cp '$KIT_ROOT/flutter/agents/'*.$AGENT_EXT '$AGENTS_DIR/' 2>/dev/null || true"

# --- 4. 어댑터 정리: flutter.md 만 남긴다 ---
echo "[3/5] implement-agent 어댑터 정리 (flutter만 유지)"
ADAPTERS_DIR="$SKILLS_DIR/implement-agent/adapters"
for stack in backend unity; do
  if [[ -f "$ADAPTERS_DIR/$stack.md" ]]; then
    run "rm -f '$ADAPTERS_DIR/$stack.md'"
  fi
done

# --- 5. Codex 경로 보정: spec-pipeline 의 .claude/skills → .agents/skills ---
if [[ "$PLATFORM" == "codex" ]]; then
  echo "[3.5] Codex 경로 보정 (spec-pipeline)"
  PIPELINE="$SKILLS_DIR/spec-pipeline/SKILL.md"
  if [[ -f "$PIPELINE" ]]; then
    run "sed -i.bak 's#\\.claude/skills#.agents/skills#g' '$PIPELINE' && rm -f '$PIPELINE.bak'"
  fi
fi

# --- 6. flame-rate-limit 훅 설치 (Phase A 전용) ---
echo "[4/5] flame-rate-limit 훅 스크립트 복사"
run "cp '$KIT_ROOT/flutter/hooks/flame-rate-limit/flame-rate-limit.sh' '$HOOKS_DIR/flame-rate-limit.sh'"
run "chmod +x '$HOOKS_DIR/flame-rate-limit.sh'"

# --- 7. 전제조건 점검 (경고만, 비차단) ---
echo "[5/5] 전제조건 점검"
WARN=0
if [[ ! -f "$TARGET/pubspec.yaml" ]]; then
  echo "  ⚠ pubspec.yaml 이 없습니다. Flutter 프로젝트가 맞는지 확인하세요."
  echo "    (flame-harness Phase A는 새 프로젝트를 생성하므로, 빈 작업 디렉토리에서 시작해도 됩니다.)"
  WARN=1
fi
if [[ ! -f "$TARGET/CLAUDE.md" && ! -f "$TARGET/AGENTS.md" ]]; then
  echo "  ⚠ CLAUDE.md / AGENTS.md 가 없습니다. spec-writer·coder가 아키텍처 섹션을 참조합니다."
  WARN=1
fi
[[ "$WARN" == "0" ]] && echo "  ✓ 점검 통과"

# --- 완료 안내 ---
echo ""
echo "== 완료 =="
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY-RUN 이었습니다. 실제 설치하려면 --dry-run 없이 다시 실행하세요."
  exit 0
fi
cat <<EOF

설치된 워크플로우:

[프로토타입 — Phase A 파이프라인 (상태머신 자동 진행)]
  /flame-harness "<게임 아이디어>"   → research→plan→design→contract→generator↔evaluator
  /flame-harness-status              → 진행 상태 확인
  /flame-harness-resume              → 일시정지(rate limit 등) 후 재개

[기능 반복 루프 (프로토타입을 키울 때)]
  /plan-writer → /spec-pipeline @기획서 → /implement-spec|implement-agent → /finalize-feature

[출시 (각 스킬 독립 호출)]
  /ship-admob /ship-build /ship-screenshot /ship-submit /ship-retro

수동 추가 단계:
  • flame-rate-limit 훅을 켜려면 flutter/hooks/flame-rate-limit/install.${PLATFORM}.json 의
    hooks 블록을 대상 프로젝트 설정에 병합하세요.

이 스크립트는 파일 복사만 합니다. push·커밋은 하지 않습니다.
EOF
