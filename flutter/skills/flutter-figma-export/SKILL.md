---
name: flutter-figma-export
description: Use when the user wants to push a Flutter app (widgets, design tokens, screens) into Figma — either initial setup or re-export after code changes. Walks through gates with subagent dispatch and produces Docs/flutter-figma-bridge/ artifacts plus an updated Figma file. For pixel-art drawn by CustomPainter, use pixel-painter-figma-sync instead.
---

`flutter-figma-export` skill — Flutter 앱(위젯·디자인 토큰·스크린)을 Figma 디자인 시스템 + 스크린으로 idempotent하게 export한다. 여러 게이트에서 사용자 승인을 받는다.

> `CustomPainter`로 코드가 직접 그리는 픽셀아트는 이 스킬이 아니라 `pixel-painter-figma-sync`로 다룬다.

## 구성 요소

| 구성 요소 | 위치(권장 배치) | 비고 |
|---|---|---|
| orchestrator skill | 이 `SKILL.md` | — |
| `flutter-widget-analyzer` | agent | sonnet |
| `flutter-token-extractor` | agent | sonnet |
| `flutter-figma-designer` | agent | **opus 고정** |
| `flutter-figma-writer` | agent | sonnet |
| `flutter-figma-screen-renderer` | agent | **opus** |
| 결정적 Dart 도구 | `tool/flutter_figma_bridge/` ← `tools/scan_widgets.dart`, `tools/scan_tokens.dart`, `tools/models.dart` | — |
| 자산 업로드 스크립트 | `scripts/flutter_figma_bridge/upload_asset.sh` ← `tools/upload_asset.sh` | raw bytes POST |
| 영속 산출물 | `Docs/flutter-figma-bridge/` | figma-state.json 등 |

> **배치:** 이 스킬의 `tools/`에 든 결정적 도구를 프로젝트의 `tool/flutter_figma_bridge/`와
> `scripts/flutter_figma_bridge/`로 복사해 둔다. 에이전트들이 그 경로를 `dart run`/`bash`로 호출한다.

## 인자

- `--dry-run` — 마지막 게이트까지 모든 분석·설계를 수행하지만 Figma write는 하지 않는다.
- `--only=tokens|components|screens` — writer 단계에서 부분 실행.
- `--force-tokens` — 토큰 hash가 같아도 강제 재push.

## 실행 흐름

### 0. 사전 점검
- `Docs/flutter-figma-bridge/figma-state.json` 존재 여부로 첫 실행 vs 후속 실행 판단.
- `git status --short` 확인. dirty 파일이 있으면 사용자에게 알리고 진행 여부 묻는다.
- `flutter analyze` 실행, 통과 안 되면 중단.

### G0. 네이밍 규칙 게이트 (첫 실행 한정)
- `flutter-figma-designer` agent를 `mode=draft-naming-rules`로 dispatch.
- 결과(`naming-rules.md`)를 Read해 요약 표시.
- `AskUserQuestion`: "이 네이밍 규칙으로 진행할까요?" — 승인 / 수정 요청 / 중단.
- 수정 요청 시 free-form notes를 designer에게 다시 dispatch.

### G1. 분석 게이트
- `flutter-widget-analyzer` agent dispatch.
- `widget-usage.json` 읽어 요약: 총 위젯 수, top 10 빈도, 추출 후보 N개 표시.
- `AskUserQuestion`: 그대로 진행 / 일부 제외 / 추가 포함 / 중단.

### G2. 토큰 게이트
- `flutter-token-extractor` agent dispatch.
- `design-tokens.json` 읽어 요약: 토큰 카운트, 클러스터 미리보기, refactorPlan의 replacements 수 표시.
- `AskUserQuestion`:
  - 승인 → 토큰 PR 브랜치 생성 (`feat/flutter-figma-export-token-refactor`). `design_tokens.dart` 작성 + replacements 적용. **자동 머지 안 함.**
  - 토큰 일부 수정 요청 → notes와 함께 token-extractor 재dispatch.
  - 중단.
- 승인 시 PR 브랜치를 만들고 사용자에게 `gh pr create` 명령을 안내 (orchestrator가 자동으로 PR 생성하지는 않음).

