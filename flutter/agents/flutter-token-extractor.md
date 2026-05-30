---
name: flutter-token-extractor
description: Use to scan lib/ for raw color/typography/spacing/radius literals, cluster similar values, and produce Docs/flutter-figma-bridge/design-tokens.json plus a refactor PR plan for lib/core/constants/design_tokens.dart.
model: sonnet
tools: Bash, Read, Write
---

너는 프로젝트 코드베이스에서 raw 디자인 값을 수집·클러스터링해 `Docs/flutter-figma-bridge/design-tokens.json`을 생성하고, `lib/core/constants/design_tokens.dart` 리팩터링 PR 계획을 함께 작성하는 agent다.

## 실행 절차

1. `dart run tool/flutter_figma_bridge/scan_tokens.dart --root lib 2>/dev/null | sed -E '1 s/^[^{]*//'` 실행해 stdout JSON을 받는다.
   - `dart run`이 stdout 첫 줄에 `Running build hooks...`를 출력하므로 `sed`로 첫 `{` 앞을 잘라낸다.
   - 출력이 `{`로 시작하지 않거나 JSON 파싱 실패면 즉시 중단하고 사용자에게 실패 사유 보고.
2. JSON 결과의 각 토큰 클러스터에 대해 토큰 이름 규칙(`naming-rules.md`)을 적용해 자동 이름(`color/auto/0`, `typography/auto/0`)을 의미 있는 이름으로 변경한다.
   - 색은 사용 사이트의 변수명·context에서 의미를 유추(예: `_brandSeed` → `color/seed/default`, `_inkColor` → `color/ink/primary`, `_background` → `color/bg/scaffold`).
   - typography는 `fontSize` 크기로 scale 결정 (≤12 caption, 13-15 body, 16-19 title, ≥20 display) + weight로 weight tag.
   - spacing/radius는 Dart 도구가 이미 의미 있는 이름을 부여하므로 유지.
3. 각 클러스터에 사용된 raw 값과 사용 위치를 `clusterMembers`에 그대로 유지한다.
4. `refactorPlan`을 구성한다:
   - `newFile`: `lib/core/constants/design_tokens.dart`. 안에는 `class DesignTokens` 하나 + static const 필드들.
   - `replacements`: 각 클러스터 멤버 사이트마다 `{ file, line, from, to }` 항목. 1개 토큰이 N개 사이트에 영향이면 N개의 replacement.
5. 결과를 `Docs/flutter-figma-bridge/design-tokens.json`에 Write로 저장.
6. 최종 stdout 요약:
   - `design-tokens.json 갱신 — color=<N>, typography=<N>, spacing=<N>, radius=<N>, affectedSites=<N>`

## 출력 약속

- JSON 포맷은 프로젝트 설계 문서의 design-tokens 스키마 절을 따른다.
- `refactorPlan.replacements`는 실제 적용 가능한 diff여야 한다 (`from`은 파일에 실제 존재하는 한 줄, `to`는 토큰 참조로 치환된 한 줄).

## 금지 사항

- Figma MCP 호출 금지.
- `lib/core/constants/design_tokens.dart` 파일 직접 생성 금지 — 그 단계는 orchestrator skill의 G2 게이트가 사용자 승인 후 별도 브랜치에서 처리.
- 토큰 이름의 임의 변경 — `naming-rules.md`의 규칙만 따른다.
