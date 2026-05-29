---
name: implement-agent
description: 사용자로부터 전달된 명세서를 기반으로 git 충돌 감지 후, 서브에이전트 파이프라인(planner → coder → verifier(spec) → flutter-reviewer(quality) → dart-build-resolver)을 직접 조율하여 구현을 진행하고 완료 후 산출물 문서를 생성한다. TASK 수가 많을 경우 superpowers 방식의 순차 격리 모드로 task별 two-stage review를 수행한다.
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

## 언제 사용하나요?

- 자동으로 사용되지 않도록 한다.
- 사용자의 자의적 호출에 의해서 사용되도록 한다.

## Instructions

1. 사용자로부터 전달된 명세서 파일 경로를 확인한다.

- 명세서 파일이 전달되지 않은 경우:
  - 사용자에게 "명세서 파일 경로를 전달해주세요. (예: Docs/spec/[spec]20260305_feature.md)" 메시지를 출력한다.
  - 경로가 전달될 때까지 다음 단계를 진행하지 않는다.

2. 전달된 Markdown 파일을 읽는다.

- 일반적으로 전달된 명세서 파일의 규칙 : `[spec]날짜_주제.md`
- ex: `[spec]20260309_new-skill.md`

3. **리모트 브랜치 충돌 감지** (명세서를 읽은 직후 수행)

   명세서에서 언급된 주요 파일/모듈과 다른 개발자의 작업 및 main 최신 변경사항이 겹치는지 확인한다.

   a. `git fetch --all`을 실행하여 리모트 브랜치 정보를 갱신한다.
   b. **main 브랜치 변경사항 확인**: 현재 브랜치가 `main`에서 분기한 이후 `main`에 머지된 변경 파일을 확인한다.
      - `git diff --name-only HEAD...origin/main` 사용
   c. **활성 작업 브랜치 변경사항 확인**: 리모트의 활성 작업 브랜치(`feat/`, `fix/` 접두어)를 조회하고, 각 브랜치에서 `main` 분기 이후 변경된 파일 목록을 확인한다.
      - `git diff --name-only main...<remote-branch>` 사용
      - 현재 자신의 브랜치는 검사 대상에서 제외한다.
   d. 명세서에서 언급된 파일/모듈과 겹치는 변경이 감지되면:
      - 사용자에게 충돌 가능성을 표시한다:
        ```
        ⚠️ 수정 범위 충돌 감지
        [main 변경사항]
        - 겹치는 파일: band_of_mercenaries/lib/core/providers/game_state.dart

        [작업 브랜치]
        - 브랜치: origin/feat/20260320_quest-system
        - 겹치는 파일: band_of_mercenaries/lib/features/quest/domain/quest_notifier.dart
        ```
      - **Slack 경고 발송**: 환경변수 `SLACK_WEBHOOK_DEV_ALERT`를 확인한다. 환경변수가 없으면 프로젝트 루트의 `.env` 파일에서 `SLACK_WEBHOOK_DEV_ALERT` 값을 읽는다. 웹훅 URL이 확보되면 Bash로 curl을 실행하여 Slack 경고를 발송한다. URL을 확보할 수 없으면 Slack 발송을 건너뛴다.
      - 사용자에게 "겹치는 작업이 감지되었습니다. 계속 진행하시겠습니까?" 확인을 요청한다.
      - 사용자가 승인하면 다음 단계로 진행한다.
   e. 겹침이 없으면 그대로 다음 단계로 진행한다.

