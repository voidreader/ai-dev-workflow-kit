#!/usr/bin/env bash
#
# install-backend.sh — ai-dev-workflow-kit의 backend 스킬·에이전트를 대상 프로젝트에 설치한다.
#
# 사용법:
#   scripts/install-backend.sh [옵션] <대상-프로젝트-경로>
#
# 옵션:
#   --codex      Codex 레이아웃으로 설치 (.agents/skills, .codex/agents). 기본은 Claude(.claude/...).
#   --dry-run    실제로 복사하지 않고 수행할 작업만 출력한다.
#   -h, --help   도움말 출력.
#
# 동작:
#   1. common/skills + backend/skills → 대상 skills 디렉토리
#   2. common/agents + backend/agents (Claude=.md / Codex=.toml) → 대상 agents 디렉토리
#   3. implement-agent 어댑터를 backend.md 만 남기고 정리 (flutter/unity 제거)
#   4. Codex 설치 시 spec-pipeline의 .claude/skills 경로를 .agents/skills 로 보정
#   5. 전제조건(CLAUDE.md, 테스트 러너) 점검 후 경고 출력
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
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
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
  AGENT_EXT="toml"
else
  SKILLS_DIR="$TARGET/.claude/skills"
  AGENTS_DIR="$TARGET/.claude/agents"
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

echo "== ai-dev-workflow-kit · backend 설치 =="
echo "  kit       : $KIT_ROOT"
echo "  대상      : $TARGET"
echo "  플랫폼    : $PLATFORM (skills=$SKILLS_DIR, agents=$AGENTS_DIR)"
[[ "$DRY_RUN" == "1" ]] && echo "  모드      : DRY-RUN (변경 없음)"
echo ""

# --- 1. 디렉토리 생성 ---
run "mkdir -p '$SKILLS_DIR' '$AGENTS_DIR'"

# --- 2. 스킬 복사 (common + backend) ---
echo "[1/4] 스킬 복사"
run "cp -R '$KIT_ROOT/common/skills/.' '$SKILLS_DIR/'"
run "cp -R '$KIT_ROOT/backend/skills/.' '$SKILLS_DIR/'"

# --- 3. 에이전트 복사 (common + backend, 플랫폼 확장자) ---
echo "[2/4] 에이전트 복사 (*.$AGENT_EXT)"
run "cp '$KIT_ROOT/common/agents/'*.$AGENT_EXT '$AGENTS_DIR/'"
run "cp '$KIT_ROOT/backend/agents/'*.$AGENT_EXT '$AGENTS_DIR/'"

# --- 4. 어댑터 정리: backend.md 만 남긴다 ---
echo "[3/4] implement-agent 어댑터 정리 (backend만 유지)"
ADAPTERS_DIR="$SKILLS_DIR/implement-agent/adapters"
for stack in flutter unity; do
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

# --- 6. 전제조건 점검 (경고만, 비차단) ---
echo "[4/4] 전제조건 점검"
WARN=0

if [[ ! -f "$TARGET/CLAUDE.md" && ! -f "$TARGET/AGENTS.md" ]]; then
  echo "  ⚠ CLAUDE.md / AGENTS.md 가 없습니다. spec-writer·coder가 아키텍처 섹션을 참조합니다."
  echo "    → /init 로 생성 후 모듈 구조·레이어 규칙·ORM·테스트 러너를 보강하세요."
  WARN=1
fi

if [[ -f "$TARGET/package.json" ]]; then
  if ! grep -q '"test"' "$TARGET/package.json"; then
    echo "  ⚠ package.json 에 test 스크립트가 없습니다. backend 어댑터는 TDD 게이트로 'npm test'를 씁니다."
    WARN=1
  fi
  if ! grep -Eq '"(jest|vitest)"' "$TARGET/package.json"; then
    echo "  ⚠ jest/vitest 의존성이 보이지 않습니다. RED/GREEN 게이트에 테스트 러너가 필요합니다."
    WARN=1
  fi
else
  echo "  ⚠ package.json 이 없습니다. Node.js/NestJS 프로젝트가 맞는지 확인하세요."
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
  /plan-writer              → 기획서 (Docs/plans/)
  /spec-pipeline @기획서     → 명세 작성 + 검증
  /implement-agent @명세서   → 구현 (TDD 게이트 + backend-coding-rule, TASK≤2면 경량)
  /finalize-feature         → 마무리·아카이브·커밋 (소규모는 /finalize-minor-task)

이 스크립트는 파일 복사만 합니다. push·커밋은 하지 않습니다.
EOF
