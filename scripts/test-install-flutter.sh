#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install-flutter.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_flutter_project() {
  local path="$1"
  mkdir -p "$path"
  printf 'name: installer_fixture\n' > "$path/pubspec.yaml"
}

codex_target="$TEST_ROOT/codex-new"
make_flutter_project "$codex_target"
bash "$INSTALLER" --codex "$codex_target" > "$TEST_ROOT/codex-new.log"
[[ -f "$codex_target/AGENTS.md" ]] || fail "Codex 신규 프로젝트에 AGENTS.md가 설치되지 않았습니다."
cmp "$SCRIPT_DIR/../flutter/templates/AGENTS.md" "$codex_target/AGENTS.md" >/dev/null || \
  fail "설치된 AGENTS.md가 Flutter 템플릿과 다릅니다."

claude_target="$TEST_ROOT/claude-new"
make_flutter_project "$claude_target"
bash "$INSTALLER" "$claude_target" > "$TEST_ROOT/claude-new.log"
[[ -f "$claude_target/CLAUDE.md" ]] || fail "Claude 신규 프로젝트에 CLAUDE.md가 설치되지 않았습니다."
cmp "$SCRIPT_DIR/../flutter/templates/AGENTS.md" "$claude_target/CLAUDE.md" >/dev/null || \
  fail "설치된 CLAUDE.md가 Flutter 템플릿과 다릅니다."

existing_target="$TEST_ROOT/existing"
make_flutter_project "$existing_target"
printf '기존 프로젝트 지침\n' > "$existing_target/AGENTS.md"
cp "$existing_target/AGENTS.md" "$TEST_ROOT/AGENTS.before"
bash "$INSTALLER" --codex "$existing_target" > "$TEST_ROOT/existing.log"
cmp "$TEST_ROOT/AGENTS.before" "$existing_target/AGENTS.md" >/dev/null || \
  fail "기존 AGENTS.md가 변경되었습니다."
grep -q '기존 지침을 유지' "$TEST_ROOT/existing.log" || \
  fail "기존 지침을 유지한다는 안내가 없습니다."

dry_run_target="$TEST_ROOT/dry-run"
make_flutter_project "$dry_run_target"
bash "$INSTALLER" --codex --dry-run "$dry_run_target" > "$TEST_ROOT/dry-run.log"
[[ ! -e "$dry_run_target/AGENTS.md" ]] || fail "dry-run이 AGENTS.md를 생성했습니다."
grep -q 'AGENTS.md' "$TEST_ROOT/dry-run.log" || fail "dry-run 출력에 지침 설치 계획이 없습니다."

echo "PASS: Flutter 설치 지침 동작"