4. **코딩 에이전트 파이프라인 실행**

   아래 PHASE를 순서대로 직접 실행한다. 어떤 PHASE도 건너뛰지 않는다.

   ### PHASE 1: 계획 수립 (analyzer + architect 통합)

   planner 에이전트를 Agent()로 호출한다.

   프롬프트에 포함할 내용:
   - 명세서 전문
   - git 충돌 감지에서 확인된 주의 파일 목록 (해당 시)
   - 변경 범위 규칙:
     - 수정이 필요한 파일 목록을 먼저 식별할 것.
     - 해당 범위를 벗어나는 파일 수정은 금지.
     - 범위를 벗어난 수정이 필요하면 사용자에게 반드시 확인 요청할 것.

   planner가 반환한 통합 계획 리포트(요구사항 분해 + 영향 범위 + 설계 방향 + 태스크 목록)를 확인한다.

   **"사용자 확인 필요" 항목이 있는 경우:**
   - 해당 질문을 사용자에게 전달한다.
   - 사용자 답변을 받은 후, 답변 내용을 포함하여 planner를 재호출한다.
   - 모든 질문이 해소될 때까지 반복한다.

   **"사용자 확인 필요" 항목이 없는 경우:**
   - 통합 계획 리포트를 사용자에게 보여주고 승인을 요청한다.

     ```
     ## 구현 계획 검토

     [통합 계획 리포트 내용]

     ---
     이 계획대로 진행할까요? 수정할 부분이 있으면 알려주세요.
     ```

   **사용자가 수정을 요청한 경우:**
   - 수정 요청 내용을 포함하여 planner를 재호출한다.
   - 수정된 계획서를 다시 보여준다.
   - 승인될 때까지 반복한다.

   **사용자가 승인한 경우:**
   - PHASE 2로 진행한다.

   ### PHASE 2: 구현

   구현 계획서의 "실행 순서"에 따라 coder 에이전트를 Agent()로 호출한다.

   **모델 선택 (superpowers의 model selection 방식):**

   planner가 각 TASK에 부여한 `추천 모델`(haiku/sonnet/opus)을 Agent 호출 시 `model` 파라미터로 그대로 전달한다.

   - `mechanical` 복잡도 → `model: "haiku"` — 기계적 구현, 명세에 시그니처 완전, 1-2 파일
   - `integration` 복잡도 → `model: "sonnet"` — 다중 파일 협력, Provider 연결, 일반 비즈니스 로직 (대부분의 task)
   - `architecture` 복잡도 → `model: "opus"` — 새 패턴 설계, 동시성, 복잡한 도메인 로직

   판단이 애매하거나 planner의 추천이 의심스러우면 **한 단계 위**로 올린다. 약한 모델로 재작업하는 비용이 capable 모델 한 번 쓰는 비용보다 크다.

   verifier·flutter-reviewer·planner·dart-build-resolver의 모델은 각 에이전트 frontmatter의 기본값을 사용한다 (별도 override 없음).

   **각 coder 호출 시 프롬프트에 포함할 내용:**
   - 해당 태스크(TASK-n)의 상세 내용
   - 전체 구현 계획서 (컨텍스트 참조용)
   - CLAUDE.md 준수사항 리마인드:
     - 최적화를 염두해서 개발을 진행한다.
     - 의존성을 되도록 줄이는 방향을 고려한다.
     - CLAUDE.md 코멘트 정책 준수
     - CLAUDE.md 금지사항을 준수하고, 부득이하게 위반해야하는 경우는 사유를 반드시 완료 보고에 포함한다.
   - **자가 점검 책임 (필수)**: coder는 코드 작성 후 다음을 자체 수행하고 결과를 완료 보고에 기재해야 한다:
     - 변경 파일에 대한 `flutter analyze` (변경 파일 경로 한정)
     - 모델 변경 시 `dart run build_runner build --delete-conflicting-outputs`
     - 변경한 도메인 서비스/Calculator/Notifier에 기존 테스트가 있으면 해당 테스트 실행
     - 빌드/분석/테스트 실패 시 명백한 원인은 자체 수정 후 재실행. 2회 시도 후에도 실패하면 그대로 완료 보고에 기재 (오케스트레이터의 PHASE 2.5에서 dart-build-resolver가 처리).
   - (재작업인 경우) verifier 또는 flutter-reviewer의 해당 태스크 수정 지시사항

   **실행 모드 분기 (TASK 수 기준):**

   계획 리포트의 TASK 개수에 따라 실행 방식을 분기한다.

   - **병렬 모드** (TASK 수 < 5): 실행 순서의 병렬 그룹을 활용한다. 모든 태스크 완료 후 PHASE 2.5 → PHASE 3을 일괄 수행한다.
   - **순차 격리 모드** (TASK 수 ≥ 5): superpowers의 subagent-driven-development 방식. 한 번에 1 TASK씩 처리하고 각 TASK 직후 즉시 verifier(spec) → flutter-reviewer(quality) 순으로 two-stage review를 수행한다. 두 리뷰 모두 통과 시 다음 TASK로 진행. main은 응답 전문을 폐기하고 요약만 보관하여 컨텍스트 누적을 방지한다.

   **공통 실행 규칙:**
   - 의존성이 있는 태스크는 반드시 선행 태스크 완료 후에 호출한다.
   - 각 coder 호출 시 프롬프트는 위에 명시된 내용을 그대로 사용한다.
   - coder가 "구현 불가능" 또는 "태스크 지시 모순"을 보고한 경우 사용자에게 보고하고 판단을 요청한다.

   #### 병렬 모드 절차

   - 실행 순서의 같은 단계에 있는 태스크는 병렬로 호출한다.
   - 각 coder의 완료 보고(변경 파일 목록 + 자가 점검 결과)를 수집하여 보관한다.
   - 모든 태스크가 완료되면 PHASE 2.5(빌드 게이트)로 진행한다.

   #### 순차 격리 모드 절차 (superpowers 방식)

   병렬 그룹을 무시하고 의존성 순서만 따라 한 번에 1 TASK씩 처리한다. **task 사이에는 사용자 체크인을 하지 않는다 (continuous execution).** 다음 경우에만 사용자에게 멈춰 보고한다:
   - coder가 BLOCKED 상태(구현 불가능·태스크 지시 모순)를 보고한 경우
   - verifier/flutter-reviewer가 2회 재시도 후에도 FAIL/BLOCK인 경우
   - 모든 TASK가 완료되어 PHASE 2.5로 넘어가는 시점

   **각 TASK의 미니 사이클:**

   1. **coder 호출** — 해당 TASK-n 단독. coder의 자가 점검 결과(빌드/분석/테스트)를 완료 보고에서 확인.
   2. **미니 검증 가이드 생성** — main이 해당 TASK 범위만으로 검증 가이드(아래 PHASE 3 형식)를 생성한다. 단일 TASK 범위의 직접 변경 파일·REQ별 확인 포인트·시그니처·호환성 체크만 포함.
   3. **verifier 호출 (spec compliance)** — 미니 검증 가이드 + 해당 TASK 명세 부분 + 탐색 제한 지시.
      - PASS / PASS(with warnings) → 다음 단계로 진행.
      - FAIL → 이슈 목록과 함께 같은 coder를 재호출한다 → verifier 재호출. **최대 2회**. 2회 후에도 FAIL이면 사용자에게 보고.
   4. **flutter-reviewer 호출 (code quality)** — verifier가 PASS 준 후에만 진행. 해당 TASK의 변경 파일 목록 + 역할 경계 명시("명세 준수는 verifier가 이미 PASS. Flutter/Dart 품질만 검증").
      - APPROVE / APPROVE(with warnings) → 다음 단계로 진행.
      - BLOCK → 이슈 목록(출처 태그 `[flutter-reviewer]`)과 함께 같은 coder를 재호출한다 → flutter-reviewer 재호출. **최대 2회**. 2회 후에도 BLOCK이면 사용자에게 보고.
   5. **요약 보관 및 응답 전문 폐기** — 두 리뷰 모두 통과하면 다음 형식으로 요약만 보관하고 coder·verifier·flutter-reviewer의 응답 전문은 폐기한다:
      ```
      [TASK-n: PASS]
      - 변경 파일: <전체 경로 목록>
      - 핵심 시그니처: <신규/변경된 공개 인터페이스 한두 줄>
      - 자가 점검: analyze=PASS / build_runner=PASS|N/A / test=PASS(n/n)|N/A
      - 이슈 기록: <warnings로 통과한 minor 항목 한 줄 요약, 없으면 "없음">
      ```
   6. 다음 TASK로 진행한다. 모든 TASK가 통과될 때까지 반복.

   모든 태스크가 완료되면 PHASE 2.5(빌드 게이트)로 진행한다.

   ### PHASE 2.5: 빌드 게이트 (전체 sanity check)

   순차 격리 모드에서는 coder가 task별로 자체 빌드/분석을 수행했지만, task 간 통합 빌드 정합성을 마지막에 한 번 더 확인한다. 병렬 모드에서는 이 단계가 최초의 통합 빌드 검증이다.

   **수행 절차:**

   a. `cd band_of_mercenaries && flutter analyze` 실행 (전체)
   b. 누적된 변경 파일에 freezed/json_serializable/hive/riverpod 모델이 포함되면 `cd band_of_mercenaries && dart run build_runner build --delete-conflicting-outputs` 실행
   c. 두 명령 모두 PASS인 경우 → PHASE 3으로 진행
   d. 에러가 발생한 경우 → `dart-build-resolver` 에이전트를 Agent()로 호출

   **dart-build-resolver 호출 시 프롬프트 내용:**
   - 실패한 명령 출력 전문
   - 누적된 변경 파일 목록 (순차 격리 모드의 경우 task별 요약에서 추출)
   - 원본 작업 명세서 (컨텍스트 참조용)
   - 경계 규칙: "기능 추가·리팩토링 금지. 빌드 에러만 외과적으로 수정한다."

   **dart-build-resolver 결과 처리:**
   - SUCCESS → PHASE 3으로 진행
   - PARTIAL/FAILED → 잔여 에러를 사용자에게 보고하고 판단 요청 (계속 진행 / 수동 수정 / 중단)
   - 수정한 파일이 추가로 발생하면 변경 파일 목록에 합산하여 PHASE 3에 전달

   ### PHASE 3: 검증

   PHASE 2.5 빌드 게이트를 통과한 후 진행한다. **두 검증자를 역할 분리하여 운영한다:**

   | 에이전트 | 검증 대상 |
   |---------|----------|
   | `verifier` | 명세 요구사항(REQ-n) 충족 + 구현 계획 시그니처 준수 + 기존 프로젝트 호환성 |
   | `flutter-reviewer` | Flutter/Dart 코드 품질 (보안·아키텍처·Riverpod·위젯·성능·라이프사이클·에러·테스트·Dart·접근성) |

   두 에이전트의 관심사는 겹치지 않는다. verifier는 "명세대로 만들었는가"를, flutter-reviewer는 "Flutter답게 잘 만들었는가"를 본다.

   #### PHASE 3 진입 전: 검증 가이드 생성 (필수)

   verifier를 호출하기 전에 main이 아래 형식의 **검증 가이드**를 직접 생성한다. main은 이미 명세서·계획 리포트·coder 보고를 보유하고 있으므로, 추가 파일 읽기 없이 인라인으로 추출한다.

   ```
   ## 검증 가이드

   ### 직접 변경 파일 (전체 읽기 필수)
   [coder 완료 보고에서 추출한 변경 파일 경로 목록]

   ### REQ별 확인 포인트
   - REQ-1: [명세의 요구사항 전문] → 확인 위치: [파일명]의 [클래스/함수명]
   - REQ-2: ...

   ### 시그니처 확인 (계획 리포트에서 추출)
   - [클래스명]: [파일경로]에 존재 여부 및 공개 인터페이스 일치 여부
   - [함수명]: [반환타입 및 파라미터] 시그니처 일치 여부

   ### 호환성 체크 포인트 (범위 제한 grep)
   - [체크 항목]: grep 대상 파일 범위를 명시. 예:
     - Hive typeId 충돌: 신규 typeId [XX] → [직접 변경된 모델 파일]에서만 grep
     - Provider 연결 확인: [신규 Provider명] → app.dart의 ref.listen 섹션만 확인
     - [기타 명세에서 도출된 연관 체크 포인트]
   - 위에 명시되지 않은 파일은 탐색하지 않는다.

   ### coder 결정사항
   - [명세와 다르게 구현된 부분이 있으면 기록. 없으면 "없음"]
   ```

   **검증 모드 분기 (TASK 수 기준)**

   계획 리포트의 TASK 개수에 따라 검증 깊이를 분기한다:

   - **경량 검증** (TASK 수 ≤ 2): main이 명세 검증 수행 + flutter-reviewer 1회 호출
   - **풀 검증** (3 ≤ TASK 수 ≤ 4): verifier와 flutter-reviewer를 단일 메시지에서 **병렬로** Agent() 호출
   - **순차 격리 모드 final integration** (TASK 수 ≥ 5): PHASE 2 내부 루프에서 이미 TASK별 검증이 완료되었으므로, 여기서는 task 간 통합 sanity check만 수행 (아래 3-C 참조)

   #### 3-A. 경량 검증

   TASK 수가 2개 이하일 때 적용한다. 다음을 순서대로 수행한다:

   1. **main 직접 명세 검증**
      - 검증 가이드의 "직접 변경 파일" 목록을 Read로 읽어 실제 내용을 확인한다.
      - "REQ별 확인 포인트"를 기준으로 각 요구사항 구현 여부를 대조한다.
      - "시그니처 확인" 항목을 기준으로 계획 시그니처 준수 여부를 확인한다.
      - "호환성 체크 포인트"에 명시된 범위 내에서만 grep을 수행한다.

   2. **flutter-reviewer 호출** (품질 리뷰)
      - 프롬프트에 변경 파일 목록과 원본 명세서를 전달한다.
      - 역할 경계 명시: "명세 준수는 main이 직접 검증. Flutter/Dart 품질만 검증한다."
      - 결과(APPROVE/BLOCK + 이슈 목록)를 수집한다.

   **판정:**
   - main 명세 검증 PASS + flutter-reviewer APPROVE → 5단계(산출물 생성)로 진행
   - 한쪽이라도 이슈 발생 시 → FAIL로 처리 → 이슈를 통합 정리 후 해당 TASK의 coder 재호출 (최대 2회 반복)
   - 2회 반복 후에도 FAIL → 사용자에게 보고 후 판단 요청

   #### 3-B. 풀 검증 (병렬 리뷰)

   TASK 수가 3~4개일 때 적용한다. verifier와 flutter-reviewer를 단일 메시지에서 **병렬로** Agent() 호출한다.

   각 에이전트에 전달할 내용:
   - **verifier**: 검증 가이드 + 원본 명세서 + 통합 계획 리포트 + 탐색 제한 지시 ("가이드에 명시된 파일과 포인트만 탐색")
   - **flutter-reviewer**: 변경 파일 목록 + 원본 명세서(참조용) + 역할 경계 명시 ("명세 준수 판정은 verifier 담당. Flutter/Dart 품질만 검증")

   **결과 취합:**

   두 결과를 main이 다음 규칙으로 통합한다:

   1. verifier가 FAIL → FAIL (명세 미충족은 차단 사유)
   2. verifier PASS + flutter-reviewer BLOCK → FAIL (품질 이슈도 차단 사유)
   3. verifier PASS + flutter-reviewer APPROVE → PASS
   4. verifier PASS(with warnings, minor만) + flutter-reviewer APPROVE → PASS (이슈 기록)

   **이슈 중복 병합:**
   - 두 에이전트가 같은 파일·같은 문제를 지적하면 하나로 통합한다 (출처는 `[verifier]` / `[flutter-reviewer]` / `[both]`로 태그).
   - 이슈 내용이 충돌할 경우(예: verifier는 "명세의 X 구현 필요" vs flutter-reviewer는 "해당 패턴 안티패턴") 사용자에게 판단 요청.

   **결과 처리:**
   - PASS → 5단계(산출물 생성)로 진행
   - FAIL → 통합된 이슈 목록의 각 항목을 해당 TASK-n의 coder에 재호출 (출처 태그 포함). 수정 완료 후 빌드 게이트(PHASE 2.5) → 병렬 리뷰 재실행. **최대 2회**.
   - 2회 후에도 FAIL → 사용자에게 보고 후 판단 요청

   #### 3-C. 순차 격리 모드 final integration sanity check

   TASK 수가 5개 이상일 때 적용한다. PHASE 2 내부 루프에서 이미 task별 verifier + flutter-reviewer가 PASS로 완료된 상태다. 여기서는 task 간 통합 관점만 점검한다.

   1. **main 직접 통합 점검** (범위 좁게)
      - PHASE 2에서 축적된 task별 요약을 모두 펼친다 (변경 파일 + 핵심 시그니처 + 자가 점검 결과).
      - 시그니처 충돌, 누락된 wiring(Provider 등록, Repository 연결, app.dart의 ref.listen 등) 여부를 검증 가이드의 호환성 체크 포인트 기준으로만 확인한다.
      - PHASE 2.5에서 dart-build-resolver가 수정한 파일이 있으면 해당 파일에 한해 PHASE 3-A 절차로 경량 재검증한다.

   2. **flutter-reviewer 호출 (final integration)** — 선택적이지만 권장
      - 모든 변경 파일 목록과 task별 요약 + 명시적 지시 "task 간 통합·일관성·교차 의존만 검증. 단일 task 내부 품질은 PHASE 2에서 이미 검증되었으므로 재검증하지 않는다"를 전달한다.
      - 결과 APPROVE/BLOCK 수집.

   **판정:**
   - main 통합 점검 PASS + (flutter-reviewer 호출 시) APPROVE → 5단계(산출물 생성)로 진행
   - 이슈 발생 시 → 해당 TASK의 coder 재호출 (최대 2회). 2회 후에도 실패하면 사용자에게 보고.

   ### 파이프라인 규칙

   - 어떤 PHASE도 건너뛰지 않는다. 단순한 작업이라도 전체 흐름을 따른다.
   - PHASE 1 승인 이후 구현을 시작한다. 사용자 승인 없이 PHASE 2로 진행하지 않는다.
   - 서브에이전트의 출력을 임의로 수정하거나 해석하지 않는다. 그대로 다음 단계에 전달한다.
   - 직접 코드를 작성하지 않는다. 모든 코드 작성은 coder 에이전트에 위임한다.
   - **순차 격리 모드의 task 사이에는 진행 보고를 하지 않는다 (continuous execution).** PHASE 1·2.5·3 진입 시점, BLOCKED 보고 시점, 모든 task 완료 시점에만 사용자에게 상황을 알린다.

   ### 에러 처리

   - 서브에이전트가 예상 출력 형식을 따르지 않은 경우: 같은 입력으로 1회 재호출한다. 2회 연속 형식 오류 시 사용자에게 보고한다.
   - 서브에이전트가 응답하지 않거나 실패한 경우: 사용자에게 즉시 보고하고 판단을 요청한다.
   - 어떤 상황에서도 사용자 확인 없이 임의로 작업을 종료하지 않는다.

