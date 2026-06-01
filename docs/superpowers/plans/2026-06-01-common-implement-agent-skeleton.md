# 공통 implement-agent 골격 + 스택 어댑터 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 스택 무관 `common/skills/implement-agent` 골격과 flutter/unity/backend 어댑터, 공통 planner/coder/verifier 에이전트, backend-reviewer를 만들어 백엔드(TDD)·기존 스택을 하나의 흐름으로 다룬다.

**Architecture:** 골격 SKILL.md는 오케스트레이션 흐름만 담고, 스택별로 달라지는 검증 게이트·리뷰어·명령은 `adapters/<stack>.md`가 선언한다. 골격은 시작 시 배포된 단일 어댑터를 Read해서 동작한다 (`spec-pipeline`의 "런타임 스택 버전 Read" 패턴 계승).

**Tech Stack:** Markdown 스킬·에이전트 문서 (코드 아님). Claude용 `.md` + Codex용 `.toml`.

> **검증 방식 주의:** 이 산출물은 실행 코드가 아니라 마크다운 문서다. 따라서 "실패하는 테스트 → 통과" TDD 루프를 적용할 수 없다. 각 Task의 검증 스텝은 문서 산출물에 맞춰 **(a) frontmatter 유효성, (b) 필수 섹션·슬롯 커버리지 grep, (c) 교차 참조 일관성**으로 대체한다. 설계 SSOT는 `docs/superpowers/specs/2026-06-01-common-implement-agent-skeleton-design.md`다.

---

## File Structure

신규 생성 파일과 각자의 책임:

- `common/skills/implement-agent/adapters/_interface.md` — 어댑터가 채워야 할 슬롯 6개의 계약서. 다른 어댑터·골격이 이 슬롯 이름을 공유한다.
- `common/skills/implement-agent/adapters/backend.md` — 검증모드 `tdd`. NestJS/Node 게이트 명령·reviewer 지정.
- `common/skills/implement-agent/adapters/flutter.md` — 검증모드 `build-gate`. analyze + build_runner.
- `common/skills/implement-agent/adapters/unity.md` — 검증모드 `build-gate`. 컴파일 검증.
- `common/skills/implement-agent/SKILL.md` — 골격. PHASE 0~3 흐름. 어댑터 슬롯을 읽어 분기.
- `common/agents/planner.md` + `.toml` — 스택 중립 계획 에이전트.
- `common/agents/coder.md` + `.toml` — 스택 중립 구현 에이전트. TDD 모드 시 RED 테스트 작성 책임 포함.
- `common/agents/verifier.md` + `.toml` — 스택 중립 명세 준수 검증 에이전트.
- `backend/agents/backend-reviewer.md` + `.toml` — Node/NestJS 코드 품질 검증 에이전트(2단계 리뷰).

수정 파일:

- `README.md` — 스킬·에이전트 인덱스 표에 신규 항목 추가.

의존 순서: `_interface.md`(Task 1) → 어댑터들(Task 2,3) → 골격(Task 4, 어댑터 슬롯 참조) → 공통 에이전트(Task 5,6,7) → backend-reviewer(Task 8) → README+최종검증(Task 9). 골격(Task 4)은 어댑터 슬롯 이름에 의존하므로 Task 1 이후여야 한다. 에이전트(5~8)는 골격과 독립이라 Task 4와 병렬 가능.

---

### Task 1: 어댑터 인터페이스 계약서 `_interface.md`

**Files:**
- Create: `common/skills/implement-agent/adapters/_interface.md`

이 파일이 슬롯 이름의 SSOT다. 이후 모든 어댑터와 골격이 여기 정의된 슬롯 이름을 그대로 쓴다.

- [ ] **Step 1: 파일 작성**

아래 내용 전체를 작성한다:

````markdown
# 어댑터 인터페이스 (계약서)

이 디렉토리의 각 `<stack>.md`는 아래 슬롯을 **모두** 채워야 한다. 골격 `SKILL.md`는
이 슬롯 이름만 알고, 안에 든 값은 모른다. 새 스택 추가 = 이 슬롯을 채운 파일 1개 작성.

배포 시 대상 프로젝트에는 `SKILL.md` + 해당 스택 어댑터 1개만 복사된다. 골격은 PHASE 0에서
`adapters/` 안의 단일 `*.md`(이 `_interface.md` 제외)를 Read한다.

## 슬롯 목록

