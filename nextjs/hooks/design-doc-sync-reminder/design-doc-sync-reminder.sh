#!/usr/bin/env bash

set -euo pipefail

payload="$(cat)"

json_paths="$(
  printf '%s' "$payload" | jq -r '
    [
      .tool_input.file_path?,
      .tool_input.filePath?,
      .tool_input.path?,
      .tool_response.file_path?,
      .tool_response.filePath?,
      .tool_response.path?
    ]
    | map(select(type == "string" and length > 0))
    | .[]
  ' 2>/dev/null || true
)"

patch_paths="$(
  printf '%s' "$payload" | jq -r '
    if (.tool_input | type) == "string" then
      .tool_input
    elif (.tool_input.patch? | type) == "string" then
      .tool_input.patch
    else
      empty
    end
  ' 2>/dev/null \
    | awk '/^\*\*\* (Add|Update|Delete) File: / {
        sub(/^\*\*\* (Add|Update|Delete) File: /, "")
        print
      }' || true
)"

paths="$(
  {
    printf '%s\n' "$json_paths"
    printf '%s\n' "$patch_paths"
  } | sed '/^$/d' | sort -u
)"

should_remind=false

while IFS= read -r path; do
  [ -n "$path" ] || continue

  relative_path="${path#"$PWD"/}"

  case "$relative_path" in
    *.test.ts|*.test.tsx)
      continue
      ;;
  esac

  case "$relative_path" in
    src/app/*page.tsx|*/src/app/*page.tsx|\
    src/app/*route.ts|*/src/app/*route.ts|\
    src/app/*route.tsx|*/src/app/*route.tsx|\
    src/app/*layout.tsx|*/src/app/*layout.tsx|\
    src/app/*loading.tsx|*/src/app/*loading.tsx|\
    src/app/*error.tsx|*/src/app/*error.tsx|\
    src/app/*opengraph-image.tsx|*/src/app/*opengraph-image.tsx|\
    src/features/*.tsx|*/src/features/*.tsx)
      should_remind=true
      break
      ;;
  esac
done <<EOF
$paths
EOF

if [ "$should_remind" = false ]; then
  exit 0
fi

printf '%s' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[문서 동기화 점검] 방금 화면/구성요소 파일을 수정했습니다. 화면을 추가·삭제·이동했거나 구성요소·상태·토큰을 바꿨다면, 같은 작업 안에서 Docs/design/ 문서(page-inventory, component-inventory, interaction-states, design-tokens, figma-handoff)의 갱신 필요 여부를 확인하세요. 규칙은 AGENTS.md의 「화면 변경 시 문서 동기화 규칙」 참고."}}'