5. **산출물 생성** (파이프라인 완료 후 수행)

   PHASE 3 검증이 통과되면 아래를 하나의 완료 단계로 모두 수행한다. 문서 생성을 빠뜨리지 않는다.

   a. **plan 문서 생성** (필수)
      - 명세서 파일명에서 `.md` 확장자를 제거한 이름을 `{specBase}`로 사용한다.
        - 예: 명세서가 `[spec]20260318_quest-system.md`인 경우, `{specBase}` = `[spec]20260318_quest-system`
      - 파일명: `{specBase}_plan.md`
      - 위치: `Docs/spec/` (명세서와 동일한 디렉토리)
      - 내용:
        - 최상단에 사용한 스킬명 기재. ex: `Skill used : implement-agent`
        - 수립한 구현 계획과 실제 개발 사항 정리
        - 변경 파일 목록 (파일 경로, 변경 유형, 설명)
        - 실행 모드 (병렬/순차 격리) 및 검증 모드 (경량/풀/순차 격리 final) / 결과 요약 (verifier·flutter-reviewer 각 PASS/FAIL 횟수, 수정된 이슈 목록)
        - build_runner 재실행이 필요한 파일 목록 (해당 시)
        - CLAUDE.md 금지사항 위반이 있었다면 사유와 함께 명시

   **피드백 반영**: 사용자 테스트 중 피드백이 있으면:
   - 피드백 내용을 포함하여 해당 TASK의 coder를 Agent()로 재호출한다.
   - 수정 완료 후 검증 모드에 맞춰 재검증한다:
     - 경량 검증이었으면 main 직접 + flutter-reviewer 1회
     - 풀 검증이었으면 verifier + flutter-reviewer 병렬 1회
     - 순차 격리였으면 해당 task 미니 사이클(verifier → flutter-reviewer)을 재실행
   - 해당 산출물 문서를 업데이트한다.

   ** 생성, 변경되는 모든 마크다운 문서는 기술적인 용어를 유지하며, 한국어 스타일을 유지한다. **

6. **워크플로우 안내**

> **CLAUDE.md 업데이트, CHANGELOG Fragment 생성은 이 스킬에서 수행하지 않는다.**
> 이 작업들은 `finalize-feature` 스킬에서 일괄 처리한다.

- 이 스킬은 git commit과 문서 아카이브를 수행하지 않는다.
- 구현 완료 후 사용자에게 다음을 안내한다:
  - "커밋과 아카이브가 필요하시면 `finalize-feature` 스킬을 실행해주세요."
  - 변경된 파일 목록 요약
  - build_runner 재실행이 필요한 경우 해당 내용 안내
  - 생성된 산출물 문서 경로 안내