| 슬롯 | 의미 | 허용 값 / 형식 |
|---|---|---|
| `검증모드` | task 미니사이클 ②번 게이트의 종류 | `tdd` 또는 `build-gate` |
| `게이트 명령` | ②에서 실행할 셸 명령 | 셸 명령 문자열 (여러 개면 순서대로) |
| `coder 규칙` | coder 에이전트가 preload할 스택 규칙 스킬 이름 | 스킬 이름 목록 (없으면 "없음") |
| `2단계 reviewer` | ④ 품질 검증에 쓸 에이전트 이름 | 에이전트 이름 (없으면 "없음 — main 직접 리뷰") |
| `build resolver` | 게이트 실패 시 위임할 에이전트 | 에이전트 이름 (없으면 "없음") |
| `작업 디렉토리` | 게이트 명령을 실행할 기준 경로 | 프로젝트 상대 경로 (루트면 ".") |

## 검증모드별 골격 동작 (참고)

- `tdd`: 미니사이클 ①이 (①-a) coder가 실패 테스트 작성 → (②-a) 게이트 명령으로 RED 확인
  → (①-b) coder가 최소 구현 → (②-b) 게이트 명령으로 GREEN 확인 으로 전개된다.
- `build-gate`: ① coder 구현 → ② 게이트 명령 PASS 확인.

## 어댑터 작성 형식

각 어댑터는 위 슬롯을 다음 형식의 표로 선언하고, 그 아래 스택 특이사항을 자유 서술한다:

```markdown
# <스택명> 어댑터

| 슬롯 | 값 |
|---|---|
| 검증모드 | ... |
| 게이트 명령 | ... |
| coder 규칙 | ... |
| 2단계 reviewer | ... |
| build resolver | ... |
| 작업 디렉토리 | ... |

## 스택 특이사항
...
```
````

- [ ] **Step 2: 검증 — 슬롯 6개가 모두 정의됐는지 확인**

Run: `grep -cE '검증모드|게이트 명령|coder 규칙|2단계 reviewer|build resolver|작업 디렉토리' common/skills/implement-agent/adapters/_interface.md`
Expected: 6 이상 (슬롯 표 + 동작 설명에서 반복되므로 6보다 클 수 있음)

- [ ] **Step 3: 커밋**

```bash
git add common/skills/implement-agent/adapters/_interface.md
git commit -m "implement-agent 어댑터 인터페이스 계약서 추가"
```

---

### Task 2: backend 어댑터 (TDD 모드)

**Files:**
- Create: `common/skills/implement-agent/adapters/backend.md`

- [ ] **Step 1: 파일 작성**

`_interface.md`의 어댑터 형식을 따라 작성한다:

````markdown
# 백엔드(NestJS/Node.js) 어댑터

| 슬롯 | 값 |
|---|---|
| 검증모드 | tdd |
| 게이트 명령 | `npm test`  (또는 프로젝트에 vitest 설정 시 `npx vitest run`) |
| coder 규칙 | 없음 (백엔드 규칙 스킬이 생기면 여기 추가) |
| 2단계 reviewer | backend-reviewer |
| build resolver | 없음 (타입 에러는 coder가 `npx tsc --noEmit`로 자체 해결) |
| 작업 디렉토리 | . |

## 스택 특이사항

- **검증모드 tdd**: 골격은 task마다 coder에게 먼저 실패 테스트(`*.spec.ts`)를 작성시키고,
  `npm test`로 RED를 확인한 뒤 구현 → GREEN을 확인한다. RED 단계에서 테스트가 통과해버리면
  (= 테스트가 기능을 검증하지 못함) 골격은 해당 task를 coder에게 반려한다.
- 테스트 러너는 프로젝트 설정을 따른다. Jest면 `npm test`, Vitest면 `npx vitest run`.
  단일 파일만 돌리려면 `npm test -- <파일경로>`를 쓴다.
- coder는 구현 전 `npx tsc --noEmit`로 타입 정합성을 자체 확인한다.
- e2e 테스트(`*.e2e-spec.ts`)는 task 미니사이클의 게이트에서 제외하고 PHASE 3 통합 점검으로 미룬다
  (단위 테스트만 task 게이트로 사용).
````

- [ ] **Step 2: 검증 — 검증모드가 tdd이고 reviewer가 backend-reviewer인지 확인**

Run: `grep -E '검증모드 \| tdd|2단계 reviewer \| backend-reviewer' common/skills/implement-agent/adapters/backend.md`
Expected: 두 줄 모두 출력됨

- [ ] **Step 3: 커밋**

```bash
git add common/skills/implement-agent/adapters/backend.md
git commit -m "implement-agent backend 어댑터(TDD 모드) 추가"
```

---

### Task 3: flutter / unity 어댑터 (build-gate 모드)

**Files:**
- Create: `common/skills/implement-agent/adapters/flutter.md`
- Create: `common/skills/implement-agent/adapters/unity.md`