### G3. 컴포넌트 분류 게이트
- `flutter-figma-designer` agent를 `mode=design-components`로 dispatch.
- `component-catalog.json` 읽어 요약: 컴포넌트 N개, variants 통계, 각 컴포넌트의 `decisionReason` 일부.
- `AskUserQuestion`: 승인 / 일부 수정 요청 / 중단.

### G4. 스크린 조립 게이트
- `flutter-figma-designer` agent를 `mode=design-screens`로 dispatch.
- `screen-blueprints.json` 읽어 요약: 스크린 N개, 각 스크린의 자식 instance 수, `unmappedNotes` 항목.
- `AskUserQuestion`:
  - 승인 → write 단계 진입.
  - unmapped 항목 처리 요청 → notes와 함께 G3로 되돌아가 카탈로그 확장.
  - 중단.

### Write 단계
- `flutter-figma-writer` agent dispatch.
- 인자 그대로 전달 (`--dry-run`, `--only=...`, `--force-tokens`).
- writer가 끝나면:
  - dry-run이었으면 호출 계획 JSON을 사용자에게 표시하고 종료.
  - 실제 write였으면 `figma-state.json` 갱신 확인 후 다음 단계.

### 최종 검토
- `flutter-figma-designer` agent를 `mode=final-review`로 dispatch.
- designer가 만든 한국어 요약을 사용자에게 표시.
- screenshots/ 경로 안내.
- `AskUserQuestion`:
  - 만족 → 종료.
  - 재실행 (특정 only 모드) → write 단계로 되돌아감.

### 후속 실행 모드의 diff 표시

`figma-state.json`이 이미 존재하면 각 게이트에서 다음을 추가로 보여준다.

- G1: 직전 widget-usage 대비 추가/제거/usageCount 변동 위젯.
- G2: 직전 design-tokens 대비 새 토큰·삭제된 토큰·값 변경된 토큰.
- G3: 직전 component-catalog 대비 새 컴포넌트·삭제·variant 추가.
- G4: 직전 blueprints 대비 새 스크린·삭제·자식 변경.

diff는 designer가 mode=design-components / design-screens에서 직전 catalog를 입력으로 받았으므로 같은 id 매칭이 자동으로 됨.

## 게이트 응답 형식

각 게이트는 `AskUserQuestion`을 다음 옵션으로 호출한다:
1. **승인하고 다음으로** (recommended)
2. **부분 수정** (notes로 어떤 항목을 어떻게 바꿀지 받음, 같은 agent 재dispatch)
3. **중단** (현재까지의 산출물만 보존)

## 첫 실행 vs 후속 실행 차이

- 첫 실행: G0 포함, 모든 게이트에서 전체 목록 표시.
- 후속 실행: G0 건너뛰기, 게이트마다 직전 산출물과의 diff 위주 표시 ("지난번 대비 N개 추가, M개 변경").

## 사용자 안전

- 게이트에서 "중단" 선택 시 이미 만들어진 산출물(`widget-usage.json`, `design-tokens.json`, `component-catalog.json`)은 그대로 둔다 — 다음 실행 때 재사용 가능.
- writer 단계 진입 전에는 Figma 파일에 어떤 변경도 가하지 않는다.
- 자산 업로드는 반드시 `scripts/flutter_figma_bridge/upload_asset.sh` 경유 (raw bytes POST, multipart 금지).
- `figma-state.json`은 커밋 대상 — idempotent 실행과 후속 Figma→Flutter import의 ground truth.
- `naming-rules.md`는 1회 승인 후 stable. 변경은 사용자가 직접 PR로만.

## 산출물 폴더 (`Docs/flutter-figma-bridge/`)

| 파일 | 누가 만들고 | 누가 읽나 |
|---|---|---|
| `naming-rules.md` | G0에서 1회 작성, 승인 후 stable | designer agent |
| `widget-usage.json` | widget-analyzer (매 실행) | designer agent |
| `design-tokens.json` | token-extractor (매 실행) | designer, writer agent |
| `component-catalog.json` | designer (G3) | writer agent, 후속 import |
| `screen-blueprints.json` | designer (G4) | writer agent |
| `figma-state.json` | writer (매 실행) | 다음 실행, 후속 import |
| `screenshots/*.png` | writer 검증 단계 | 사람 |

> `screenshots/`는 용량이 크면 `.gitignore`에 등록한다.
