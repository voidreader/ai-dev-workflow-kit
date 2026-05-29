---
name: implement-spec
description: 사용자로부터 전달된 명세서를 기반으로 요구사항 분석 및 구현 계획 수립을 진행한다. 프로젝트 아키텍처 규칙을 준수하여 구현을 진행하고 완료 후 산출물 문서를 생성한다.
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

## 언제 사용하나요?

- 자동으로 사용되지 않도록 한다.
- 사용자의 자의적 호출에 의해서 사용되도록 한다.

## Instructions

1. 사용자로부터 전달된 명세서 파일 경로를 확인한다.

- 명세서 파일이 전달되지 않은 경우:
  - 사용자에게 "명세서 파일 경로를 전달해주세요. (예: Docs/spec/[spec]20260305_feature.md)" 메시지를 출력한다.
  - 경로가 전달될 때까지 구현을 진행하지 않는다.

2. 전달된 Markdown 파일을 읽는다.

- 일반적으로 전달된 명세서 파일의 규칙 : `[spec]날짜_주제.md`
- ex: `[spec]20260309_new-skill.md`

3. 명세서를 기반으로 다음을 수행한다.

- 요구사항 분석
- 수정 대상 파일 목록 식별

4. **리모트 브랜치 충돌 감지** (명세서 분석 후, 구현 계획 수립 전에 수행)

   명세서에서 식별한 수정 대상 파일과 다른 개발자의 작업 및 main 최신 변경사항이 겹치는지 확인한다.

   a. `git fetch --all`을 실행하여 리모트 브랜치 정보를 갱신한다.
   b. **main 브랜치 변경사항 확인**: 현재 브랜치가 `main`에서 분기한 이후 `main`에 머지된 변경 파일을 확인한다.
      - `git diff --name-only HEAD...origin/main` 사용
   c. **활성 작업 브랜치 변경사항 확인**: 리모트의 활성 작업 브랜치(`feat/`, `fix/` 접두어)를 조회하고, 각 브랜치에서 `main` 분기 이후 변경된 파일 목록을 확인한다.
      - `git diff --name-only main...<remote-branch>` 사용
      - 현재 자신의 브랜치는 검사 대상에서 제외한다.
   d. 수정 대상 파일과 겹치는 변경이 감지되면:
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

5. 구현 계획을 수립한다.

**변경 범위 규칙** :

- 수정이 필요한 파일 목록을 먼저 식별한다.
- 해당 범위를 벗어나는 파일 수정은 금지한다.
- 범위를 벗어난 수정이 필요하면 사용자에게 반드시 확인 요청을 한다.

6. 요구사항 분석 및 구현 계획 수립 도중 확인이 필요한 사항, 명세서 내용간 모순이 있다면 사용자에게 확인을 요청한다.

7. **EnterPlanMode를 사용하여** 구현 계획을 수립 후, 사용자에게 승인을 받는다.
   - Plan Mode에서 코드베이스를 탐색하고 구현 방향을 설계한다.
   - 계획이 확정되면 ExitPlanMode로 사용자 승인을 받는다.
   - 승인을 받게 되면 개발을 시작한다.

8. 개발 진행 (계획 실행)

   개발 시 준수사항:
   - 최적화를 염두해서 개발을 진행한다.
   - 의존성을 되도록 줄이는 방향을 고려한다.
   - CLAUDE.md 코멘트 정책 준수
   - CLAUDE.md 금지사항을 준수하고, 부득이하게 위반해야하는 경우는 사유를 반드시 사용자에게 알려준다.
   - freezed/json_serializable/riverpod_generator를 사용하는 파일 수정 시, build_runner 재실행이 필요함을 안내한다.

9. 구현 완료 — 검증 및 산출물 생성

   구현이 끝나면 아래 a~b를 **하나의 완료 단계**로 모두 수행한다. 검증만 하고 문서 생성을 빠뜨리지 않는다.

   a. **정적 분석 검증 (빌드 게이트)**

      1. `cd band_of_mercenaries && flutter analyze`를 실행하여 분석 오류를 점검한다.
      2. freezed/json_serializable/hive/riverpod 모델이 변경된 경우 `cd band_of_mercenaries && dart run build_runner build --delete-conflicting-outputs`를 실행한다.
      3. 새로 생성한 클래스/Provider가 기존 코드에서 올바르게 참조되는지 확인한다.
      4. import 구문 누락, 오타, 패키지 불일치 등 명백한 오류를 점검한다.

      **빌드 에러 발생 시 처리:**
      - 단순한 import 누락이나 오타 등 명백한 1~2줄 수정으로 해결 가능한 에러는 main이 직접 수정한다.
      - 다음 경우 `dart-build-resolver` 에이전트를 Agent()로 호출하여 위임한다:
        - 3개 이상의 분석 에러가 동시에 발생
        - freezed/hive typeId 중복 등 코드 생성 충돌
        - pub 의존성 버전 충돌
        - main이 한 번 수정 시도했으나 새 에러가 파생된 경우

      **dart-build-resolver 호출 시 프롬프트 내용:**
      - 실패한 명령 출력 전문
      - 변경 파일 목록
      - 원본 작업 명세서 (컨텍스트 참조용)
      - 경계 규칙: "기능 추가·리팩토링 금지. 빌드 에러만 외과적으로 수정한다."

      **resolver 결과 처리:**
      - SUCCESS → 다음 단계(산출물 생성)로 진행
      - PARTIAL/FAILED → 잔여 에러를 사용자에게 보고하고 판단 요청 (계속 진행 / 수동 수정 / 중단)
      - resolver가 추가로 수정한 파일은 변경 파일 목록에 합산한다.

      build_runner 재실행이 추가로 필요한 경우 사용자에게 안내한다.

   b. **plan 문서 생성** (필수)
      - 명세서 파일명에서 `.md` 확장자를 제거한 이름을 `{specBase}`로 사용한다.
        - 예: 명세서가 `[spec]20260318_quest-system.md`인 경우, `{specBase}` = `[spec]20260318_quest-system`
      - 파일명: `{specBase}_plan.md`
      - 위치: `Docs/spec/` (명세서와 동일한 디렉토리)
      - 내용:
        - 최상단에 사용한 스킬명 기재. ex: `Skill used : implement-spec`
        - 수립한 구현 계획과 실제 개발 사항 정리
        - 변경 파일 목록 (파일 경로, 변경 유형, 설명)
        - build_runner 재실행이 필요한 파일 목록 (해당 시)
        - CLAUDE.md 금지사항 위반이 있었다면 사유와 함께 명시

   **피드백 반영**: 사용자 테스트 중 피드백이 있으면 해당 문서를 업데이트한다.

   ** 생성, 변경되는 모든 마크다운 문서는 기술적인 용어를 유지하며, 한국어 스타일을 유지한다. **

10. 워크플로우 안내

> **CLAUDE.md 업데이트, CHANGELOG Fragment 생성은 이 스킬에서 수행하지 않는다.**
> 이 작업들은 `finalize-feature` 스킬에서 일괄 처리한다.

- 이 스킬은 git commit과 문서 아카이브를 수행하지 않는다.
- 구현 완료 후 사용자에게 다음을 안내한다:
  - "커밋과 아카이브가 필요하시면 `finalize-feature` 스킬을 실행해주세요."
  - 변경된 파일 목록 요약
  - build_runner 재실행이 필요한 경우 해당 내용 안내
  - 생성된 산출물 문서 경로 안내
