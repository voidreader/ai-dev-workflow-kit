# flame-harness & ship-* 사용법

`flutter-flame-harness`에서 이식한 **Flame 게임 전용** 워크플로우의 상세 사용 가이드다.
아이디어 → 검증된 프로토타입 → 기능 반복 → 스토어 출시까지의 전 과정을 다룬다.

> 이 문서는 **사용법** 문서다. 각 스킬의 내부 동작·스키마는 해당 `SKILL.md`와 부트스트랩으로
> 생성되는 `docs/harness/protocol.md`(SSOT)를 참조한다. kit 전체 규칙은 저장소 루트의
> [`README.md`](../README.md)·[`CLAUDE.md`](../CLAUDE.md) 참조.

---

## 0. 전체 그림 — 3단계

```
[1단계 · 프로토타입]            [2단계 · 기능 반복]                 [3단계 · 출시]
flame-harness-* (상태머신 자동)  plan-writer → spec-pipeline →       ship-* (각자 독립 호출)
아이디어→플레이가능한 게임        implement-* → finalize-*           admob→build→screenshot→submit→retro
        │                              ▲   프로토타입을 진짜             │
        └─ evaluator PASS ─ 사람 검수 ─┴─ 게임으로 키운다 ──────────────┘ 출시 준비되면
```

- **1단계**는 kit에서 **유일하게 중앙 상태머신(`docs/harness/state.md`)으로 자동 진행**한다.
  `flame-harness` 오케스트레이터가 `next_role`을 읽어 다음 스킬을 디스패치한다.
- **2단계**는 kit의 기존 반복 루프다. 수동 호출하며, 프로토타입에 기능을 더해 완성도를 높인다.
- **3단계**는 `ship-*` 5개 스킬을 **필요할 때 각각 독립 호출**한다. harness가 만든 게임뿐 아니라
  **임의의 Flutter 앱**에도 쓸 수 있다(경로·자격증명을 인자로 받음).

---

## 1. 설치 & 사전 준비

### 1.1 kit 설치

대상 프로젝트(또는 빈 작업 디렉토리)에 flutter 스킬·에이전트·훅을 설치한다.

```bash
# Claude 레이아웃(.claude/)
scripts/install-flutter.sh <대상-경로>

# Codex 레이아웃(.agents/, .codex/)
scripts/install-flutter.sh --codex <대상-경로>

# 무엇이 복사될지 미리보기 (변경 없음)
scripts/install-flutter.sh --dry-run <대상-경로>
```

복사되는 것: `common/skills` + `flutter/skills` (동봉 `protocol.md`·`game-gotchas.md`·각 스킬
`templates/` 포함) + 에이전트 + `flame-rate-limit` 훅 스크립트.

> **1단계는 새 프로젝트를 직접 생성**하므로, 빈 작업 디렉토리에서 시작해도 된다. 이미 있는
> Flutter 앱에 `ship-*`만 쓰려면 그 앱 디렉토리(또는 그 부모)에 설치하면 된다.

### 1.2 rate-limit 훅 켜기 (1단계 권장)

긴 generator↔evaluator 루프가 rate limit(429)에 걸려도 상태가 보존되도록 `Stop` 훅을 켠다.

- `flutter/hooks/flame-rate-limit/install.claude.json`(또는 `install.codex.json`)의 `hooks`
  블록을 대상 프로젝트 설정(`.claude/settings.json` 등)에 병합한다.
- 설치 스크립트가 훅 스크립트는 복사해 두며, 병합 안내를 출력한다.

### 1.3 외부 도구 (단계별로 필요할 때)

| 도구 | 필요 단계 | 비고 |
|---|---|---|
| Flutter SDK | 전체 | `flutter` / `dart` |
| iOS 시뮬레이터 · Android 에뮬레이터 | 1단계(evaluator), 3단계(screenshot) | 스크린샷은 iOS 6.7" + Android phone 규격 |
| fastlane (Ruby gem) | 3단계 build/submit | 서명·업로드 레인 |
| ImageMagick / ffmpeg | 1단계(generator 에셋 합성) | 코드 합성 오디오/아이콘 |
| App Store Connect API 키(.p8), Android keystore(.jks), `play-store-key.json` | 3단계 | §4.1 자격증명 참조 |

---

## 2. 1단계 — 프로토타입 (flame-harness Phase A)

### 2.1 실행

