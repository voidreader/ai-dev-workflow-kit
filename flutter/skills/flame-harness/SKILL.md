---
name: flame-harness
description: 오케스트레이터 — Flutter/Flame 게임 파이프라인(아이디어→플레이 가능한 게임)을 부트스트랩하고 각 Phase 스킬을 디스패치한다. flame-harness 실행을 시작하거나 재개할 때 사용한다.
argument-hint: "[game idea] [--strict] [--rounds N] [--skip-research] [--skip-admob] [--auto-idea] [--auto-deploy] [--resume]"
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# flame-harness 오케스트레이터

이 스킬은 아이디어에서 플레이 가능한 게임까지 Flutter/Flame 게임 파이프라인 전체를 부트스트랩하고 구동한다.
모든 파일 스키마(`config.md`, `state.md`, `contract.md`, 로그 테이블)와 phase 전이 테이블은
`docs/harness/protocol.md`에 정의되어 있다 — 이 문서를 단일 소스 오브 트루스(SSOT)로 참조한다.
스키마를 여기서 재정의하지 않는다.

---

## 인자 파싱

아무것도 하기 전에 호출 인자를 파싱한다.

| 인자 | `config.md` 키 | 기본값 |
|---|---|---|
| `[game idea]` | `app_idea` | 선택 — 생략 시 research가 아이디어를 직접 생성·추천 |
| `--strict` | `strict_mode: true` | `false` |
| `--rounds N` | `max_rounds: N` | `3` |
| `--skip-research` | `skip_research: true` | `false` |
| `--skip-admob` | `skip_admob: true` | `false` |
| `--auto-idea` | `auto_idea: true` | `false` |
| `--auto-deploy` | `auto_deploy: true` | `false` |
| `--resume` | (resume 핸들러에 위임; Resume 섹션 참조) | — |

**가드:** `--skip-research`가 설정되어 있고 아이디어도 없으면 즉시 중단한다:
`flame-harness: --skip-research는 게임 아이디어가 필요합니다 (research도 없고 아이디어도 없으면 빌드할 것이 없습니다).`

키-파일 매핑은 `docs/harness/protocol.md` Section 1의 `config.md` 스키마를 따른다.

- `--strict` → `config.md`에 `strict_mode: true` 기록
- `--rounds N` → `config.md`에 `max_rounds: N` 기록
- `--skip-research` → `config.md`에 `skip_research: true` 기록. 첫 실행 시 `next_role`은 여전히 `research`(NOT `plan`): research 스킬이 `skip_research`를 인식해 시장 조사·아이디어 생성을 건너뛰되, 제공된 아이디어에 대한 App Store 4.3 클론 회피 검사는 반드시 수행하고 research 스펙을 기록한다 — 클론 검사가 묵시적으로 건너뛰어지는 일이 없도록 한다.
- `--skip-admob` → `config.md`에 `skip_admob: true` 기록
- `--auto-idea` → `config.md`에 `auto_idea: true` 기록. research 스킬이 생성한 개념들을 자동 채점해 사용자 확인 없이 최우수안을 선택한다. `--skip-research`와 함께 쓰면 효과 없음(아이디어를 그대로 사용하므로 선택할 것이 없다).
- `--auto-deploy` → `config.md`에 `auto_deploy: true` 기록. QA 후 사람 검수 pause를 건너뛴다: QA PASS 시 사용자가 직접 게임을 확인·승인하는 단계 없이 deploy(admob→build→screenshot→submit)까지 계속 진행한다. 기본값 `false` — 기본적으로 harness는 QA 후 일시 정지해 사용자가 빌드된 게임을 확인하고 나서 deploy를 승인한다. (`--auto-idea --auto-deploy` 조합 = 완전 핸즈오프 아이디어→deploy.)
- `--resume` → 부트스트랩을 완전히 건너뛰고 `flame-harness-resume`에 바로 위임 (Resume 섹션 참조)

---

## 부트스트랩 (첫 실행)

`docs/harness/state.md`가 아직 존재하지 않을 때만 부트스트랩을 실행한다.

### 1. 디렉토리 트리 생성

```
docs/harness/
docs/harness/handoff/
docs/harness/feedback/
docs/harness/specs/
docs/harness/plans/
```

### 2. 프로토콜 문서 복사

이 스킬 디렉토리(`skills/flame-harness/`)에 동봉된 `protocol.md`와 `game-gotchas.md`를
대상 프로젝트의 harness 문서 디렉토리로 복사한다:

```
skills/flame-harness/protocol.md   →  docs/harness/protocol.md
skills/flame-harness/game-gotchas.md  →  docs/harness/game-gotchas.md
```

이 두 파일은 모든 하위 스킬(flame-harness-*)이 SSOT로 인용하는 문서다. 복사 후에는
`docs/harness/protocol.md`와 `docs/harness/game-gotchas.md`를 참조하면 된다.

### 3. 자격증명 디렉토리 결정 (`credentials_dir`)

