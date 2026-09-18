#!/usr/bin/env bash
#
# install-unity.sh — ai-dev-workflow-kit의 unity 스킬·에이전트·훅을 대상 프로젝트에 설치한다.
#
# 사용법:
#   scripts/install-unity.sh [옵션] <대상-프로젝트-경로>
#
# 옵션:
#   --claude          Claude 레이아웃만 (.claude/). 기본값.
#   --codex           Codex 레이아웃만 (.agents/skills, .codex/agents, .codex/hooks).
#   --both            둘 다. 스킬 실체는 .claude/skills 한 벌이고 .agents/skills 는 심링크다.
#   --docs-root <경로> 산출물 루트. 기본 Docs (kit 원본). 예: docs/workflow
#   --dry-run         실제로 복사하지 않고 수행할 작업만 출력한다.
#   -h, --help        도움말 출력.
#
# 동작:
#   1. common/skills(implement-agent·google-sheets-safe-edit 제외) + unity/skills → skills 디렉토리
#   2. common/agents + unity/agents (Claude=.md / Codex=.toml) → agents 디렉토리
#   3. --both 면 .agents/skills 를 .claude/skills 심링크로 건다
#   4. --codex 단독이면 spec-pipeline 의 .claude/skills 경로를 .agents/skills 로 보정
#   5. unity-pattern-guard 훅 복사 + settings 병합 안내 출력
#   6. --docs-root 지정 시 스킬 문서의 Docs/ 경로를 치환
#   7. 전제조건(ProjectSettings/ProjectVersion.txt) 점검 후 경고 출력
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"

PLATFORM="claude"
DOCS_ROOT="Docs"
DRY_RUN=0
TARGET=""

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)    PLATFORM="claude"; shift ;;
    --codex)     PLATFORM="codex"; shift ;;
    --both)      PLATFORM="both"; shift ;;
    --docs-root) DOCS_ROOT="${2:?--docs-root 에 경로가 필요합니다}"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    -h|--help)   usage 0 ;;
    -*)          echo "알 수 없는 옵션: $1" >&2; usage 1 ;;
    *)
      if [[ -n "$TARGET" ]]; then echo "대상 경로는 하나만 지정합니다: '$TARGET', '$1'" >&2; exit 1; fi
      TARGET="$1"; shift ;;
  esac
done

[[ -n "$TARGET" ]] || { echo "오류: 대상 프로젝트 경로가 필요합니다." >&2; usage 1; }
[[ -d "$TARGET" ]] || { echo "오류: 대상 경로가 디렉토리가 아닙니다: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

DOCS_ROOT="${DOCS_ROOT%/}"

# --- 레이아웃 결정 ---
# AGENT_TARGETS 원소는 "<디렉토리>:<확장자>" 형식이다.
SYMLINK_SKILLS=0
case "$PLATFORM" in
  claude)
    SKILLS_DIR="$TARGET/.claude/skills"
    AGENT_TARGETS=("$TARGET/.claude/agents:md")
    HOOK_TARGETS=("$TARGET/.claude/hooks")
    ;;
  codex)
    SKILLS_DIR="$TARGET/.agents/skills"
    AGENT_TARGETS=("$TARGET/.codex/agents:toml")
    HOOK_TARGETS=("$TARGET/.codex/hooks")
    ;;
  both)
    SKILLS_DIR="$TARGET/.claude/skills"
    AGENT_TARGETS=("$TARGET/.claude/agents:md" "$TARGET/.codex/agents:toml")
    HOOK_TARGETS=("$TARGET/.claude/hooks" "$TARGET/.codex/hooks")
    SYMLINK_SKILLS=1
    ;;
esac

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [dry-run] $*"
  else
    eval "$@"
  fi
}

# 산출물 경로 치환 — 순서가 중요하다.
# Docs/ 는 kit 에서 단일 루트고 그 아래 여러 하위 영역이 갈린다. 맨몸 Docs/ 는
# 명세서 자리라 specs/ 로 보내야 하므로, 이름 있는 하위 영역을 먼저 처리하고
# catch-all 을 맨 마지막에 둔다.
substitute_docs_root() {
  if [[ "$DOCS_ROOT" == "Docs" ]]; then
    echo "  기본값(Docs) — 치환 없음"
    return 0
  fi

  local -a exprs=(
    "s#Docs/plans#${DOCS_ROOT}/plans#g"
    "s#Docs/spec/#${DOCS_ROOT}/specs/#g"
    "s#Docs/Archive#${DOCS_ROOT}/specs/Archive#g"
    "s#Docs/changelog-fragments#${DOCS_ROOT}/changelog-fragments#g"
    "s#Docs/CHANGELOG#${DOCS_ROOT}/CHANGELOG#g"
    "s#Docs/milestone-runs#${DOCS_ROOT}/milestone-runs#g"
    "s#Docs/content-design#${DOCS_ROOT}/content-design#g"
    "s#Docs/balance-design#${DOCS_ROOT}/balance-design#g"
    "s#Docs/content-data#${DOCS_ROOT}/content-data#g"
    "s#Docs/roadmap#${DOCS_ROOT}/roadmap#g"
    "s#Docs/#${DOCS_ROOT}/specs/#g"
  )

  local sed_args=()
  local expr
  for expr in "${exprs[@]}"; do
    sed_args+=(-e "$expr")
  done

  echo "  Docs/ → ${DOCS_ROOT}/ (${#exprs[@]}개 규칙, catch-all 은 specs/)"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [dry-run] find '$SKILLS_DIR' -name '*.md' -exec sed -i '' ... {} +"
    return 0
  fi

  # BSD sed(macOS)와 GNU sed 모두에서 동작하도록 -i 백업 확장자를 명시하고 지운다.
  find "$SKILLS_DIR" -name '*.md' -type f -print0 \
    | xargs -0 sed -i.kitbak "${sed_args[@]}"
  find "$SKILLS_DIR" -name '*.md.kitbak' -type f -delete
}