```
/flame-harness "<게임 아이디어>" [옵션]
/flame-harness            # 아이디어 없이 → AI가 시장 조사 후 컨셉 추천
```

진입점은 `flame-harness` 오케스트레이터다. 부트스트랩에서:
1. 작업 디렉토리에 `docs/harness/` 생성, `config.md`·`state.md` 작성.
2. 동봉된 `protocol.md`·`game-gotchas.md`를 `docs/harness/`로 복사.
3. 자격증명 디렉토리(`credentials_dir`)를 환경변수 `FLAME_CREDENTIALS_DIR` 또는 입력으로 설정.
4. 게임 생성 경로(`<project_root>/<app_slug>`)를 정하고 파이프라인을 디스패치.

### 2.2 옵션 (플래그 → config 매핑)

| 플래그 | config | 기본값 | 의미 |
|---|---|---|---|
| `--strict` | `strict_mode: true` | `false` | QA를 엄격 모드(품질 점수 + 엣지케이스 스윕)로 |
| `--rounds N` | `max_rounds: N` | `3` | generator↔evaluator 최대 라운드 |
| `--skip-research` | `skip_research: true` | `false` | 시장 조사 생략(아이디어 필수). 클론 체크·스펙 작성은 수행 |
| `--skip-admob` | `skip_admob: true` | `false` | 광고 통합 단계 생략 |
| `--auto-idea` | `auto_idea: true` | `false` | research가 묻지 않고 최적 컨셉 자동 선택 |
| `--auto-deploy` | `auto_deploy: true` | `false` | QA PASS 후 사람 검수 일시정지를 생략 |
| `--resume` | — | — | 일시정지된 파이프라인 재개(아래 2.5) |

> 가드: `--skip-research`인데 아이디어도 없으면 중단된다(빌드할 게 없음).

### 2.3 파이프라인 단계 (자동 진행)

```
research → plan → design → contract → generator ↔ evaluator → (PASS) 사람 검수
```

| 단계 | 스킬 | 산출물 |
|---|---|---|
| 시장조사·컨셉선택 | flame-harness-research | `docs/harness/specs/<날짜>-research.md` |
| PRD·식별자 할당 | flame-harness-plan | `docs/harness/plans/<날짜>-prd.md`, config(app_name/slug/bundle_id) |
| 디자인 토큰·에셋 계획 | flame-harness-design | `docs/harness/plans/<날짜>-design.md` |
| 완성 기준 협상 | flame-harness-contract | `docs/harness/contract.md` (`## Status: AGREED`) |
| 3단계 게임 빌드 | flame-harness-generator | 게임 프로젝트 + `handoff/round-N-gen.md` |
| 회의적 QA | flame-harness-evaluator | `feedback/round-N-qa.md`, PASS/FAIL |

- **generator**는 `5a 스캐폴드+코어루프 → 5b 시스템+컴포넌트 → 5c UI+콘텐츠+폴리시` 3단계로
  빌드하며, 각 단계 끝에 HARD GATE(`flutter analyze` 0 + `flutter test` 통과)를 통과해야 다음으로.
- **evaluator**는 "코드 실행 → 앱 확인 → 판정" 철칙. FAIL이면 generator로 되돌아가 다음 라운드
  (`current_round+1`). `max_rounds` 도달 시 강제 판정.

### 2.4 상태 확인

```
/flame-harness-status      # phase / round / QA 점수 / 최근 이벤트 (읽기 전용)
```

### 2.5 일시정지 & 재개

rate limit(훅) · 사용자 확인 필요 · 에러 시 `state.md`가 `paused`가 된다. 재개:

```
/flame-harness-resume      # 또는 /flame-harness --resume
```

`pause_reason`에 따라 분기한다(rate_limit 대기 / manual_action 확인 / error 보고).

### 2.6 1단계 종료점

evaluator PASS → 기본적으로 **사람 검수를 위해 일시정지**(`auto_deploy`가 아니면). 사용자가
빌드된 게임을 직접 플레이·승인한 뒤, 다음 둘 중 하나로 진행한다:
- **2단계** 반복 루프로 기능을 키운다, 또는
- 출시 준비가 됐으면 **3단계** `ship-*`를 호출한다.

---

## 3. 2단계 — 기능 반복 (kit 반복 루프)

프로토타입을 "진짜 게임"으로 키우는 단계. kit의 기존 flutter 워크플로우를 그대로 쓴다.
(harness가 PRD·contract를 남겨 두므로, 새 기능 기획의 참고 입력으로 활용한다.)