둘 다 build-gate라 한 Task로 묶는다. 값은 기존 `flutter/skills/implement-agent`·`unity/skills/implement-agent`의 게이트에서 가져온다.

- [ ] **Step 1: flutter 어댑터 작성**

````markdown
# Flutter 어댑터

| 슬롯 | 값 |
|---|---|
| 검증모드 | build-gate |
| 게이트 명령 | `flutter analyze <변경 파일>` + (모델 변경 시) `dart run build_runner build --delete-conflicting-outputs` |
| coder 규칙 | 없음 (Flutter 규칙은 coder 본문에 내장) |
| 2단계 reviewer | flutter-reviewer |
| build resolver | dart-build-resolver |
| 작업 디렉토리 | band_of_mercenaries |

## 스택 특이사항

- **검증모드 build-gate**: task마다 coder 구현 후 `flutter analyze`(변경 파일 한정)를 PASS시킨다.
  freezed/json_serializable/hive/riverpod 모델 변경 시 `build_runner`를 먼저 실행한다.
- 게이트 실패가 3개 이상 에러·코드생성 충돌·의존성 충돌이면 `dart-build-resolver`에 위임한다.
- TDD는 강제하지 않는다. 기존 테스트가 있으면 coder가 실행해 회귀만 확인한다.
````

- [ ] **Step 2: unity 어댑터 작성**

````markdown
# Unity 어댑터

| 슬롯 | 값 |
|---|---|
| 검증모드 | build-gate |
| 게이트 명령 | Unity 컴파일 검증 (프로젝트의 컴파일/배치 빌드 스크립트) |
| coder 규칙 | error-handling, unity-script-rule |
| 2단계 reviewer | 없음 — main 직접 리뷰 (TASK 적으면 경량 검증) |
| build resolver | 없음 |
| 작업 디렉토리 | . |

## 스택 특이사항

- **검증모드 build-gate**: task마다 coder 구현 후 Unity 컴파일 검증을 PASS시킨다.
- coder는 `error-handling`·`unity-script-rule` 스킬을 preload해 라이프사이클·GetComponent 캐싱·
  Fake Null 등 Unity 관용 실수를 방지한다.
- TDD는 강제하지 않는다. 게임 로직은 주로 사용자 플레이 테스트로 검증한다.
````

- [ ] **Step 3: 검증 — 두 어댑터가 build-gate이고 coder 규칙이 맞는지 확인**

Run: `grep -H '검증모드 \| build-gate' common/skills/implement-agent/adapters/flutter.md common/skills/implement-agent/adapters/unity.md && grep 'error-handling, unity-script-rule' common/skills/implement-agent/adapters/unity.md`
Expected: flutter.md·unity.md 각각 build-gate 한 줄 + unity의 coder 규칙 줄 출력

- [ ] **Step 4: 커밋**

```bash
git add common/skills/implement-agent/adapters/flutter.md common/skills/implement-agent/adapters/unity.md
git commit -m "implement-agent flutter/unity 어댑터(build-gate) 추가"
```

---

### Task 4: 골격 SKILL.md

**Files:**
- Create: `common/skills/implement-agent/SKILL.md`

골격은 흐름만 담는다. 스택 명령·리뷰어 이름을 하드코딩하지 않고 어댑터 슬롯을 참조한다. 설계 문서 §4의 PHASE 흐름을 본문으로 구현한다.

- [ ] **Step 1: frontmatter 작성**

```markdown
---
name: implement-agent
description: 명세서를 기반으로 스택 어댑터를 로드하여, planner→coder→verifier→(어댑터 지정)reviewer 파이프라인을 subagent-driven 방식으로 조율해 task를 격리 구현한다. 검증 게이트(TDD/빌드)는 어댑터가 선언한다.
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **
```

- [ ] **Step 2: PHASE 0~1 본문 작성 (어댑터 로드 + 계획)**

```markdown
## 언제 사용하나요?
- 자동으로 사용되지 않도록 한다. 사용자의 자의적 호출로만 사용한다.
- 명세서를 받아 격리된 task 단위로 구현·검증할 때 사용한다.

## PHASE 0: 어댑터 로드
1. `adapters/` 디렉토리에서 `_interface.md`를 제외한 단일 `*.md`를 Read한다.
   - 파일이 0개면 "스택 어댑터가 없습니다. adapters/에 <stack>.md를 배포하세요." 출력 후 중단.
   - 2개 이상이면 사용자에게 어느 어댑터를 쓸지 묻는다.
2. 어댑터의 슬롯 6개(검증모드·게이트 명령·coder 규칙·2단계 reviewer·build resolver·작업 디렉토리)를
   읽어 이번 실행의 동작 파라미터로 확정한다.

## PHASE 1: 계획 수립
1. 사용자가 전달한 명세서 파일을 Read한다. 없으면 경로를 요청하고 중단한다.
2. `planner` 에이전트를 Agent()로 호출한다. 프롬프트에 포함:
   - 명세서 전문
   - 어댑터에서 읽은 스택 컨텍스트 (검증모드, 게이트 명령, 작업 디렉토리)
   - 변경 범위 규칙(범위 밖 수정 금지, 필요 시 사용자 확인)
3. planner의 "사용자 확인 필요" 항목이 있으면 해소될 때까지 사용자와 반복한다.
4. 통합 계획 리포트(task 목록 + task별 추천 모델)를 사용자에게 보여주고 승인을 받는다.
```