echo "== ai-dev-workflow-kit · unity 설치 =="
echo "  kit       : $KIT_ROOT"
echo "  대상      : $TARGET"
echo "  플랫폼    : $PLATFORM (skills=$SKILLS_DIR)"
echo "  산출물루트: $DOCS_ROOT"
[[ "$DRY_RUN" == "1" ]] && echo "  모드      : DRY-RUN (변경 없음)"
echo ""

# --- 1. 스킬 복사 ---
echo "[1/6] 스킬 복사 (common + unity)"
if [[ "$SYMLINK_SKILLS" == "1" && -e "$TARGET/.agents/skills" && ! -L "$TARGET/.agents/skills" ]]; then
  echo "오류: $TARGET/.agents/skills 가 이미 실체 디렉토리입니다." >&2
  echo "      --both 는 이 경로를 심링크로 만듭니다. 기존 내용을 옮기거나 지운 뒤 다시 실행하세요." >&2
  exit 1
fi
run "mkdir -p '$SKILLS_DIR'"
run "cp -R '$KIT_ROOT/common/skills/.' '$SKILLS_DIR/'"
# common 의 implement-agent 는 어댑터 골격이라 unity 자립형 버전과 섞이면 adapters/ 잔재가 남는다.
# google-sheets-safe-edit 는 Unity 프로젝트와 무관하다.
run "rm -rf '$SKILLS_DIR/implement-agent' '$SKILLS_DIR/google-sheets-safe-edit'"
run "cp -R '$KIT_ROOT/unity/skills/.' '$SKILLS_DIR/'"

# --- 2. 에이전트 복사 ---
echo "[2/6] 에이전트 복사"
for entry in "${AGENT_TARGETS[@]}"; do
  dir="${entry%:*}"; ext="${entry##*:}"
  run "mkdir -p '$dir'"
  run "cp '$KIT_ROOT/common/agents/'*.$ext '$dir/' 2>/dev/null || true"
  run "cp '$KIT_ROOT/unity/agents/'*.$ext '$dir/' 2>/dev/null || true"
done

# --- 3. 심링크 (--both) ---
if [[ "$SYMLINK_SKILLS" == "1" ]]; then
  echo "[3/6] .agents/skills → .claude/skills 심링크"
  run "mkdir -p '$TARGET/.agents'"
  run "ln -sfn ../.claude/skills '$TARGET/.agents/skills'"
else
  echo "[3/6] 심링크 없음 (단독 레이아웃)"
fi

# --- 4. Codex 단독 경로 보정 ---
# --both 는 심링크로 두 경로가 같은 파일을 가리키므로 보정이 필요 없다.
if [[ "$PLATFORM" == "codex" ]]; then
  echo "[3.5] Codex 경로 보정 (spec-pipeline)"
  PIPELINE="$SKILLS_DIR/spec-pipeline/SKILL.md"
  if [[ -f "$PIPELINE" || "$DRY_RUN" == "1" ]]; then
    run "sed -i.bak 's#\\.claude/skills#.agents/skills#g' '$PIPELINE' && rm -f '$PIPELINE.bak'"
  fi
fi

# --- 5. 훅 복사 ---
echo "[4/6] unity-pattern-guard 훅 복사"
for hook_dir in "${HOOK_TARGETS[@]}"; do
  run "mkdir -p '$hook_dir'"
  run "rm -rf '$hook_dir/unity-pattern-guard'"
  run "cp -R '$KIT_ROOT/unity/hooks/unity-pattern-guard' '$hook_dir/'"
  run "rm -rf '$hook_dir/unity-pattern-guard/.pytest_cache'"
done

# --- 6. 산출물 경로 치환 ---
echo "[5/6] 산출물 경로 치환"
substitute_docs_root

# --- 7. 전제조건 점검 ---
echo "[6/6] 전제조건 점검"
if [[ ! -f "$TARGET/ProjectSettings/ProjectVersion.txt" ]]; then
  echo "  ⚠ ProjectSettings/ProjectVersion.txt 이 없습니다. Unity 프로젝트가 맞는지 확인하세요."
else
  echo "  ✓ 점검 통과"
fi

echo ""
echo "== 완료 =="
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY-RUN 이었습니다. 실제 설치하려면 --dry-run 없이 다시 실행하세요."
  exit 0
fi
cat <<EOF

설치된 워크플로우:
  /plan-writer → /spec-pipeline @기획서 → /implement-agent|implement-spec → /finalize-feature
  소규모 작업: /finalize-minor-task
  참조 스킬 : unity-script-rule · error-handling · unity-developer · unity-refactor

수동 추가 단계:
  1) 훅을 켜려면 unity/hooks/unity-pattern-guard/install.<platform>.json 의 hooks 블록을
     대상 프로젝트 설정(.claude/settings.json · .codex/hooks.json)에 병합하세요.
  2) 훅 설정(.../unity-pattern-guard/config.py)의 SCOPE_MARKER·EXCLUDED_SEGMENTS·
     SEVERITY_OVERRIDES 를 프로젝트에 맞게 좁히세요. 기본값은 범용값입니다.

이 스크립트는 파일 복사만 합니다. push·커밋은 하지 않습니다.
EOF
