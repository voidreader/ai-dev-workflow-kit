# Harness 프로토콜 레퍼런스

이 문서는 모든 파일 스키마, 상태 키, 그리고 모든 phase 스킬이 사용하는 단계 전이 상태머신의
**단일 진실 공급원(SSOT)**이다. 각 스킬은 스키마를 재정의하지 않고 이 문서를 **인용**한다 (DRY 원칙).

> **설치 위치:** 이 문서는 `flame-harness` 오케스트레이터 스킬에 동봉되어 있다. 부트스트랩 시
> 오케스트레이터가 대상 프로젝트의 `docs/harness/protocol.md`로 복사하며, 이후 모든 스킬은
> 프로젝트 로컬 경로(`docs/harness/protocol.md`)를 인용한다.

동반 문서: [`docs/harness/game-gotchas.md`](game-gotchas.md) — generator가 구현하고 contract/evaluator가
강제하는 필수 견고성 패턴(오디오·햅틱·라이프사이클·성능·빌드/플랫폼). 동일하게 인용하며 재서술하지 않는다.

> **경로 정책 (kit 이식본):** 원본 harness는 절대경로(`/Users/.../credentials`,
> `/Users/.../<app_slug>`)를 사용했으나, kit 이식본은 이를 모두 **파라미터화**한다.
> - `credentials_dir` — 부트스트랩 시 환경변수 `FLAME_CREDENTIALS_DIR` 또는 사용자 입력으로 설정.
> - 게임 프로젝트 루트 — `<project_root>/<app_slug>` (`<project_root>` 기본값 = 현재 작업 디렉토리,
>   사용자가 지정 가능). 이 문서·스킬의 모든 경로 예시에서 `<project_root>`는 사용자가 정한 생성 위치다.

---

## 1. `config.md` 스키마

각 게임의 `docs/harness/config.md`는 다음 키를 담은 유효한 YAML이어야 한다:

```yaml
app_idea: ""  # 비어 있으면 research가 컨셉을 생성·추천. research 확정 후 채워짐
app_name: "<표시 이름>"
app_slug: "<kebab-case 식별자>"
bundle_id: "com.<company>.<id>"  # <id> = app_slug에서 하이픈/언더스코어 제거 (각 세그먼트는 [a-z0-9]+)
default_language: en      # 사용자가 대화하는 언어. 부트스트랩에서 설정 (예: ko, en)
orientation: portrait     # portrait | landscape — 게임의 단일 고정 방향 (plan이 설정)
strict_mode: true          # false면 QA 판정은 권고 수준
max_rounds: 3              # 기본값. generator/evaluator 루프 한도
skip_research: false       # true면 Phase A research 스킬 건너뜀
skip_admob: false          # true면 AdMob 통합 단계 건너뜀
auto_idea: false           # true면 research가 묻지 않고 최적 컨셉 자동 선택
auto_deploy: false         # true면 QA 후 사람 검수 일시정지 생략. PASS가 바로 배포로 진행

developer:                # 모든 값은 자격증명 파일(store-metadata)에서 옴 — 아래는 플레이스홀더
  company: "<회사/조직명>"
  first_name: "<App Review 연락처 이름>"
  last_name: "<App Review 연락처 성>"
  email: "<지원 이메일 / App Review·Play 연락처>"
  phone: "<App Review 연락처 전화번호, 예: +82 10-0000-0000>"
  privacy: "<개인정보 처리방침 URL (양 스토어)>"
  homepage: "<iOS 지원+마케팅 URL / Play 웹사이트>"
  copyright: "<저작권 문구>"

ios:
  team_id: "<Apple 개발자 팀 ID>"
  asc_key_id: "<App Store Connect API 키 ID>"
  asc_issuer_id: "<App Store Connect API issuer ID>"
  asc_private_key_path: "<AuthKey_<asc_key_id>.p8 절대경로>"

android:
  keystore_path: "<upload.jks 절대경로>"
  key_alias: "<키 별칭, 예: upload>"

credentials_dir: "<자격증명 디렉토리 절대경로>"   # 부트스트랩에서 FLAME_CREDENTIALS_DIR 또는 사용자 입력으로 설정

admob:
  enabled: true          # skip_admob일 때 false
  ios_app_id: ""         # ca-app-pub-XXXX~YYYY
  android_app_id: ""     # ca-app-pub-XXXX~ZZZZ
  ad_units: []           # { key, ios_id, android_id, format } 목록
```

