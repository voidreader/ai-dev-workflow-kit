---
name: flame-harness-plan
description: Phase 2 — 프로젝트의 default_language로 게임 PRD를 작성하고(코어 루프, 메카닉, 콘텐츠 지표, 승리/패배 조건, 스코프 가드), lib/ 디렉터리 구조를 매핑하고, 앱 이름/슬러그/번들 ID를 할당한다.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

# flame-harness-plan

flutter-flame-harness 파이프라인의 Phase 2 스킬이다. 리서치 스펙과 `config.md`를 읽어
프로젝트의 `default_language`로 종합적인 게임 PRD를 작성하고, `lib/` 디렉터리 구조를 매핑하고,
앱 식별자(`app_name`, `app_slug`, `bundle_id`)를 할당하고, 파이프라인 상태를 `design`으로 전진한다.

모든 파일 스키마(`config.md`, `state.md`, `pipeline-log.md`)는
`docs/harness/protocol.md`에 정의되어 있다 — 해당 문서를 단일 진실 공급원으로 참조한다.
스키마를 여기서 재정의하지 않는다.

---

## 입력 (Input)

### 1. `docs/harness/config.md` 읽기

다음 키를 추출한다:

| 키 | 용도 |
|---|---|
| `app_idea` | 리서치 단계가 작성한 정제된 컨셉 태그라인 |
| `app_name` | 표시 이름 (비어 있으면 여기서 설정) |
| `app_slug` | 케밥 케이스 식별자 (비어 있으면 여기서 도출) |
| `bundle_id` | 앱 번들 ID (비어 있으면 여기서 설정) |
| `default_language` | 오케스트레이터가 설정한 사용자 대화 언어 — PRD와 모든 텍스트를 이 언어로 작성 |

`config.md`가 존재하지 않으면 다음 메시지로 중단한다:
`flame-harness-plan: docs/harness/config.md not found — 먼저 오케스트레이터를 실행해 부트스트랩하세요.`

### 2. 최신 리서치 스펙 읽기

`docs/harness/specs/*-research.md` 패턴과 일치하는 가장 최근 파일을 찾는다 (파일명 내림차순 정렬 후 첫 번째 선택). 스펙 파일이 없으면 다음 메시지로 중단한다:
`flame-harness-plan: docs/harness/specs/에 리서치 스펙이 없습니다 — 먼저 flame-harness-research를 실행하세요.`

스펙에서 추출할 항목:

- **선정 컨셉** — 제목, 태그라인, 핵심 메카닉, 차별점
- **수익화 훅** — AdMob 연동 지점 (전면 광고 / 리워드 광고 / 배너)
- **클론 회피 판정** — 진행 전 SAFE 여부 확인

---

## 식별자 할당 (Identity Assignment)

PRD에서 최종 값을 참조할 수 있도록, PRD 작성 **전에** 앱 식별자를 도출하고 할당한다.

### app_name

리서치 스펙의 작업 제목을 표시 이름으로 사용한다. 각 단어의 첫 글자를 대문자로 표기한다.
예: `"space hop"` → `"Space Hop"`.

### app_slug

`app_slug`는 `app_name`에서 도출하는 **케밥 케이스** 식별자이다:

1. 표시 이름을 소문자로 변환한다.
2. 공백 및 특수문자를 하이픈으로 대체한다.
3. 앞뒤 하이픈을 제거하고 연속 하이픈을 하나로 축약한다.
4. 예: `"Space Hop!"` → `"space-hop"`.

슬러그는 번들 ID의 마지막 세그먼트이자 CI/CD 경로의 디렉터리 이름으로 사용된다.
언더스코어는 사용하지 않는다 — 케밥 케이스만 허용한다.

### bundle_id

번들 ID는 앱 식별자의 일부이며 **이 단계에서 사전에** 결정된다 (PRD에 명시되어 사용자가 확인). 형식 — 역방향 DNS 표기 **`com.<company>.<appname>`**:
- `<company>` = `config.md`의 `developer.company` 값.
- `<appname>` = `app_slug`에서 **하이픈/언더스코어를 모두 제거하고 소문자로** 변환한 값 (각 세그먼트는 `[a-z0-9]+`만 허용 — 하이픈/언더스코어/대문자는 **무효**이며 iOS/Android 서명을 깨뜨린다).

결과: `bundle_id` = `com.<company>.<appname>`. 예:
- `app_slug: space-hop` → **`com.<company>.spacehop`**
- `app_slug: swing-line` → **`com.<company>.swingline`** (NOT `com.<company>.swing-line`)

PRD 식별자 섹션에 선택된 `bundle_id`를 명시한다. iOS와 Android에서 바이트 동일해야 한다 (`docs/harness/protocol.md` §1).

### 화면 방향 (orientation)