- [ ] **Step 3: PHASE 2 본문 작성 (task 미니사이클 + 검증모드 분기)**

```markdown
## PHASE 2: 구현 (subagent-driven, task 격리)
계획의 task를 의존성 순서로 한 번에 1개씩 처리한다. task 사이에는 사용자 체크인을 하지 않는다
(continuous execution). 각 task는 아래 미니사이클을 따른다.

### task 미니사이클
① coder 호출 — 해당 TASK 단독. 어댑터의 `coder 규칙`을 preload 대상으로 전달.
   coder에게 task별 추천 모델(haiku/sonnet/opus)을 model 파라미터로 전달한다.
② 검증 게이트 — 어댑터의 `검증모드`로 분기:
   - tdd:
     ①-a coder가 실패 테스트 먼저 작성
     ②-a `게이트 명령`을 `작업 디렉토리`에서 실행 → RED(실패) 확인. 통과해버리면 coder에 반려.
     ①-b coder가 최소 구현
     ②-b `게이트 명령` 실행 → GREEN(통과) 확인.
   - build-gate:
     ① coder 구현
     ② `게이트 명령` 실행 → PASS 확인. 실패 시 `build resolver`가 있으면 위임, 없으면 coder 재호출.
③ verifier 호출 (명세 준수, 1단계 리뷰) — PASS/FAIL.
④ 2단계 리뷰 — 어댑터의 `2단계 reviewer`가:
   - 에이전트 이름이면 그 에이전트를 호출 (APPROVE/BLOCK).
   - "없음 — main 직접 리뷰"면 main이 변경 파일을 직접 점검.
⑤ 요약만 보관하고 coder·verifier·reviewer의 응답 전문은 폐기한 뒤 다음 task로 진행.

### 재시도 규칙
②/③/④에서 FAIL·BLOCK이면 같은 coder를 이슈와 함께 재호출 → 해당 단계 재검증. 최대 2회.
2회 후에도 실패하면 사용자에게 보고하고 판단을 요청한다.
```

- [ ] **Step 4: PHASE 3 + 종료 안내 작성 (산출물 생성 단계 없음)**

```markdown
## PHASE 3: 통합 sanity check
모든 task 완료 후, task 간 통합 정합성만 점검한다.
- tdd 어댑터: 전체 테스트 1회 실행(`게이트 명령`) + 미뤄둔 e2e가 있으면 안내.
- build-gate 어댑터: 전체 빌드/분석 1회 실행.
- 시그니처 충돌·누락된 연결(wiring)을 변경 파일 범위에서 확인한다.

## 종료
이 스킬은 커밋·문서 아카이브·산출물 문서(plan 문서)를 생성하지 않는다.
구현·검증 완료 후 다음만 안내한다:
- 변경 파일 목록 요약
- "커밋과 마무리가 필요하면 finalize-feature 스킬을 실행해주세요."
```

> 참고: 기존 flutter/unity implement-agent에 있던 "산출물 생성(`{specBase}_plan.md`)" 단계는 골격에 두지 않는다 (설계 §2.6).

- [ ] **Step 5: 검증 — 필수 PHASE와 어댑터 슬롯 참조 존재 확인**

Run: `grep -cE 'PHASE 0|PHASE 1|PHASE 2|PHASE 3|검증모드|2단계 reviewer|게이트 명령' common/skills/implement-agent/SKILL.md`
Expected: 7 이상

- [ ] **Step 6: 검증 — 스택 명령이 하드코딩되지 않았는지 확인 (골격은 스택 무관)**

Run: `grep -nE 'flutter analyze|build_runner|npm test|vitest|band_of_mercenaries' common/skills/implement-agent/SKILL.md`
Expected: 출력 없음 (골격 본문에 스택 명령이 직접 등장하면 안 됨 — 모두 어댑터 슬롯으로 참조)

- [ ] **Step 7: 커밋**

