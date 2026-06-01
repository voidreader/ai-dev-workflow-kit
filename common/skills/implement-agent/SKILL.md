---
name: implement-agent
description: 명세서를 기반으로 스택 어댑터를 로드하여, planner→coder→verifier→(어댑터 지정)reviewer 파이프라인을 subagent-driven 방식으로 조율해 task를 격리 구현한다. 검증 게이트(TDD/빌드)는 어댑터가 선언한다.
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

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