컨셉을 바탕으로 게임의 **단일** 고정 방향을 결정하고 PRD에 기록한다:
`portrait` (기본값 — 대부분의 캐주얼/한손 게임) 또는 `landscape` (본질적으로 가로형 플레이: 횡스크롤 플랫포머, 트윈스틱, 가로형 레이서). 게임은 이 단일 방향으로 고정 출시된다 (제너레이터가 다른 방향을 네이티브로 제거 — 실행 중 회전 없음).

### `config.md` 업데이트

`Edit`을 사용하여 `config.md`에 식별자 키와 화면 방향을 업데이트한다:

```yaml
app_name: "<표시 이름>"
app_slug: "<kebab-case-slug>"
bundle_id: "com.<company>.<id>"   # <id> = app_slug에서 하이픈/언더스코어 제거
orientation: portrait              # 또는 "landscape"
```

타겟 편집만 수행한다 — 파일 전체를 재작성하지 않는다.

---

## PRD 콘텐츠 (PRD Content)

PRD를 `default_language`로 **전부** 작성한다 (사용자가 대화하는 언어). 제목과 본문을 해당 언어로 작성한다. 아래 템플릿은 한국어 프로젝트를 예시로 한국어 제목을 보여준다 — 프로젝트 언어가 한국어가 아닌 경우 제목을 `default_language`(예: 영어)로 번역한다. 예외 사항:
- 로컬 동일어가 없는 코드 식별자, 파일 경로, 클래스명, 기술 용어.
- 섹션 제목에는 현지화 제목 뒤에 영어 기술 용어를 괄호로 추가할 수 있다.

아래 구조를 그대로 사용한다. 새로운 Claude가 리서치 스펙만으로 모든 섹션을 채울 수 있어야 한다 — 추측은 허용하지 않는다.

### PRD 구조 (필수 섹션)

```markdown
# 게임 기획서 (PRD) — <app_name>

> **버전:** 1.0  
> **작성일:** <YYYY-MM-DD>  
> **작성자:** flame-harness-plan  
> **번들 ID:** com.<company>.<id> (slug에서 하이픈·언더스코어 제거)

---

## 1. 장르 및 컨셉 (Genre & Concept)

- **장르:** <예: 하이퍼캐주얼 러너 / 타워 디펜스 / 퍼즐>
- **한 줄 설명:** <리서치 스펙의 태그라인, default_language로 번역>
- **핵심 차별점:** <리서치 스펙의 차별점, default_language로>
- **대상 연령:** <target age group>

---

## 2. 코어 루프 (Core Loop)

플레이어가 10–30초마다 반복하는 핵심 행동을 단계별로 기술한다.

1. <단계 1>
2. <단계 2>
3. <단계 3>
   ...

---

## 3. 게임 메카닉 (Game Mechanics)

### 3.1 조작 방법 (Controls)

| 플랫폼 | 조작 | 결과 |
|---|---|---|
| iOS/Android | <탭 / 스와이프 / 홀드> | <동작> |

### 3.2 핵심 메카닉 (Core Mechanic)

<주요 메카닉을 2~4문장으로 기술>

### 3.3 보조 메카닉 (Secondary Mechanics)

<보조 메카닉 2~4개를 불릿 리스트로>

---

## 4. 콘텐츠 지표 (Content Metrics)

| 항목 | 목표값 |
|---|---|
| 레벨 수 | <number> |
| 적 종류 수 | <number> |
| 웨이브 수 (레벨당) | <number> |
| 스테이지 테마 수 | <number> |
| 아이템/파워업 종류 수 | <number> |

콘텐츠 수치는 MVP 기준이며, 업데이트를 통해 확장할 수 있다.

---

## 5. 진행 및 경제 (Progression & Economy)

### 5.1 진행 구조

<레벨/스테이지 잠금 해제 방식 — 선형, 월드맵, 무한 등>

### 5.2 점수 및 보상

- 기본 점수 단위: <예: 코인, 별, 포인트>
- 레벨 클리어 보상: <설명>
- 광고 시청 보상 (리워드 애드): <설명 — AdMob 리워드 광고와 매핑>

### 5.3 저장 및 영속성

- 로컬 저장: `SharedPreferences` (점수, 최고 기록, 설정)
- 클라우드 저장: 미포함 (스코프 외 — §8 참조)

---

## 6. 승리 및 패배 조건 (Win / Lose Conditions)

### 6.1 승리 조건

<레벨/세션에서 플레이어가 달성해야 할 것을 기술>

### 6.2 패배 조건

<게임 오버 상태를 유발하는 조건을 기술>

### 6.3 게임 오버 화면

게임 오버 화면은 다음을 표시한다:
- 최종 점수
- 최고 기록 (갱신 여부 표시)
- 재시작 버튼
- 메인 메뉴 버튼
- 광고 시청으로 부활 옵션 (선택, 리워드 애드)

---

## 7. App Store 컴플라이언스 체크리스트

| 항목 | 상태 |
|---|---|
| 앱 심사 지침 4.3 클론 회피 확인 | SAFE (리서치 스펙 참조) |
| 개인정보 처리방침 URL 포함 | 필요 (config.md `privacy` 필드) |
| 연령 등급 적합성 (4+) | 확인 필요 |
| AdMob 광고 레이블 표시 | 광고 시청 버튼에 레이블 명시 |
| 인앱구매 없음 (MVP) | 스코프 외 |
| 위치 정보 미사용 | 해당 없음 |
| 카메라/마이크 미사용 | 해당 없음 |

---

## 8. 스코프 가드 (Scope Guard)

다음 항목은 **MVP 스코프 외**이다. 계획, 설계, 구현 단계에서 이 항목들을 구현하지 않는다.
스코프 확장이 필요한 경우 PRD를 개정한 후 진행한다.

**스코프 외 항목:**

- 온라인 멀티플레이어 / 소셜 기능
- 클라우드 저장 / 계정 시스템 (Google Play Games, Game Center)
- 인앱구매 (IAP) 및 프리미엄 콘텐츠
- 푸시 알림
- 커스텀 캐릭터 / 스킨 시스템
- 맵 에디터 또는 사용자 생성 콘텐츠
- 다국어 지원 (한국어 + 영어 이외의 언어)
- 태블릿 전용 레이아웃
- 백엔드 서버 / API

---
```