```bash
git add common/skills/implement-agent/SKILL.md
git commit -m "공통 implement-agent 골격 SKILL.md 추가 (PHASE 0~3, 어댑터 분기)"
```

---

### Task 5: 공통 planner 에이전트

**Files:**
- Create: `common/agents/planner.md`
- Create: `common/agents/planner.toml`

`flutter/agents/planner.md`를 베이스로 스택 종속 표현을 중립화한다.

- [ ] **Step 1: planner.md 작성**

`flutter/agents/planner.md`의 구조를 그대로 쓰되 아래를 치환한다:
- frontmatter `model: opus` 유지, `tools: Read, Grep, Glob, Bash` 유지.
- 2단계: `pubspec.yaml, analysis_options.yaml` → "프로젝트 설정 파일(언어/런타임별 manifest·lint 설정)".
- 4단계: "CLAUDE.md의 아키텍처 규칙 및 feature 모듈 구조(view/domain/data 3계층)" → "프로젝트 규칙 문서(CLAUDE.md/AGENTS.md)의 아키텍처 규칙". "Riverpod Provider/Notifier, Hive 저장소, Supabase 동기화" → "프로젝트의 기존 패턴(상태관리·저장소 접근·외부 동기화 등)".
- 5단계: "시그니처는 Dart 타입 시스템에 맞춰 작성" → "시그니처는 프로젝트 언어의 타입 시스템에 맞춰 작성".
- 복잡도 분류표의 예시(`위젯`, `enum`, `Provider`)는 언어 중립 예시로: mechanical="단순 데이터 모델·직렬화·상수 추가·기계적 매핑", integration="여러 파일 협력·기존 서비스 호출·일반 비즈니스 로직", architecture="새 도메인 모델·복잡 로직·동시성·새 패턴 도입".
- 출력 형식 §3 "Flutter/Dart 버전" → "언어/런타임 버전", "상태관리" → "아키텍처 스타일".
- **추가**: 입력 절에 "오케스트레이터가 전달하는 스택 컨텍스트(검증모드·게이트 명령·작업 디렉토리)를 계획에 반영한다. 검증모드가 tdd면 각 task에 '검증할 동작'을 명시해 coder가 테스트를 먼저 쓸 수 있게 한다." 한 줄 추가.

복잡도 분류표·출력 형식·규칙의 나머지는 원본을 그대로 유지한다.

- [ ] **Step 2: planner.toml 작성**

`common/agents/planner.md`의 본문을 `flutter/agents/coder.toml`과 동일한 형식으로 옮긴다:
```toml
name = "planner"
description = "<planner.md의 description 한 줄로 압축>"
developer_instructions = """
<planner.md의 frontmatter 아래 본문 전체>
"""
```
(`.toml`에는 tools/model 키를 넣지 않는다 — flutter/agents/coder.toml 형식과 동일.)

- [ ] **Step 3: 검증 — frontmatter·스택 중립성 확인**

Run: `head -8 common/agents/planner.md && grep -nE 'Riverpod|Hive|pubspec|Dart 타입|view/domain/data' common/agents/planner.md`
Expected: frontmatter에 name/description/tools/model 존재, 두 번째 grep은 출력 없음 (스택 종속 표현 제거됨)

- [ ] **Step 4: 커밋**

```bash
git add common/agents/planner.md common/agents/planner.toml
git commit -m "공통 planner 에이전트(스택 중립) 추가"
```

---

### Task 6: 공통 coder 에이전트

**Files:**
- Create: `common/agents/coder.md`
- Create: `common/agents/coder.toml`

`flutter/agents/coder.md` 베이스. 스택 중립화 + TDD 모드의 RED 테스트 작성 책임 + 규칙 preload 슬롯을 추가한다.

- [ ] **Step 1: coder.md 작성**

`flutter/agents/coder.md`의 구조를 쓰되:
- frontmatter `tools: Read, Write, Edit, Bash, Grep, Glob`, `model: sonnet` 유지.
- 2단계 "Flutter/Dart 규칙을 준수한다…(freezed/Riverpod/Hive)" 블록 → "오케스트레이터가 지정한 스택 규칙(preload된 스킬이 있으면 그 규칙)을 준수한다. 없으면 프로젝트 규칙 문서(CLAUDE.md/AGENTS.md)와 기존 코드 스타일을 따른다."
- 4단계 자가 점검: 스택 고정 명령(`band_of_mercenaries`, `build_runner`, `flutter analyze`) 제거. 대신 "오케스트레이터가 전달한 `게이트 명령`을 `작업 디렉토리`에서 실행해 자가 점검한다. 명령과 경로는 task 프롬프트에 포함된다."로 일반화.
- 출력 보고의 "build_runner / flutter analyze" 항목 → "게이트 명령 결과 / 테스트 결과".
- 규칙은 원본 유지(할당 task만, TODO 금지 등).