`credentials_dir`를 다음 우선순위로 결정한다:

1. 환경변수 `FLAME_CREDENTIALS_DIR`이 설정되어 있으면 그 값을 사용한다.
2. 그렇지 않으면 사용자에게 자격증명 디렉토리 경로를 묻는다
   (`store-metadata.md`가 있는 디렉토리 — 예: `~/credentials`).

결정된 `credentials_dir`에서 `<credentials_dir>/store-metadata.md`를 읽어
`developer`, `ios`, `android` 자격증명 블록을 추출한다.
**자격증명 값을 코드에 하드코딩하지 않는다**; 항상 `credentials_dir`에서 읽는다.

### 4. 프로젝트 루트 결정 (`project_root`)

게임 프로젝트는 `<project_root>/<app_slug>` 경로에 생성된다.

- `project_root` 기본값 = 현재 작업 디렉토리
- 사용자가 프로젝트를 생성할 디렉토리를 별도로 지정한 경우 그 값을 사용한다
  (예: `--project-root ~/projects`).

`project_root`를 결정한 후 `config.md`에 기록한다. 이후 모든 하위 스킬은
`config.md`의 `project_root`와 `app_slug`를 조합해 게임 프로젝트 경로를 참조한다.

### 5. `docs/harness/config.md` 작성

`docs/harness/protocol.md` Section 1의 전체 스키마에 따라 `docs/harness/config.md`를 작성한다.

게임 고유 키는 파싱된 인자로 채운다:

- `default_language` — 사용자가 대화하는 언어를 감지한다 (한국어 요청 → `ko`, 영어 요청 → `en`); 불분명하면 `en`. 전체 파이프라인(PRD, 카피, l10n 기본 언어)이 이 언어로 작성된다.
- `app_idea` — 위치 인자에서; 인자가 없으면 `app_idea: ""`로 기록 (빈 값도 유효 — research가 개념을 생성·추천한다). 아이디어가 없다고 중단하지 않는다.
- `app_name` — 아이디어에서 짧은 표시 이름을 유도한다 (불명확하면 사용자에게 확인); 아이디어가 없으면 `app_name: ""`로 기록 — plan phase가 research 이후 이름을 확정한다.
- `app_slug` — `app_name`의 kebab-case; `app_name`이 비어 있으면 `app_slug: ""`로 기록.
- `bundle_id` — `com.<company>.<id>` 형태. `<company>`는 `config.developer.company`, `<id>`는 `app_slug`에서 하이픈·언더스코어를 제거한 값 (bundle-id 세그먼트는 `[a-z0-9]+` 이어야 한다; 하이픈·언더스코어는 서명을 깨뜨린다). `app_slug`가 비어 있으면 빈 값.
- `project_root` — 위 Step 4에서 결정한 값.
- `strict_mode`, `max_rounds`, `skip_research`, `skip_admob`, `auto_idea`, `auto_deploy` — 플래그에서 (위 표의 기본값 적용)
- `developer`, `ios`, `android` — `<credentials_dir>/store-metadata.md`에서 읽은 값
- `credentials_dir` — Step 3에서 결정한 값

### 6. `docs/harness/state.md` 작성

`docs/harness/protocol.md` §2의 스키마에 따라 `state.md`를 작성한다.
초기값: `status: running`, `current_phase: (init)`, `current_round: 1`,
`next_role: research` (항상 `research`로 시작 — research 스킬이 `skip_research`를 내부적으로
처리하며 클론 검사와 스펙 기록은 항상 수행한다),
`pause_reason: ""`, `resume_attempts: 0`,
`created_at`/`updated_at`은 현재 ISO-8601 UTC 타임스탬프.

### 7. `docs/harness/pipeline-log.md`에 INIT 행 추가

`pipeline-log.md`가 없으면 생성하고 아래 행을 추가한다:

```
| <ISO-8601 UTC 현재> | start | bootstrap | config.md written |
```

`pipeline-log.md` 스키마는 `docs/harness/protocol.md` Section 6을 따른다.

---

## 디스패치 루프

부트스트랩 완료 후(또는 `--resume` 없이 재개할 때) 디스패치 루프에 진입한다.

### `next_role` 읽기

`docs/harness/state.md`를 읽어 `next_role`과 `status`를 추출한다.

- `status: completed` — 완료 요약을 출력하고 종료한다.
- `status: paused` — `pause_reason`과 대기 중인 수동 작업을 출력한 뒤,
  사용자에게 `--resume`으로 재실행하도록 안내한다. 자동으로 계속 진행하지 않는다.

### 디스패치

`next_role`이 알려진 집합에 속하면 해당 phase 스킬을 호출한다:

```
Skill("flame-harness-<next_role>")
```

유효한 `next_role` 값과 스킬 매핑 (`docs/harness/protocol.md` Section 7 전이 테이블 참조):