### 키 참고

- `bundle_id`는 `com.<company>.<id>` 형식이며, `<id>`는 `app_slug`에서 하이픈·언더스코어를 모두 제거한
  **소문자** 문자열이다(각 reverse-DNS 세그먼트는 `[a-z0-9]+` 매칭. 하이픈/언더스코어/대문자가 있으면
  bundle id가 무효가 되어 iOS/Android 서명이 깨진다). 예: `swing-line` → `com.<company>.swingline`.
  **iOS·Android 양쪽에서 바이트 단위로 동일**해야 한다 — iOS `PRODUCT_BUNDLE_IDENTIFIER` ==
  Android `applicationId`(+ `namespace`) == 이 값. `flutter create`가 프로젝트명에서 파생한 다른 id를
  쓰지 않도록 명시적으로 설정한다.
- `credentials_dir`는 모든 자격증명 파일(keystore, p8 키 등)을 두는 공유 디렉토리다.
- 스킬은 자격증명 경로를 하드코딩하지 않는다. 반드시 `config.md`의 `credentials_dir`를 읽는다.
- `max_rounds`는 강제 판정 전까지 허용되는 generator→evaluator 사이클 수를 제어한다.

---

## 2. `state.md` 스키마

각 게임의 `docs/harness/state.md`는 실행 상태를 추적한다. 유효한 YAML이어야 한다.

```yaml
status: running          # running | paused | completed
current_phase: research  # 현재 실행 중인 phase 이름
current_round: 1         # 정수. generator→evaluator 사이클마다 증가
next_role: evaluator     # 다음에 실행할 역할 (접미사 없는 스킬 이름)
pause_reason: ""         # "" | rate_limit | manual_action | error
created_at: "2026-06-22T00:00:00Z"   # ISO-8601. 부트스트랩이 설정, 이후 불변
updated_at: "2026-06-22T00:00:00Z"   # ISO-8601. 모든 스킬이 쓸 때 갱신
resume_attempts: 0       # 정수. 일시정지 후 재개할 때마다 증가
```

### 키 정의

| 키 | 타입 | 허용 값 | 기록 주체 |
|---|---|---|---|
| `status` | enum | `running` \| `paused` \| `completed` | 모든 스킬 |
| `current_phase` | string | phase 이름 (전이표 참조) | 모든 스킬 |
| `current_round` | integer | ≥ 1 | generator, evaluator |
| `next_role` | string | 스킬 역할 이름 | 모든 스킬 |
| `pause_reason` | enum | `""` \| `rate_limit` \| `manual_action` \| `error` | 모든 스킬 |
| `created_at` | ISO-8601 string | — | 부트스트랩만 |
| `updated_at` | ISO-8601 string | — | 모든 스킬이 쓸 때 |
| `resume_attempts` | integer | ≥ 0 | resume 핸들러 |

**참고:** 타임스탬프는 스크립트가 아니라 런타임의 스킬이 기록한다.

---

## 3. `contract.md` 레이아웃

`docs/harness/contract.md`는 코딩 시작 전 Generator와 Evaluator 사이에서 협상된다.

```markdown
# Contract — <app_name>

## Mandatory Hard Gates

이 기준들은 협상 불가다. 하나라도 FAIL이면 다른 기준의 통과 여부와 무관하게 즉시 FAIL 판정.

1. `flutter analyze`가 0 issue 반환.
2. `flutter test` — 모든 테스트 통과.
3. 게임 로직에 TODO·stub·placeholder 없음 (grep으로 검증 가능).
4. 모든 튜닝 상수가 `game_config.dart`에 중앙화 — 게임플레이 코드에 매직 넘버 없음.
5. 게임 콘텐츠(적/레벨/웨이브)가 하드코딩이 아닌 데이터로 정의됨.
6. 설정된 모든 로케일의 현지화 완료 — `default_language`, 그리고 `default_language` ≠ `en`일 때 영어 — 누락 l10n 키 없음.
7. 코어 루프가 end-to-end 동작: 시작 → 플레이 → 승/패 → 재시작.
8. 시뮬레이터/에뮬레이터에서 크래시 0, 콘솔 에러 0으로 실행.

## Functional Criteria (게임별)

<!-- Generator가 AGREED 제출 전 게임별 수용 기준을 여기 추가. -->
<!-- 예:
- 플레이어가 탭하면 캐릭터가 100ms 내에 점프로 반응한다.
- 장애물 하나를 넘을 때마다 점수가 1 증가한다.
- 게임오버 화면에 최종 점수와 재시작 버튼이 표시된다.
-->

## Status: AGREED
```