**TDD 모드 책임 추가** — 2단계 위에 새 절을 넣는다:

```markdown
## 1.5단계: TDD 모드일 때 (검증모드=tdd)
오케스트레이터가 검증모드를 tdd로 전달한 경우, 코드 작성 순서를 다음으로 한다:
1. task의 "검증할 동작"을 대상으로 **실패하는 테스트를 먼저 작성**한다.
2. 게이트 명령으로 실행해 테스트가 실패(RED)하는지 확인하고 완료 보고에 RED 결과를 기재한다.
   - 테스트가 곧바로 통과하면 그 테스트는 기능을 검증하지 못하는 것이므로 다시 작성한다.
3. 그 뒤 최소 구현으로 테스트를 통과(GREEN)시킨다.
build-gate 모드면 이 절을 건너뛰고 2단계로 간다.
```

**규칙 preload 슬롯 반영** — frontmatter 처리: 공통 coder는 특정 스킬을 고정 preload하지 않는다. 대신 frontmatter에 `skills:` 키를 두지 않고, 본문 1단계에 "오케스트레이터가 `coder 규칙`으로 전달한 스킬이 있으면 그 규칙을 먼저 확인한다."를 넣는다. (배포 시 스택이 unity면, 그 프로젝트에서 coder에 `skills: [error-handling, unity-script-rule]`를 덧붙이는 것은 어댑터/배포 단계 책임 — 후속 작업. 1차에서는 본문 지시로 충분.)

- [ ] **Step 2: coder.toml 작성**

`flutter/agents/coder.toml` 형식대로 `common/agents/coder.md` 본문을 옮긴다 (name/description/developer_instructions).

- [ ] **Step 3: 검증 — TDD 절·스택 중립성 확인**

Run: `grep -nE 'TDD 모드일 때|실패하는 테스트를 먼저' common/agents/coder.md && grep -nE 'band_of_mercenaries|build_runner|flutter analyze' common/agents/coder.md`
Expected: 첫 grep 출력 있음(TDD 절 존재), 두 번째 grep 출력 없음(스택 명령 제거)

- [ ] **Step 4: 커밋**

```bash
git add common/agents/coder.md common/agents/coder.toml
git commit -m "공통 coder 에이전트(TDD RED 작성 책임 포함) 추가"
```

---

### Task 7: 공통 verifier 에이전트

**Files:**
- Create: `common/agents/verifier.md`
- Create: `common/agents/verifier.toml`

`flutter/agents/verifier.md` 베이스. 명세 준수 검증은 본래 스택 무관에 가까우므로 컨텍스트만 중립화한다.

- [ ] **Step 1: verifier.md 작성**

`flutter/agents/verifier.md`를 쓰되:
- frontmatter `tools: Read, Bash, Grep, Glob`, `model: opus` 유지.
- description·본문의 "Flutter/Dart 코드 품질 검증은 flutter-reviewer가 별도로 수행" → "코드 품질 검증은 어댑터가 지정한 reviewer가 별도로 수행". "Flutter/Dart 코드가" → "코드가".
- "# 프로젝트 컨텍스트" 절(위치 band_of_mercenaries / Riverpod / freezed / 3계층)을 삭제하고 "# 프로젝트 컨텍스트\n오케스트레이터가 전달한 스택 컨텍스트(검증모드·게이트 명령·작업 디렉토리)와 프로젝트 규칙 문서를 기준으로 검증한다."로 대체.
- 5단계 "coder의 빌드 결과 참고": `flutter analyze`/`build_runner` 고정 항목 → "coder가 보고한 게이트 명령·테스트 결과"로 일반화.
- 규칙의 "Flutter/Dart 코드 품질 이슈… flutter-reviewer 담당" → "코드 품질 이슈… 어댑터 지정 reviewer 담당".
- 판정 규칙(critical/high→FAIL 등)·출력 형식은 원본 유지.

- [ ] **Step 2: verifier.toml 작성**

`flutter/agents/coder.toml` 형식대로 본문을 옮긴다.

- [ ] **Step 3: 검증 — 스택 중립성 확인**

Run: `grep -nE 'band_of_mercenaries|Riverpod|freezed|flutter-reviewer|view/.*domain/.*data' common/agents/verifier.md`
Expected: 출력 없음

- [ ] **Step 4: 커밋**

```bash
git add common/agents/verifier.md common/agents/verifier.toml
git commit -m "공통 verifier 에이전트(스택 중립) 추가"
```

---

### Task 8: backend-reviewer 에이전트