| next_role | 호출 스킬 |
|---|---|
| `research` | `flame-harness-research` |
| `plan` | `flame-harness-plan` |
| `design` | `flame-harness-design` |
| `contract` | `flame-harness-contract` |
| `generator` | `flame-harness-generator` |
| `evaluator` | `flame-harness-evaluator` |
| `admob` | `flame-harness-admob` |
| `build` | `flame-harness-build` |
| `screenshot` | `flame-harness-screenshot` |
| `submit` | `flame-harness-submit` |
| `retro` | `flame-harness-retro` |

각 phase 스킬은 반환 전에 `state.md`를 업데이트(다음 phase로 `next_role` 설정 포함)할
책임이 있으며, `docs/harness/protocol.md` Section 7의 전이 규칙을 따른다.

각 스킬이 반환된 후, `state.md`를 다시 읽어 디스패치 전과 비교해 `updated_at`이
변경되었거나 `next_role`이 진행되었는지 검증한다. 둘 다 변경되지 않았으면 즉시 중단한다:
`"orchestrator: phase 스킬 '<role>'이 state.md를 업데이트하지 않고 반환됨 — 재디스패치 루프를 방지하기 위해 중단합니다."`

`status: paused`가 되면(예: `submit`이 `pause_reason: manual_action`으로 설정) `state.md`의
대기 중인 수동 작업을 출력하고 사용자에게 완료 후 `--resume`으로 재실행하도록 안내한다.
자동으로 계속 진행하지 않는다.

이후 디스패치 검사를 반복한다. 다음 조건이 충족될 때까지 계속한다:
- `status: completed` (`retro`가 설정 — 완료 요약 출력 후 종료)
- `status: paused` (pause_reason 출력 후 `--resume`으로 재실행 안내, 종료)

---

## 재개 (Resume)

`--resume`이 인자로 전달된 경우, 먼저 `docs/harness/state.md`가 존재하는지 확인한다.
존재하지 않으면 중단한다:
`"재개할 것이 없습니다 — state.md를 찾을 수 없습니다. --resume 없이 실행해 새 파이프라인을 시작하세요."`

그 외의 경우, 부트스트랩과 디스패치 로직을 모두 건너뛰고 resume 스킬에 바로 위임한다:

```
Skill("flame-harness-resume")
```

`flame-harness-resume`은 `state.md`를 읽고, `resume_attempts`를 증가시키고,
`status: running`을 복원한 뒤 디스패치 루프에 재진입할 책임이 있다.

resume 스킬에 위임하기 전에 `state.md`를 읽거나 수정하지 않는다.

---

## 오류 처리

- 첫 실행이 아닌데 `docs/harness/config.md`가 없으면 명확한 오류 메시지와 함께 중단한다.
- 호출된 phase 스킬이 오류로 종료되거나 `pause_reason: error`로 `status: paused`를 설정하면 루프를 멈추고 사용자에게 실패를 보고한다.
- `next_role`이 알려진 집합(research, plan, design, contract, generator, evaluator, admob, build, screenshot, submit, retro)에 없는 값을 담고 있으면, "알 수 없는 next_role" 오류와 함께 중단한다 — 사용자가 `state.md`를 직접 확인할 수 있도록 한다.

---

## 이후 단계 접합 안내

evaluator가 PASS를 반환하면 파이프라인은 자동으로 다음 phase(admob 또는 build)로 진행하거나,
`auto_deploy: false`(기본값)인 경우 사람 검수를 위해 일시 정지한다.

**사람 검수 후 두 가지 경로가 있다:**

### (a) 기능 확장 — kit 반복 루프

게임에 새 기능을 추가하거나 스펙을 개선하려면 다음 스킬들을 순서대로 호출한다:

```
plan-writer      → 기획 문서 작성
spec-pipeline    → 명세서 생성
implement-*      → 구현 (implement-agent / implement-spec)
finalize-feature → 기능 완료·정리
finalize-minor-task → 소규모 작업 완료
```

이 루프를 반복해 게임을 성숙시킨다. 각 기능 사이클이 완료될 때마다 evaluator를 다시 호출해
품질 게이트를 통과하는지 검증하는 것을 권장한다.

### (b) 출시 준비 — ship-* 스킬 독립 호출

게임이 출시 준비가 되면 다음 스킬들을 필요에 따라 **독립적으로** 호출한다 (harness
파이프라인 컨텍스트 없이 단독 실행 가능):

| 스킬 | 역할 |
|---|---|
| `ship-admob` | AdMob 광고 유닛 설정·통합 |
| `ship-build` | iOS/Android 릴리스 빌드 |
| `ship-screenshot` | 스토어 스크린샷 생성 |
| `ship-submit` | App Store/Play Store 제출 |
| `ship-retro` | 출시 회고·메트릭 기록 |

각 ship-* 스킬은 `app_slug`, `bundle_id`, `credentials_dir`, `project_root`, developer 정보 등을
**직접 인자**로 받아 동작하므로, harness 상태머신이 없는 임의의 Flutter 프로젝트에서도 단독으로
사용할 수 있다.
