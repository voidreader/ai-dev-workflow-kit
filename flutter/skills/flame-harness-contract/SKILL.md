---
name: flame-harness-contract
description: Phase 4 — 검증 가능한 완성 기준과 필수 하드 게이트를 제안하고, AGREED에 도달시킨다(기본 1-pass, --strict 시 다단계 자기검토).
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

# flame-harness-contract

flutter-flame-harness 파이프라인의 Phase 4. PRD와 디자인 문서를 읽고, 검증 가능한 완성 기준(Mandatory Hard Gates + Functional Criteria)을 제안한 뒤, generator에 핸드오프하기 전에 계약을 AGREED로 표시한다.

모든 파일 스키마(`config.md`, `state.md`, `contract.md`)는 `docs/harness/protocol.md`에 정의되어 있다 — 해당 문서를 단일 진실의 출처(SSOT)로 참조한다. 스키마를 이 문서에서 재정의하지 않는다.

---

## 입력

### 1. `docs/harness/config.md` 읽기

다음 키를 추출한다:

| 키 | 용도 |
|---|---|
| `app_name` | 계약서 제목 헤더 |
| `app_slug` | 게임 식별에 사용 |
| `strict_mode` | `true`이면 `--strict` 협상 실행; `false`(또는 부재)이면 기본 1-pass 실행 |

### 2. 최신 PRD 읽기

`docs/harness/plans/*-prd.md` 패턴에 맞는 가장 최근 파일을 찾는다(파일명 내림차순 정렬, 첫 번째 선택). 존재하지 않으면 명확한 메시지와 함께 중단한다.

### 3. 디자인 문서 읽기

`docs/harness/plans/*-design.md` 패턴에 맞는 가장 최근 파일을 찾는다(파일명 내림차순 정렬, 첫 번째 선택). 존재하지 않으면 중단한다.

---

## Mandatory Hard Gates

이 8가지 기준은 협상 불가이며, 모든 `contract.md`에 그대로 포함되어야 한다. 어느 하나라도 FAIL이면 다른 기준의 통과 여부와 무관하게 즉시 FAIL 판정이 난다.

> **출처:** `docs/harness/protocol.md` §3 — Mandatory Hard Gates 블록. 항상 인용하며, 다르게 재서술하지 않는다.

1. `flutter analyze` returns zero issues.
2. `flutter test` — all tests pass.
3. No TODO, stub, or placeholder in game logic (grep-checkable).
4. All tuning constants centralized in `game_config.dart` — no magic numbers in gameplay code.
5. Game content (enemies / levels / waves) is defined as data, not hardcoded.
6. Localization complete for all configured locales — `default_language`, plus English when `default_language` ≠ `en` — no missing l10n keys.
7. Core loop works end to end: start → play → win/lose → restart.
8. Runs on a simulator/emulator with zero crashes and zero console errors.

이 8줄을 `contract.md`의 `## Mandatory Hard Gates` 섹션에 그대로 복사한다. 바꿔 쓰거나 순서를 바꾸거나 빠뜨리지 않는다.

## Platform-Robustness Gates

위 8개 핵심 게이트 외에도, 모든 계약서에는 `docs/harness/game-gotchas.md`의 패턴을 요구하는 `## Platform-Robustness Gates` 섹션이 포함된다(해당 문서를 인용할 것). 다음은 필수 항목이다:

- **R1 Audio safe**: 모든 오디오 호출을 try/catch로 감쌈(누락 에셋이 크래시를 일으키지 않음); 빈번한 SFX는 `AudioPool` 사용(매 호출 `FlameAudio.play()` 금지); BGM은 게임오버·앱 백그라운드·teardown 시 정지.
- **R2 Haptics safe** (게임이 햅틱을 사용하는 경우): 플랫폼 가드 + 스로틀 + `enabled` 토글 + try/catch를 갖춘 `Haptics` 헬퍼 사용; 게임플레이에서 `HapticFeedback.*`을 직접 호출하지 않음.
- **R3 Lifecycle**: 앱 호스트가 `WidgetsBindingObserver`를 구현; 백그라운드 전환 시 → `pauseEngine()` + BGM 일시정지; 재개 시 역전; teardown 시 오디오/타이머 정리.
- **R4 Performance**: 핫 패스에서 프레임마다 `world.children.whereType<...>()`를 호출하지 않음(프레임당 한 번 캐시); `Paint`/셰이더를 프레임마다 재생성하지 않음.
- **R5 App branding**: 커스텀 아이콘 + 스플래시를 생성함(기본 Flutter 아트 사용 금지); 아이콘은 불투명(알파 없음); 지역화된 앱 표시 이름(`CFBundleDisplayName`/`android:label`)이 `app_name`으로 설정됨("Runner"/슬러그 아님).
- **R6 Native config**: 방향(orientation)을 `config.orientation`에 맞게 **네이티브에서** 잠금(미사용 방향 제거 — 실행 시 회전 없음); iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`, iPad 없음); `ITSAppUsesNonExemptEncryption = false`; 루트 뒤로 버튼 = SnackBar 더블 프레스 종료; bundle id가 iOS(`PRODUCT_BUNDLE_IDENTIFIER`)와 Android(`applicationId`) 양쪽에서 `config.bundle_id`와 **바이트 단위로 동일**(소문자, `_`/`-` 없음).
- **R7 Assets & CI**: 게임에 오디오(합성 또는 소싱) + 비주얼(코드 드로잉 또는 정제된 스프라이트)이 포함되고 **누락된 에셋 참조가 없음**(모든 `pubspec.yaml` 에셋이 실제 존재); `.github/workflows` CI(analyze + test)가 존재.
- **R8 Store graphics**: Android Play 리스팅에 `supply`용 **hi-res icon(512×512)** 및 **feature graphic(1024×500)** 배치(`metadata/android/<locale>/images/icon.png` + `featureGraphic.png`); iOS에 지역화된 스크린샷 포함.
- **R9 Durable save**: 영속성이 재설치 **및** 기기 이전 후에도 유지됨(`shared_preferences` 단독 사용 금지) — `SaveRepository`가 저장 블롭을 iOS Keychain(`flutter_secure_storage`, `first_unlock`) + Android Block Store(`play_services_block_store`) + `shared_preferences` 캐시에 미러링; 내구성 우선으로 읽고, try/catch 안에서 모든 티어에 씀; `PreferencesService`가 이를 통해 라우팅.

> **출처:** 각 R1~R9 패턴의 상세 구현 지침은 `docs/harness/game-gotchas.md`를 참조한다. 재서술하지 않는다.

---

## Functional Criteria

PRD에서 도출한 게임별 인수 기준. 각 기준은 다음 중 하나로 검증 가능해야 한다:

- **Command** — 종료 코드 또는 출력으로 기준을 증명하는 셸 명령어(예: `grep -r "TODO" lib/`가 아무것도 반환하지 않음).
- **Screenshot** — 기준을 시각적으로 확인하는 레이블된 스크린샷.
- **Code path** — 동작을 구현하는 파일명 + 메서드명, 그리고 이를 실행하는 테스트.

### Functional Criteria 작성 방법

PRD 섹션을 주의 깊게 읽는다:

| PRD 섹션 | 추출할 내용 |
|---|---|
| Core Loop | 각 루프 단계별로 하나의 기준(각 단계는 관찰 가능해야 함) |
| Game Mechanics | 각 메커닉별로 하나의 기준; 측정 가능한 임계값 명시 |
| Win/Lose Conditions | 명확한 통과/실패 상태 |
| Content Metrics | 수량 목표(예: "데이터 파일에 적 유형 ≥ 3개 정의됨") |
| Progression & Economy | 점수 증가, 보상 트리거 |

검증 불가능한 기준(예: "게임이 재미있다")은 관찰 가능한 체크로 재작성하거나 제거해야 한다. 시간 임계값을 참조하는 모든 기준은 구체적인 수치를 명시해야 한다(예: "100 ms 이내 응답" — "빠르게 응답" 불가).

게임당 Functional Criteria는 5~10개를 목표로 한다. 많을수록 좋은 것이 아니라 구체성이 중요하다.

### Anti-stub 규칙

AGREED를 표시하기 전에 다음을 실행한다:

```bash
grep -rn "TODO\|stub\|placeholder\|스텁\|미구현" lib/ --include="*.dart"
```

이 명령어가 어떤 출력이라도 반환하면, 계약서를 AGREED로 표시해서는 **안 된다**. 진행하기 전에 모든 스텁을 제거하거나 해결한다.

---

## 협상

### 기본 모드 (1-pass)

`strict_mode`가 `false`이거나 부재할 때:

1. Generator가 PRD와 디자인 문서를 읽는다.
2. Generator가 `docs/harness/contract.md`를 작성한다:
   - 8개 Mandatory Hard Gates를 그대로(`docs/harness/protocol.md` §3에서).
   - PRD에서 도출한 5~10개 Functional Criteria.
3. Generator가 각 기준의 검증 가능성을 자체 검토한다.
4. Generator가 같은 패스에서 계약서를 `## Status: AGREED`로 표시한다.
5. Generator가 `state.md`를 갱신하고 generator 단계로 핸드오프한다.

### --strict 모드 (엄격한 자체 검토)

`config.md`에 `strict_mode: true`가 있거나, 스킬이 `--strict`로 호출될 때:

1. Generator가 초기 `contract.md`를 작성한다(기본과 동일, 1~3단계).
2. Generator가 모든 Functional Criteria에 대해 **두 번째 자체 검토 패스**를 수행하며, 각각을 다음 세 게이트에 대해 검사한다:
   - **구체적인 검증 방법** — 특정 셸 명령어(예상 종료 코드 또는 출력 포함), 레이블된 스크린샷, 또는 파일명 + 메서드명 + 테스트를 명시하는가? "올바르게 작동한다" 또는 "좋아 보인다"와 같은 모호한 표현은 측정 가능한 체크로 재작성해야 한다.
   - **구체적인 수치** — 모든 타이밍·카운트·임계값이 실제 값을 명시해야 한다(예: "100 ms 이내 응답", "적 유형 ≥ 3개", "장애물당 점수 10 증가"). 상대적 표현("빠르게", "여러 개", "충분히")은 교체해야 한다.
   - **PRD 전체 커버리지** — PRD의 모든 핵심 루프 단계·메커닉·승리/패배 조건·콘텐츠 지표에 대응하는 Functional Criteria가 하나 이상 있음을 확인한다.
3. 두 번째 패스 검토에서 기준이 실패하면 진행 전에 해당 기준을 제자리에서 수정한다.
4. Generator가 `## Status: AGREED`를 자체 표시하고 진행한다(기본 모드와 동일한 `state.md` 쓰기).

> **Phase B 참고:** Phase B에서는 Generator↔Evaluator 왕복을 통한 Evaluator 측 계약 협상이 재도입될 수 있다; Phase A는 엄격한 자체 검토만 사용한다.

두 모드 모두 generator 단계가 코딩을 시작하기 전에 계약서 파일에 `## Status: AGREED`가 포함되어 있어야 한다.

---

## 출력

### 1. `docs/harness/contract.md` 작성

`docs/harness/protocol.md` §3에 정의된 레이아웃을 사용한다:

```markdown
# Contract — <app_name>

## Mandatory Hard Gates

These criteria are non-negotiable. A FAIL on any one of these results in an immediate FAIL verdict,
regardless of other passing criteria.

1. `flutter analyze` returns zero issues.
2. `flutter test` — all tests pass.
3. No TODO, stub, or placeholder in game logic (grep-checkable).
4. All tuning constants centralized in `game_config.dart` — no magic numbers in gameplay code.
5. Game content (enemies / levels / waves) is defined as data, not hardcoded.
6. Localization complete for all configured locales — `default_language`, plus English when `default_language` ≠ `en` — no missing l10n keys.
7. Core loop works end to end: start → play → win/lose → restart.
8. Runs on a simulator/emulator with zero crashes and zero console errors.

## Functional Criteria (per game)

<!-- Generator가 게임별 인수 기준을 여기에 추가한다. -->
<!-- 각 기준은 명령어, 스크린샷, 또는 코드 패스로 검증 가능해야 한다. -->

## Status: AGREED
```

`docs/harness/`가 존재하지 않으면 작성 전에 생성한다.

### 2. `state.md` 갱신

`docs/harness/protocol.md` §2의 스키마에 따라 `docs/harness/state.md`를 갱신한다:

```yaml
status: running
current_phase: contract
next_role: generator
current_round: 1
updated_at: "<ISO-8601 UTC now>"
```

다른 모든 키는 그대로 둔다. 타겟 업데이트에는 `Edit`을 사용한다.

`docs/harness/protocol.md` §7(Phase Transition Table)에 따라: `contract → AGREED` 이벤트는 `next_role: generator`와 `current_round: 1`을 설정한다.

### 3. `pipeline-log.md`에 추가

`docs/harness/protocol.md` §6의 스키마에 따라 `docs/harness/pipeline-log.md`에 한 행을 추가한다:

```
| <ISO-8601 UTC now> | complete | contract | contract AGREED; <N> functional criteria; next: generator |
```

---

## 오류 처리

- PRD가 없으면, 명확한 메시지와 함께 중단하고 `state.md`를 `status: paused`, `pause_reason: manual_action`으로 설정한다.
- 디자인 문서가 없으면, 명확한 메시지와 함께 중단하고 `state.md`를 `status: paused`, `pause_reason: manual_action`으로 설정한다.
- `config.md`를 읽을 수 없으면, 즉시 중단한다(부분 출력을 작성하지 않는다).
- `--strict` 모드에서, Generator는 엄격한 두 번째 패스 검토 후 AGREED를 자체 표시한다; Phase A에서는 다단계 Evaluator 루프가 없다. `max_rounds`는 generator→evaluator 사이클(Phase 5~6)에만 적용되며, 계약 협상에는 적용되지 않는다.