---

## 4. `handoff/round-N-gen.md` 레이아웃

각 generator 라운드 후, generator는 `docs/harness/handoff/round-<N>-gen.md`를 쓴다.

```markdown
# Generator Handoff — Round <N>

## What Was Built / Fixed

<!-- 이번 라운드에서 구현한 기능 또는 수정한 버그 목록. -->

## Contract Self-Assessment

| Criterion | Status | Notes |
|---|---|---|
| flutter analyze zero errors | DONE / PARTIAL / FAIL | … |
| flutter test zero failures | DONE / PARTIAL / FAIL | … |
| Cold-start (iOS + Android) | DONE / PARTIAL / FAIL | … |
| Flame ≥ 30 fps | DONE / PARTIAL / FAIL | … |
| No hardcoded credentials | DONE / PARTIAL / FAIL | … |
| Bundle ID correct | DONE / PARTIAL / FAIL | … |
| Assets declared in pubspec | DONE / PARTIAL / FAIL | … |
| AdMob IDs from config | DONE / PARTIAL / FAIL | … |
| <game-specific criterion> | DONE / PARTIAL / FAIL | … |

## Test Results

```
flutter analyze 출력 (마지막 20줄로 축약)
```

```
flutter test 출력 (마지막 20줄로 축약)
```

## Environment Detection

- Flutter 버전: <`flutter --version` 출력>
- Dart 버전: <위에서>
- 스모크 테스트에 쓴 기기/에뮬레이터: <이름>

## Known Issues

<!-- 알려진 이슈·제약·보류 항목. 깨끗하면 "none". -->
```

---

## 5. `feedback/round-N-qa.md` 레이아웃

각 evaluator 라운드 후, evaluator는 `docs/harness/feedback/round-<N>-qa.md`를 쓴다.

```markdown
# QA Feedback — Round <N>

## Verdict

**PASS** / **FAIL**

## Evidence

실행한 명령과 출력(또는 스크린샷 경로):

| Command | Result | Screenshot / Log Path |
|---|---|---|
| `flutter analyze` | 0 errors | — |
| `flutter test` | 0 failures | — |
| Cold-start iOS | OK / CRASH | screenshots/round-<N>-ios-start.png |
| Cold-start Android | OK / CRASH | screenshots/round-<N>-android-start.png |
| FPS check | ≥ 30 fps | — |
| <game-specific check> | … | … |

## Failed Criteria

<!-- FAIL이면 각 실패 기준과 구체적·재현 가능한 수정 방법을 나열. -->
<!-- 예:
- **flutter analyze error**: `lib/game.dart:42` — 미사용 import `dart:html`. 수정: import 제거.
- **Cold-start crash (Android)**: `MainActivity.onCreate`의 NullPointerException. 수정: `super.onCreate()` 전에 FlameGame 초기화.
-->

<!-- PASS면 "none". -->
```

---

## 6. 로그 테이블 스키마

### `build-log.md`

`docs/harness/build-log.md`는 generator 라운드마다 한 행 누적.

```markdown
# Build Log

| Round | Phase | Score | Duration | Notes |
|---|---|---|---|---|
| 1 | generator | PASS | 12 m | Initial scaffold |
| 2 | generator | FAIL | 8 m | Flame fps regression |
```

컬럼 정의:

| 컬럼 | 내용 |
|---|---|
| Round | 정수 라운드 번호 |
| Phase | 행을 생성한 스킬 (`generator` \| `evaluator`) |
| Score | `PASS` \| `FAIL` \| `PARTIAL` |
| Duration | 소요 시간 (사람이 읽는 형식, 예 `5 m`) |
| Notes | 가장 중요한 변경/실패의 한 줄 요약 |

### `pipeline-log.md`

`docs/harness/pipeline-log.md`는 주요 harness 이벤트마다 한 행 추가.

```markdown
# Pipeline Log

| Time | Event | Phase | Details |
|---|---|---|---|
| 2026-06-22T10:00Z | start | bootstrap | config.md written |
| 2026-06-22T10:05Z | complete | research | 3 competitors analysed |
| 2026-06-22T10:30Z | pause | generator | rate_limit hit |
```

컬럼 정의:

| 컬럼 | 내용 |
|---|---|
| Time | ISO-8601 타임스탬프 (UTC) |
| Event | `start` \| `complete` \| `pause` \| `resume` \| `error` \| `handoff` \| `PASS` \| `FAIL` |
| Phase | 이벤트 시점의 현재 phase 이름 |
| Details | 자유 텍스트 한 줄 |

---

## 7. 단계 전이표

`current_phase`, `next_role`, `status` 전이를 지배하는 상태머신:

| current_phase | event | → next_role / next_phase |
|---|---|---|
| (init) | bootstrap | research (항상 — research는 내부적으로 `skip_research`를 존중: 탐색은 건너뛰되 클론 체크 + 스펙 작성은 수행) |
| research | complete | plan |
| plan | complete | design |
| design | complete | contract |
| contract | AGREED | generator (current_round=1) |
| generator | handoff | evaluator |
| evaluator | PASS | paused (manual_action, 사람 검수) — `auto_deploy: true`면 resume이 admob 디스패치 (skip_admob: true면 build) |
| evaluator | FAIL | generator (current_round+1) |
| evaluator | max_rounds | 강제 판정 후 PASS와 동일한 사람 검수 게이트 (auto_deploy: true 아니면 paused) → admob/build |
| admob      | complete       | build                                    |
| build      | complete       | screenshot                               |
| screenshot | complete       | submit                                   |
| submit     | metadata-done  | status=paused, pause_reason=manual_action|
| (paused)   | resume         | retro                                    |
| retro      | complete       | status=completed                         |
| any | rate_limit | status=paused, pause_reason=rate_limit |

> **참고 (kit 이식본):** admob~retro 단계는 kit에서 독립 `ship-*` 스킬로 분리되어 상태머신을 쓰지
> 않는다. 위 전이표의 admob~retro 행은 원본 harness 파이프라인의 흐름을 기록한 것이며, kit에서는
> Phase A(research~evaluator)만 이 상태머신을 따른다. evaluator PASS 이후에는 사람이 검수하고
> 반복 루프(plan-writer/spec-pipeline/implement)나 `ship-*` 스킬을 수동으로 호출한다.

### 상태 전이 규칙

1. 스킬은 종료 전 `state.md`를 원자적으로(쓰기 후 rename/덮어쓰기) 갱신해야 한다.
2. phase 스킬이 성공적으로 완료하고 파이프라인을 진행시킬 때, 같은 `state.md` 갱신에서 `status: running`을
   `current_phase`·`next_role`과 함께 설정한다. `status: paused`는 rate-limit 훅·에러·일시정지만 설정한다.
3. `status`가 `paused`면 `pause_reason`은 `rate_limit`·`manual_action`·`error` 중 하나여야 한다(빈 값 불가).
4. 일시정지 후 `status`를 `running`으로 되돌릴 때 `resume_attempts`를 증가시켜야 한다.
5. `current_round`는 contract가 AGREED될 때 1로 시작하고, evaluator가 FAIL을 반환할 때마다(새 generator 라운드 시작 시) 증가한다.
6. `current_round`가 `max_rounds`를 초과하면 evaluator는 `max_rounds` 이벤트를 트리거해 강제 판정을 쓰고,
   이후 PASS 경로와 동일하게 — `auto_deploy: true`(규칙 10)가 아니면 배포 전 사람 검수를 위해 일시정지 — 진행한다.
7. `completed` 상태는 마지막 phase(`retro`)가 정상 종료된 후에만 설정된다. (kit에서는 evaluator PASS + 사람 검수가 Phase A의 종착점.)
8. `pause_reason`은 rate-limit 훅·에러 경로·또는 의도적으로 `manual_action`으로 일시정지하는 forward-flow
   스킬(evaluator의 QA 후 검수 게이트)이 설정한다. `flame-harness-resume`이 `status`를 `running`으로
   되돌릴 때 `""`로 클리어한다. 일시정지하지 않는 forward-flow 스킬은 `pause_reason`을 건드리지 않는다.
9. `config.md`의 `skip_admob: true`면 evaluator의 PASS는 사람 검수 후 반복 루프/`ship-build`로 안내한다.
10. 기본적으로 PASS는 배포 전 사람 검수를 위해 일시정지한다: evaluator가 `status: paused`,
    `pause_reason: manual_action`을 설정. 사용자가 빌드된 게임을 플레이/승인한 뒤 `--resume` 또는 다음
    단계(반복 루프/`ship-*`)를 수동 호출한다. `auto_deploy: true`면 일시정지 없이 진행한다.