**Files:**
- Create: `backend/agents/backend-reviewer.md`
- Create: `backend/agents/backend-reviewer.toml`

`flutter/agents/flutter-reviewer.md`의 구조(읽기 전용, APPROVE/BLOCK, 심각도 판정)를 그대로 두고 체크리스트를 Node/NestJS로 교체한다.

- [ ] **Step 1: backend-reviewer.md 작성**

frontmatter:
```markdown
---
name: backend-reviewer
description: >
  Node.js/NestJS 백엔드 코드 품질을 전담 검증한다. 보안·아키텍처(레이어/DI)·에러 처리·
  비동기·타입 안전·테스트 품질·로깅·성능을 체크한다. 명세 준수 판정은 verifier 담당이며,
  이 에이전트는 "백엔드답게 잘 짰는가"만 본다. APPROVE/BLOCK 판정과 이슈 목록을 반환한다.
  코드를 직접 수정하지 않는 읽기 전용 에이전트다.
tools: Read, Bash, Grep, Glob
model: opus
---
```

본문은 flutter-reviewer의 절 구조(입력 / 1단계 변경 파일 확인 / 2단계 체크리스트 / 출력 형식 / 규칙)를 유지하고, 체크리스트를 다음으로 교체한다:

```markdown
### [CRITICAL] 보안
- 소스에 하드코딩된 시크릿/DB 자격증명/API key (환경변수·ConfigService 사용)
- SQL/NoSQL injection (파라미터 바인딩·ORM 쿼리빌더 미사용)
- 입력 검증 누락 (DTO + class-validator / 스키마 검증 부재)
- 민감 데이터 로깅, 인증/인가 가드 누락

### [CRITICAL] 아키텍처
- 레이어 경계 위반 — Controller에 비즈니스 로직 (Service로), Service에서 직접 DB 드라이버 접근 (Repository 경유)
- DI 위반 — `new`로 의존성 직접 생성 (생성자 주입 사용)
- 모듈 경계 위반 — 다른 모듈의 내부 provider 직접 import

### [CRITICAL] 비동기·에러
- floating promise (await 또는 void 처리 누락)
- 잡지 않은 rejection, 빈 catch로 삼킨 예외
- 도메인 예외를 HTTP 레이어까지 raw로 전파 (예외 필터·적절한 상태코드)

### [HIGH] 타입 안전
- `any` 남용, 부적절한 non-null `!`, 런타임 경계(요청 body·외부 응답)의 타입 미검증

### [HIGH] 테스트 품질 (검증모드 tdd의 핵심)
- 테스트가 동작이 아닌 구현 세부를 단언 (과도한 mock)
- happy path만 커버, 에러·경계 케이스 누락
- 테스트가 실제 기능을 검증하지 못하고 항상 통과 (assertion 부재)
- 외부 의존성(DB·HTTP) mock/stub 누락 또는 과잉

### [HIGH] 성능
- N+1 쿼리, 트랜잭션 경계 누락, 불필요한 동기 블로킹

### [MEDIUM] 관용·로깅
- 구조화된 로거 대신 `console.log`, 매직 넘버/문자열, 일관성 없는 네이밍
```

출력 형식(APPROVE/BLOCK + 이슈 목록)과 판정 규칙(critical·high→BLOCK, medium만→APPROVE with warnings, low/없음→APPROVE), 분류 라벨(보안|아키텍처|비동기|에러|타입|테스트|성능|로깅), 읽기 전용 규칙은 flutter-reviewer와 동일하게 유지한다.

- [ ] **Step 2: backend-reviewer.toml 작성**

`flutter/agents/coder.toml` 형식대로 본문을 옮긴다 (name/description/developer_instructions).

- [ ] **Step 3: 검증 — frontmatter·테스트 품질 절 확인**

Run: `head -12 backend/agents/backend-reviewer.md && grep -nE '테스트 품질|floating promise|injection' backend/agents/backend-reviewer.md`
Expected: frontmatter 정상, grep에 세 항목 모두 출력 (백엔드 체크리스트 반영됨)

- [ ] **Step 4: 커밋**

```bash
mkdir -p backend/agents
git add backend/agents/backend-reviewer.md backend/agents/backend-reviewer.toml
git commit -m "backend-reviewer 에이전트(Node/NestJS 품질 검증) 추가"
```

---

### Task 9: README 인덱스 갱신 + 최종 일관성 검증

**Files:**
- Modify: `README.md` (스킬·에이전트 인덱스 표)

- [ ] **Step 1: common/skills 표에 implement-agent 행 추가**