```
/plan-writer                         → 기획서 (Docs/plans/)
/spec-pipeline @기획서                → 명세 작성 + 검증 (spec-writer ↔ verify-spec, 최대 3회)
/implement-spec @명세서               → 올인원 구현 (소규모)
  또는 /implement-agent @명세서        → 서브에이전트 파이프라인 (대규모)
/finalize-feature                    → 마무리·문서·커밋 (소규모는 /finalize-minor-task)
```

> 1단계의 `docs/harness/`와 2단계의 `Docs/`는 공존한다. 반복 루프는 `Docs/` 규약을 쓴다.

---

## 4. 3단계 — 출시 (ship-*, 독립 호출)

각 스킬을 순서대로(또는 필요한 것만) **독립 호출**한다. 권장 순서:

```
ship-admob → ship-build → ship-screenshot → ship-submit → ship-retro
```

> **경로 규칙:** 모든 `ship-*` 스킬에서 `project_root`는 **Flutter 앱 루트 디렉토리 자체**
> (`pubspec.yaml`·`ios/`·`android/`가 있는 곳)다. 미지정 시 현재 작업 디렉토리.
> 1단계 직후라면 generator가 만든 게임은 `<작업 디렉토리>/<app_slug>`에 있으므로,
> `project_root=<작업 디렉토리>/<app_slug>`로 그 앱 디렉토리를 가리키면 된다.

### 4.1 자격증명 준비 (build/submit 전 1회)

`credentials_dir`에 모아 둔다. 스킬·템플릿에는 실제 값이 없고 플레이스홀더만 있다 — 값은 인자나
이 디렉토리에서 읽는다.

| 파일 / 값 | 용도 |
|---|---|
| `AuthKey_<asc_key_id>.p8` | App Store Connect API 키 |
| `<keystore>.jks` (+ key alias) | Android 업로드 키 |
| `play-store-key.json` | Google Play Publisher 서비스 계정 |
| apple_id / team_id / asc_key_id / asc_issuer_id | iOS 서명·업로드 |
| developer 블록(회사/이름/이메일/전화/privacy/homepage/copyright) | 스토어 리스팅·심사 연락처 |

> **전제:** App Store Connect와 Google Play Console에 **앱 레코드가 미리 생성**되어 있어야 한다
> (API로 자동 생성 불가). AdMob 앱/광고 유닛도 콘솔에서 수동 생성.

### 4.2 ship-admob — 광고 통합

```
/ship-admob app_slug=<슬러그> bundle_id=<번들ID> project_root=<앱 루트>
```

게임 루프 분석 → 리워드 광고 배치 전략 제안 → **AdMob 콘솔에서 수동 유닛 생성 안내** →
`google_mobile_ads`/iOS ATT/UMP consent 코드 주입(`lib/admob/*`, pubspec, Info.plist,
AndroidManifest, build.gradle.kts). 콘솔 작업 후 다시 호출하면 ID를 채워 마무리한다.

### 4.3 ship-build — 서명 빌드 & 업로드

```
/ship-build app_slug=<슬러그> bundle_id=<번들ID> app_name="<표시명>" \
  credentials_dir=<자격증명 디렉토리> project_root=<앱 루트> \
  apple_id=<애플계정> ios.team_id=<팀ID> ios.asc_key_id=<키ID> ios.asc_issuer_id=<issuer> \
  android.key_alias=<별칭>
```

fastlane 템플릿 치환(`__APP_ID__`/`__TEAM_ID__`/`__ASC_KEY_ID__` 등) → 서명 IPA를 TestFlight,
AAB를 Play internal 트랙에 업로드. 자격증명 플레이스홀더는 절대 하드코딩하지 않고 인자/
`credentials_dir`에서 채운다.

### 4.4 ship-screenshot — 스토어 스크린샷 & 메타데이터

```
/ship-screenshot app_slug=<슬러그> bundle_id=<번들ID> project_root=<앱 루트> \
  default_language=<기본언어> [extra_locales=en] [ios_device_id=...] [android_device_id=...]
```

`flutter drive`로 로케일별 캡처 → ASO 메타데이터 채움 → fastlane 업로드(iOS screenshots /
Android images). 기기 ID 미지정 시 `flutter devices`에서 규격 모델을 고른다. 앱별 화면 캡처
부분은 `templates/screenshots_test.dart.template` 골격을 채워 구현한다.

