#!/usr/bin/env bash
# ship-build 스킬에 동봉된 fastlane 템플릿의 ruby 문법을 검증한다.
# 플레이스홀더를 더미 값으로 치환한 뒤 `ruby -c`로 Syntax OK를 확인한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL_DIR="$ROOT/flutter/skills/ship-build/templates/fastlane"
fail=0
for tpl in "$TPL_DIR/ios-Fastfile.template" "$TPL_DIR/android-Fastfile.template"; do
  [ -f "$tpl" ] || { echo "FAIL: missing $tpl"; fail=1; continue; }
  sed -e 's/__APP_ID__/com.example.dummy/g' \
      -e 's/__APP_NAME__/Dummy/g' \
      -e 's/__IPA_NAME__/Dummy.ipa/g' \
      -e 's/__PACKAGE__/com.example.dummy/g' \
      -e 's/__PROFILE_NAME__/com.example.dummy AppStore/g' \
      -e 's/__APPLE_ID__/dev@example.com/g' \
      -e 's/__TEAM_ID__/ABCDE12345/g' \
      -e 's/__ASC_KEY_ID__/ABCDE12345/g' \
      -e 's/__ASC_ISSUER_ID__/00000000-0000-0000-0000-000000000000/g' "$tpl" \
    | ruby -c 2>/dev/null | grep -q "Syntax OK" || { echo "FAIL: ruby syntax in $tpl"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "validate-fastlane: OK" || exit 1