---

## lib/ 구조 매핑 (lib/ Structure Map)

PRD에는 스코프 가드 바로 다음에 `lib/` 디렉터리 맵 섹션을 포함해야 한다. 이 맵은 설계 및 제너레이터 단계가 따를 권위 있는 디렉터리 구조이다.

아래 섹션을 PRD에 추가한다 (제목 번역 허용 — 경로는 정확해야 함):

```markdown
## 9. lib/ 디렉터리 구조

아래 구조는 design 및 generator 단계에서 그대로 따른다.

```
lib/
├── game/                    # FlameGame 서브클래스 및 게임 진입점
│   ├── components/          # Flame Component 클래스 (플레이어, 적, 장애물 등)
│   ├── systems/             # 게임 로직 시스템 (충돌, 스폰, 점수 등)
│   └── data/                # 레벨 데이터, 적 스탯, 게임 상수 (game_config.dart 포함)
├── screens/                 # Flutter 화면 (메인 메뉴, 게임 오버, 설정 등)
├── ui/                      # HUD 위젯, 오버레이, 공통 UI 컴포넌트
└── l10n/                    # 로컬라이제이션 ARB 파일 (ko.arb, en.arb)
```

> **규칙:** 게임 로직은 `game/` 아래에만 위치한다. Flutter 위젯은 `screens/` 또는 `ui/`에
> 위치한다. 매직 넘버는 `game/data/game_config.dart`에 집중한다 (`docs/harness/protocol.md` §4 참조).
```

---

## 출력 (Output)

### 1. PRD 작성

`docs/harness/plans/<YYYY-MM-DD>-prd.md`를 생성한다 (오늘 UTC 날짜 사용).

`docs/harness/plans/`가 존재하지 않으면 먼저 생성한다.

위 **PRD 콘텐츠** 섹션에서 정의한 구조를 사용하여, 리서치 스펙과 `config.md`에서 모든 섹션을 채워 `default_language`로 전체 PRD를 작성한다.

### 2. `config.md` 업데이트

위 **식별자 할당** 섹션에 설명된 대로 `Edit`을 통해 식별자 키(`app_name`, `app_slug`, `bundle_id`)를 적용한다.

### 3. `state.md` 업데이트

`docs/harness/protocol.md` §2의 스키마에 따라 `docs/harness/state.md`를 업데이트한다:

```yaml
status: running
current_phase: plan
next_role: design
updated_at: "<ISO-8601 UTC now>"
```

다른 키는 변경하지 않는다. 타겟 업데이트를 위해 `Edit`을 사용한다.

### 4. `pipeline-log.md`에 행 추가

`docs/harness/protocol.md` §6의 스키마에 따라 `docs/harness/pipeline-log.md`에 한 행을 추가한다:

```
| <ISO-8601 UTC now> | complete | plan | PRD 작성 완료; app_slug: <slug>; bundle_id: com.<company>.<id> |
```

---

## 오류 처리 (Error Handling)

- 리서치 스펙이 없거나 비어 있으면 명확한 메시지로 중단하고 `state.md`를 `status: paused`, `pause_reason: manual_action`으로 설정한다.
- `config.md`를 읽을 수 없으면 즉시 중단한다 (부분 출력을 작성하지 않는다).
- 필수 PRD 섹션을 스펙에서 채울 수 없으면, 섹션을 생략하지 않고 명확히 표시된 플레이스홀더를 작성한다(`<!-- TODO: 작성 필요 -->`) — 다운스트림 검증기가 섹션 제목을 grep으로 확인한다.