`README.md`의 "### common/skills" 표(현재 plan-writer~google-sheets-safe-edit)에 행 추가:
```markdown
| implement-agent | 스택 어댑터를 로드해 planner→coder→verifier→(어댑터 지정)reviewer 파이프라인을 subagent-driven으로 조율. 검증 게이트(TDD/빌드)는 어댑터가 선언 | Opus |
```
그리고 표 위 설명 문단에 "`implement-agent`는 골격이고 스택별 검증은 `adapters/<stack>.md`가 선언한다 (flutter/unity/backend 제공)." 한 줄을 덧붙인다.

- [ ] **Step 2: common/agents 표 갱신**

"### common/agents" 절의 "현재 비어 있다" 문장을 표로 교체:
```markdown
| 에이전트 | 설명 | 모델 |
|---|---|---|
| planner | 명세 분석 + 구현 계획 통합 (스택 중립, 어댑터 컨텍스트 주입) | Opus |
| coder | 계획의 개별 task 구현 (TDD 모드 시 RED 테스트 직접 작성) | Sonnet |
| verifier | 구현이 명세를 충족하는지 검증 (스택 중립) | Opus |
```

- [ ] **Step 3: backend 섹션 추가**

에이전트 인덱스에 "### backend/agents" 절을 신설(unity/agents 절 뒤):
```markdown
### backend/agents

| 에이전트 | 설명 | 모델 |
|---|---|---|
| backend-reviewer | Node.js/NestJS 코드 품질 검증 (보안·레이어·비동기·타입·테스트 품질) | Opus |
```
디렉토리 구조 설명·카테고리 절에도 `backend/` 한 줄을 추가한다 (Node.js/NestJS 전용).

- [ ] **Step 4: 검증 — README에 신규 항목이 모두 들어갔는지 확인**

Run: `grep -cE 'implement-agent.*어댑터|backend-reviewer|planner .*스택 중립|backend/agents' README.md`
Expected: 4 이상

- [ ] **Step 5: 최종 교차 일관성 검증 (전체 산출물)**

Run:
```bash
ls common/skills/implement-agent/SKILL.md common/skills/implement-agent/adapters/*.md common/agents/{planner,coder,verifier}.{md,toml} backend/agents/backend-reviewer.{md,toml}
```
Expected: 12개 파일 모두 존재 (SKILL 1 + 어댑터 4 + 공통 에이전트 6 + backend-reviewer 2 = 13... 아래로 확인)

Run: `grep -l 'backend-reviewer' common/skills/implement-agent/adapters/backend.md backend/agents/backend-reviewer.md`
Expected: 두 파일 모두 — 어댑터의 `2단계 reviewer` 값과 실제 에이전트 파일명이 일치

Run: `grep -rnE 'flutter analyze|build_runner|npm test' common/agents/`
Expected: 출력 없음 (공통 에이전트에 스택 명령이 새지 않음)

- [ ] **Step 6: 커밋**

```bash
git add README.md
git commit -m "README 인덱스에 공통 implement-agent·어댑터·에이전트 반영"
```

---

## Self-Review

**1. Spec coverage** (설계 문서 §8 산출물 목록 대조):
- `_interface.md` → Task 1 ✓
- `backend.md` → Task 2 ✓
- `flutter.md`/`unity.md` → Task 3 ✓
- `SKILL.md` → Task 4 ✓
- `common/agents/{planner,coder,verifier}.{md,toml}` → Task 5,6,7 ✓
- `backend/agents/backend-reviewer.{md,toml}` → Task 8 ✓
- README 갱신 → Task 9 ✓
- 설계 §2의 결정(검증모드 어댑터 선언=Task1·4, RED는 coder=Task6, 산출물 단계 제거=Task4 Step4) 모두 반영 ✓

**2. Placeholder scan:** "TODO/TBD/나중에" 없음. 각 어댑터·골격·에이전트의 실제 본문을 인라인으로 제공. 에이전트 Task(5~7)는 "기존 파일 베이스 + 치환 규칙"으로 기술 — 원본 파일이 저장소에 존재하므로 실행 가능하고, 변환 규칙이 구체적이다.

**3. Type consistency:** 슬롯 이름 6개(검증모드/게이트 명령/coder 규칙/2단계 reviewer/build resolver/작업 디렉토리)가 Task 1·2·3·4·6에서 동일하게 사용됨. `2단계 reviewer` 값 `backend-reviewer`가 Task 2 어댑터와 Task 8 파일명·Task 9 검증에서 일치. 검증모드 값 `tdd`/`build-gate`가 전 Task에서 통일.

> Task 9 Step 5의 파일 개수: SKILL 1 + 어댑터(`_interface`+backend+flutter+unity=4) + 공통 에이전트 6 + backend-reviewer 2 = **13개**. 실행 시 `_interface.md` 포함해 확인할 것.