### 4.5 ship-submit — 메타데이터 업로드 & 제출 안내

```
/ship-submit app_slug=<슬러그> bundle_id=<번들ID> project_root=<앱 루트> \
  default_language=<기본언어> \
  developer.company=<회사> developer.first_name=<이름> developer.last_name=<성> \
  developer.email=<이메일> developer.phone=<전화> developer.privacy=<URL> \
  developer.homepage=<URL> developer.copyright="<문구>"
```

스토어 텍스트 메타데이터 업로드(fastlane deliver/supply) + Android 연락처(Publisher API ruby
스크립트) → API로 불가능한 **최종 제출(iOS "Submit for Review" / Android "Promote to
Production")과 심사 설문은 콘솔 수동 단계로 안내**한다.

### 4.6 ship-retro — 릴리스 회고

```
/ship-retro [project_root] [--changelog <path>] [--build-log <path>] [--out <path>]
```

`git log`·CHANGELOG·빌드 산출물·ship-* 결과를 근거로 **범용 릴리스 회고**(Keep/Problem/Try +
릴리스 체크리스트 점검)를 작성한다. 기본 출력 `<project_root>/Docs/retro.md`. harness 전용
산출물에 의존하지 않으므로 임의의 Flutter 릴리스에 쓸 수 있다.

---

## 5. 산출물 / 디렉토리 구조

```
<작업 디렉토리>/
├─ docs/harness/                 # 1단계 상태머신 산출물 (부트스트랩이 생성)
│  ├─ protocol.md, game-gotchas.md   # 동봉 SSOT 복사본
│  ├─ config.md, state.md            # 설정 / 실행 상태
│  ├─ specs/<날짜>-research.md
│  ├─ plans/<날짜>-prd.md, <날짜>-design.md
│  ├─ contract.md
│  ├─ handoff/round-N-gen.md, feedback/round-N-qa.md
│  └─ pipeline-log.md, build-log.md
└─ <project_root>/<app_slug>/    # generator가 생성한 Flutter 게임 프로젝트
   └─ (5a.1에서 docs/harness 를 이 안으로 이동)
```

2단계는 `Docs/`(plans/, spec/, changelog-fragments/, Archive/), 3단계는 게임 프로젝트의
`ios/fastlane`·`android/fastlane`·`store-assets/` 등에 산출물을 만든다.

---

## 6. 검증 스크립트 (kit 저장소)

```bash
bash scripts/validate-fastlane.sh   # ship-build fastlane 템플릿 ruby 문법
bash scripts/test-hook.sh           # flame-rate-limit 훅 동작
```

---

## 7. 자주 쓰는 명령 요약

```
# 1단계 (프로토타입)
/flame-harness "퍼즐 게임 아이디어"
/flame-harness "..." --strict --rounds 4
/flame-harness --auto-idea          # 아이디어까지 AI가 선택
/flame-harness-status
/flame-harness-resume

# 2단계 (기능 반복)
/plan-writer → /spec-pipeline @기획서 → /implement-agent @명세서 → /finalize-feature

# 3단계 (출시)
/ship-admob ...  →  /ship-build ...  →  /ship-screenshot ...  →  /ship-submit ...  →  /ship-retro
```

---

## 8. 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| `--skip-research`인데 중단됨 | 아이디어가 없음 → 아이디어를 함께 전달 |
| rate limit으로 멈춤 | `flame-rate-limit` 훅이 `paused` 표시 → `/flame-harness-resume` |
| evaluator가 계속 FAIL | `feedback/round-N-qa.md`의 Failed Criteria 확인. `--rounds`로 한도 조정 |
| fastlane 업로드 실패 | 스토어 앱 레코드 사전 생성 여부, `credentials_dir` 경로/키 확인 |
| bundle id 불일치 거부 | iOS `PRODUCT_BUNDLE_IDENTIFIER` == Android `applicationId` == `bundle_id` (소문자 `[a-z0-9.]`) |
| 스크린샷 캡처 실패 | 규격 기기(iOS 6.7"/Android phone) 부팅 여부, `--dart-define=screenshots=true` |
| ATT 프롬프트 미표시(2.1 거부) | `game-gotchas.md`의 ATT 패턴(resumed 대기→settle→notDetermined) 준수 |

자세한 함정·해결책은 부트스트랩으로 생성된 `docs/harness/game-gotchas.md` 참조.
