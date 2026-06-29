---
name: flame-harness-evaluator
description: Phase 6 — 회의적 QA. 게임을 실행하고, 직접 확인한 뒤, 계약서 기준으로 PASS/FAIL을 판정한다. 기본 모드는 기능 체크(6.1)만 실행하며, --strict를 붙이면 품질 점수(6.2)와 에이전트 팀 엣지케이스 스윕(6.3)이 추가된다.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

# flame-harness-evaluator

flutter-flame-harness 파이프라인의 Phase 6. 협상된 계약서를 기준으로 PASS 또는 FAIL을 판정하는 회의적 QA 게이트다. 기본 모드는 기능 체크(6.1)만 실행하며, `--strict`를 붙이면 품질 점수(6.2)와 에이전트 팀 엣지케이스 스윕(6.3)이 추가된다.

모든 파일 스키마(`config.md`, `state.md`, `handoff/round-N-gen.md`, `feedback/round-N-qa.md`, `build-log.md`)와 페이즈 전이 테이블은 `docs/harness/protocol.md`에 정의되어 있으며, 그 문서가 단일 진실 원천(SSOT)이다(§1 = `config.md`; §2 = `state.md`; §3 = `contract.md`; §4 = handoff 레이아웃; §5 = feedback 레이아웃; §6 = 로그 스키마; §7 = `evaluator → admob / evaluator → build / evaluator → generator` 전이). 스키마를 여기서 재정의하지 않는다.

---

## 핵심 원칙

**"코드를 실행하고, 앱을 직접 확인한 뒤, 판정한다." 코드 리뷰만으로는 절대 PASS할 수 없다. 명령을 실행하고, 시뮬레이터에서 게임을 구동하고, 핵심 루프를 플레이하고, 스크린샷을 캡처하고 꼼꼼히 확인하라. 스텁이 발견되면 예외 없이 자동 FAIL이다.**

---

## 경로 파라미터

- `<project_root>` — 사용자가 지정한 프로젝트 생성 디렉토리(기본값: 현재 작업 디렉토리). 이 스킬 전반에서 게임 루트는 `<project_root>/<app_slug>`를 사용한다.
- `<app_slug>` — `docs/harness/config.md`의 `app_slug` 값.

---

## 설정 — 입력 읽기

체크를 시작하기 전에 다음을 로드한다:

1. `docs/harness/state.md` — `current_round`(정수, 1 이상)를 추출하고 `next_role: evaluator`임을 확인한다.
2. `docs/harness/config.md` — `app_slug`, `strict_mode`(bool), `max_rounds`(int)를 추출한다.
3. `docs/harness/contract.md` — `## Mandatory Hard Gates`와 `## Functional Criteria`를 파싱한다.
   `## Status: AGREED`가 있는지 확인한다. 없으면 아래 메시지와 함께 중단한다:
   `flame-harness-evaluator: contract not AGREED — run flame-harness-contract first`
4. `docs/harness/handoff/round-<N>-gen.md`(N = `current_round`)를 `docs/harness/protocol.md` §4에 따라 읽는다.
   파일이 없으면 아래 메시지와 함께 중단한다:
   `flame-harness-evaluator: handoff for round <N> not found — generator must run first`

---

## 6.1 기능 체크 (기본 — 항상 실행)

모든 단계를 순서대로 실행한다. `contract.md`의 **Mandatory Hard Gate**에서 하나라도 실패하면 즉시 FAIL이며, 나머지 기준을 계속 확인하지 않는다.

### Step 1 — 정적 분석

```bash
cd <project_root>/<app_slug>
flutter analyze
```

요구 결과: **0 issues**. 이슈가 하나라도 보고되면 파일, 라인, 메시지를 각각 기록한다. 이는 Mandatory Hard Gate다.

### Step 2 — 테스트

```bash
cd <project_root>/<app_slug>
flutter test
```

요구 결과: **0 failures**. 전체 출력을 캡처한다. 이는 Mandatory Hard Gate다.

### Step 3 — 스텁 / TODO grep

```bash
grep -rn "TODO\|stub\|placeholder\|스텁\|미구현" \
  <project_root>/<app_slug>/lib/ --include="*.dart"
```

일치 항목이 하나라도 있으면 **자동 FAIL**이다. 예외 없음(`docs/harness/protocol.md` §3 Hard Gate 3 참고). 파일 경로, 라인 번호, 일치 텍스트를 기록한다.

### Step 4 — game_config.dart 집중화

```bash
grep -rn "[0-9]\{3,\}\.\?[0-9]*" \
  <project_root>/<app_slug>/lib/game/ --include="*.dart" \
  | grep -v "game_config.dart"
```

`game_config.dart` 외 게임 로직 파일에 매직 넘버(3자리 이상)가 있으면 Hard Gate 실패다(`docs/harness/protocol.md` §3 Hard Gate 4 참고). 명백히 튜닝 상수가 아닌 경우(예: HTTP 상태 코드)는 주석으로 이유가 명시된 경우에만 제외하며, 제외 내역을 피드백 파일에 기록한다.

### Step 5 — l10n 완전성

```bash
cd <project_root>/<app_slug>
flutter gen-l10n
```

그 다음, 프로젝트에 구성된 모든 `lib/l10n/app_<locale>.arb`(프로젝트의 `default_language`, 그리고 `default_language` ≠ `en`인 경우 `app_en.arb`)에 동일한 키 세트가 있는지 확인한다:

```bash
python3 -c "
import glob, json
arbs = glob.glob('lib/l10n/app_*.arb')
keysets = {f: set(json.load(open(f))) for f in arbs}
allkeys = set().union(*keysets.values()) if keysets else set()
bad = {f: sorted(allkeys - ks) for f, ks in keysets.items() if allkeys - ks}
if len(arbs) < 1: print('NO ARB FILES'); exit(1)
if bad: print('MISSING KEYS:', bad); exit(1)
print('l10n OK', list(keysets))
"
```

어느 로케일에서든 키가 누락되면 Hard Gate 실패다(`docs/harness/protocol.md` §3 Hard Gate 6 참고).

### Step 5a — 플랫폼 견고성 게이트

`contract.md` / `docs/harness/game-gotchas.md`의 `## Platform-Robustness Gates`(R1–R9)를 검증한다:

```bash
# R1 오디오: 빈번한 SFX는 풀링 + 오디오 호출 보호; BGM은 teardown 시 stop
grep -rn "AudioPool" lib/ || echo "WARN: no AudioPool — frequent SFX may stutter"
grep -rn "FlameAudio\|AudioPool\|\.bgm" lib/ | grep -i "try\|catch" >/dev/null || echo "CHECK: audio not in try/catch"
grep -rn "bgm.stop\|\.stop()" lib/ || echo "CHECK: BGM stop on teardown/background"
# R2 햅틱 (사용 시)
ls lib/systems/haptics.dart 2>/dev/null && grep -nE "kIsWeb|isIOS|isAndroid|enabled|Stopwatch|elapsed" lib/systems/haptics.dart
# R3 라이프사이클
grep -rn "WidgetsBindingObserver\|didChangeAppLifecycleState\|pauseEngine" lib/ || echo "FAIL: no lifecycle pause"
# R4 성능: update 핫 패스에서 per-frame whereType 없어야 함
grep -rn "whereType" lib/ | grep -i "update" && echo "CHECK: whereType inside update — verify it's cached, not per-frame"
# R5 브랜딩: 커스텀 아이콘 + 스플래시 + 로컬라이즈된 표시 이름 (기본값 아님)
ls assets/icons/icon.png 2>/dev/null || echo "FAIL: no custom app icon"
grep -q "flutter_launcher_icons" pubspec.yaml && grep -q "flutter_native_splash" pubspec.yaml || echo "FAIL: launcher-icons/native-splash not configured"
sips -g hasAlpha assets/icons/icon.png 2>/dev/null | grep -qi "hasAlpha: no" || echo "CHECK: icon may have alpha (App Store rejects)"
grep -rn "CFBundleDisplayName" ios/Runner/Info.plist 2>/dev/null || echo "CHECK: iOS display name not set"
grep -rn 'android:label' android/app/src/main/AndroidManifest.xml 2>/dev/null | grep -qiv "runner" || echo "CHECK: Android label still default/runner"
# R6 네이티브 설정: 방향 잠금 (config.orientation 일치, ~ipad 없음), iPhone 전용, 수출 규정 준수, 루트 back
grep -q "UISupportedInterfaceOrientations" ios/Runner/Info.plist 2>/dev/null && ! grep -q "UISupportedInterfaceOrientations~ipad" ios/Runner/Info.plist || echo "CHECK: orientation not locked / ~ipad still present"
grep -rq "TARGETED_DEVICE_FAMILY = 1" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || echo "FAIL: not iPhone-only (TARGETED_DEVICE_FAMILY != 1)"
grep -q "ITSAppUsesNonExemptEncryption" ios/Runner/Info.plist 2>/dev/null || echo "CHECK: export-compliance key missing"
grep -rq "PopScope" lib/ || echo "CHECK: no root back-button handler"
# R6 번들 ID: iOS/Android 동일 (== config.bundle_id, 소문자, _/- 없음)
IOSID=$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9._-]+' ios/Runner.xcodeproj/project.pbxproj 2>/dev/null | head -1 | sed 's/.*= //')
ANDID=$(grep -oE 'applicationId *= *"[^"]+"' android/app/build.gradle.kts 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)"/\1/')
echo "iOS=$IOSID  Android=$ANDID  (must be byte-identical == config.bundle_id)"
{ [ -n "$IOSID" ] && [ "$IOSID" = "$ANDID" ]; } || echo "FAIL: iOS and Android bundle id differ (or unset)"
echo "$IOSID" | grep -qE '^[a-z0-9.]+$' || echo "FAIL: bundle id has uppercase/_/- (must be lowercase [a-z0-9.])"
# R7 에셋 & CI: 오디오 존재, 누락된 에셋 참조 없음, CI 워크플로 존재
ls assets/audio/*.wav assets/audio/*.mp3 assets/audio/*.ogg 2>/dev/null | grep -q . || echo "FAIL: no audio assets — game ships silent"
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | grep -q . || echo "FAIL: no CI workflow"
# R8 Play 스토어 그래픽: hi-res 아이콘(512) + 피처 그래픽(1024x500) per locale
ls android/fastlane/metadata/android/*/images/icon.png 2>/dev/null | grep -q . || echo "FAIL: no Play hi-res icon (512x512)"
ls android/fastlane/metadata/android/*/images/featureGraphic.png 2>/dev/null | grep -q . || echo "FAIL: no Play feature graphic (1024x500)"
# R9 내구성 저장: SaveRepository가 Keychain + Block Store + prefs에 미러링; PreferencesService가 이를 통해 라우팅
grep -q "flutter_secure_storage" pubspec.yaml && grep -q "play_services_block_store" pubspec.yaml || echo "FAIL: durable-save deps missing (saves won't survive reinstall/device on iOS)"
ls lib/data/save_repository.dart 2>/dev/null || echo "FAIL: no SaveRepository (durable save layer)"
grep -q "FlutterSecureStorage" lib/data/save_repository.dart 2>/dev/null && grep -q "PlayServicesBlockStore" lib/data/save_repository.dart 2>/dev/null || echo "FAIL: SaveRepository missing a durable tier (Keychain/Block Store)"
# pubspec에 선언된 모든 에셋 경로가 디스크에 존재하는지 확인
python3 - <<'PY'
import re,glob,os,sys
try: txt=open('pubspec.yaml').read()
except FileNotFoundError: sys.exit(0)
m=re.search(r'\n\s*assets:\s*\n((?:\s*-\s.*\n)+)', txt)
missing=[]
if m:
    for line in m.group(1).splitlines():
        p=line.strip().lstrip('- ').strip().strip('"\'')
        if not p: continue
        if p.endswith('/'):
            if not (os.path.isdir(p) and os.listdir(p)): missing.append(p)
        elif not os.path.exists(p): missing.append(p)
print('MISSING ASSETS:',missing) if missing else print('assets OK')
PY
```

결과를 `docs/harness/game-gotchas.md` 기준으로 판정한다: 라이프사이클 pause 없음(R3)이나 에셋 누락 시 크래시하는 무방비 오디오(R1)는 FAIL이다. update 핫 패스에서 per-frame `whereType`, 또는 보호 헬퍼 없이 게임플레이에 raw `HapticFeedback.*`를 사용하는 경우, 게임이 이에 의존한다면 FAIL이다.
또한 게임이 **오디오/이미지 에셋이 없어도 크래시하지 않는지**(우아하게 성능 저하) 확인한다.
**브랜딩(R5):** 기본 Flutter 아이콘/스플래시, 알파 채널 아이콘, "Runner"/슬러그 표시 이름은 FAIL — 앱은 출시된 것처럼 보여야 한다.
**네이티브 설정(R6):** 앱은 `config.orientation`으로 바로 열려야 하고(회전 깜빡임 없음 → 네이티브에서 방향 잠금, `~ipad` 제거), iPhone 전용이어야 하고, `ITSAppUsesNonExemptEncryption=false`가 있어야 하고, 루트 back 버튼을 처리해야 한다(SnackBar 두 번 터치로 종료).
**에셋 & CI(R7):** 오디오 없음(게임이 무음으로 출시됨), 선언된 에셋 누락, CI 워크플로 없음은 FAIL이다.
**스토어 그래픽(R8):** Play hi-res 아이콘(512×512) 또는 피처 그래픽(1024×500) 누락은 FAIL — 이것들 없이는 등록을 게시할 수 없다.
**내구성 저장(R9):** `shared_preferences`만으로는 FAIL — iOS는 앱 삭제 시 이를 삭제하므로 재설치/새 기기에서 플레이어가 진행상황을 잃는다. iOS Keychain + Android Block Store에 미러링하는 `SaveRepository`가 있어야 한다(내구성 우선 읽기, 전 계층 쓰기, try/catch), `PreferencesService`는 이를 통해 라우팅해야 한다.

### Step 6 — 계약서 기준 증거

`contract.md` §§ "Mandatory Hard Gates"와 "Functional Criteria"의 각 기준에 대해, 실행한 명령, 결과, 스크린샷 또는 로그 경로를 피드백 증거 테이블에 한 행씩 기록한다. 해당 기준을 직접 검증하는 명령을 실행하지 않고는 DONE으로 표시하지 않는다.

### Step 7 — 시뮬레이터에서 실행하고 핵심 루프 플레이

**이 단계는 필수다. 이 단계를 완료하지 않으면 PASS 판정은 유효하지 않다.**

iOS 시뮬레이터(또는 iOS를 사용할 수 없는 경우 Android 에뮬레이터)를 부팅한다:

```bash
open -a Simulator
xcrun simctl boot "iPhone 16" 2>/dev/null || true
```

게임을 설치하고 실행한다:

```bash
cd <project_root>/<app_slug>
flutter run -d "iPhone 16" --no-pub
```

게임이 실행되는 동안:

0. 스크린샷 디렉토리가 없으면 생성한다:
   ```bash
   mkdir -p <project_root>/<app_slug>/docs/harness/screenshots
   ```
1. 메인 메뉴로 이동하고 스크린샷을 캡처한다:
   ```bash
   xcrun simctl io booted screenshot \
     <project_root>/<app_slug>/docs/harness/screenshots/round-<N>-ios-menu.png
   ```
2. 게임 세션을 시작한다. 핵심 루프를 플레이한다(시작 → 플레이 → 승리/패배 → 재시작).
3. 게임플레이 상태의 스크린샷을 캡처한다:
   ```bash
   xcrun simctl io booted screenshot \
     <project_root>/<app_slug>/docs/harness/screenshots/round-<N>-ios-play.png
   ```
4. 게임 오버 또는 승리 조건에 도달한다. 결과 화면을 캡처한다:
   ```bash
   xcrun simctl io booted screenshot \
     <project_root>/<app_slug>/docs/harness/screenshots/round-<N>-ios-end.png
   ```
5. 각 스크린샷을 꼼꼼히 확인한다: 빈/흰 화면, 시각적 결함, 누락된 스프라이트, 겹치는 UI 요소, 잘못된 언어, 렌더링 오류 등.
6. 게임이 크래시 없이, 콘솔 오류 없이 실행되는지 확인한다.

크래시, 빈 화면, 콘솔 오류는 Hard Gate 실패다(`docs/harness/protocol.md` §3 Hard Gates 7–8 참고).

---

## 6.2 품질 점수 (`--strict` 전용)

`config.md`에 `strict_mode: true`이거나 `--strict`를 전달한 경우에만 이 섹션을 실행한다.

게임을 4가지 축으로 점수를 매긴다(각 0–10):

| 축 | 평가 내용 |
|---|---|
| **게임 느낌 / 주스** | 반응성, 애니메이션, 액션 피드백, 오디오 큐 |
| **독창성** | 리서치 페이즈에서 파악한 경쟁작 대비 신선함 |
| **완성도** | 코드 품질, 버벅임 없음, 시각적 완성도, 일관된 디자인 토큰 |
| **기능성** | 모든 계약 기준 충족, 엣지케이스 미파손 |

추가 평가:

- **상호작용 상태**: 로딩, 오류, 빈 상태를 게임이 우아하게 처리하는가?
- **반응성**: 대상 기기 크기에서 게임이 올바르게 렌더링되는가?

점수 임계값:

- 기본(`strict_mode: false`): 가중 평균 ≥ **7 / 10**이면 PASS 권고(권고 사항).
- 엄격 프로파일(`strict_mode: true`): 가중 평균 ≥ **8 / 10**이어야 PASS.

가중치: 게임 느낌 30%, 독창성 20%, 완성도 25%, 기능성 25%.

각 축의 점수와 가중 합계를 피드백 파일에 기록한다. 가중 합계가 임계값 미만이면 6.1 결과와 무관하게 FAIL이며, 7 미만인 각 축에 대해 최소 하나의 구체적이고 재현 가능한 수정 사항을 기재해야 한다.

---

## 6.3 엣지케이스 스윕 (`--strict` 전용)

`config.md`에 `strict_mode: true`이거나 `--strict`를 전달한 경우에만 이 섹션을 실행한다.

`Agent` 툴을 통해 6개의 전문가 에이전트를 병렬로 생성한다. 전체 판정이 PASS가 되려면 6개 에이전트 모두 PASS를 보고해야 한다. 어느 하나라도 FAIL이면 FAIL 판정이다.

| 에이전트 역할 | 브리프 |
|---|---|
| **gameplay-edge** | 게임플레이 엣지케이스 찾기: 점수 오버플로, 음수 체력, 도달 불가 상태, 화면 밖 엔티티, 동시 충돌 처리. |
| **balance** | 난이도 곡선 평가: 게임이 클리어 가능한가? 처음 30초가 너무 쉬운가? 난이도 상승이 공정하게 느껴지는가? |
| **lifecycle/crash** | 앱 백그라운딩(홈 버튼), 화면 회전, 수신 전화 인터럽트 시뮬레이션; 재개가 작동하고 크래시가 없는지 확인. |
| **performance** | `flutter run --profile` 실행, DevTools에서 프레임 렌더링 확인; 30fps 미만으로 지속적으로 떨어지면 플래그. |
| **test-generator** | 테스트되지 않은 가장 위험한 3개 경로를 파악하고 위젯/유닛 테스트 작성; 통과 여부 확인. |
| **adversarial-reviewer** | 생성된 코드를 공격적으로 리뷰하여 보안 문제, 자격증명 누출, 앱 스토어 정책 위반 탐색. |

각 에이전트는 증거와 함께 구조화된 PASS/FAIL 판정을 반환해야 한다. 판정으로 진행하기 전에 6개 판정을 모두 수집한다.

---

## 판정

적용 가능한 모든 섹션(6.1, `--strict`인 경우 6.2 + 6.3)을 완료한 뒤 판정을 작성한다.

### 판정 결정

- **PASS** 조건:
  - 6.1의 모든 Mandatory Hard Gate 통과 AND 모든 6.1 기능 기준이 증거와 함께 검증됨.
  - `--strict`인 경우: 6.2 가중 점수 ≥ 임계값 AND 6개의 6.3 에이전트 모두 PASS 보고.
- **FAIL** 조건: 어떤 Hard Gate라도 실패, 증거 없는 기능 기준, 또는(`--strict`인 경우) 6.2 점수가 임계값 미만이거나 6.3 에이전트 중 하나라도 FAIL 보고.

### max_rounds 확인

판정을 작성하기 전에 확인: `current_round == max_rounds`이면 판정을 강제한다. 결과에 무관하게 FAIL을 반환하지 말고 — 현재 상태로 판정을 작성하고, 피드백 파일에 강제 진행 메모를 기록하고, PASS 전이로 진행한다(`docs/harness/protocol.md` §7 `evaluator → max_rounds → admob / build` 참고, PASS와 동일한 `skip_admob` 분기 적용).

### feedback/round-N-qa.md 작성

`docs/harness/feedback/round-<N>-qa.md`를 `docs/harness/protocol.md` §5의 레이아웃에 따라 생성한다. 다음을 채운다:

- `## Verdict` — **PASS** 또는 **FAIL** (볼드).
- `## Evidence` — 확인한 기준마다 한 행; 시뮬레이터 확인의 경우 스크린샷 경로 포함.
- `## Failed Criteria` — FAIL마다 구체적이고 재현 가능한 수정 사항. PASS이면 "none"으로 작성.

플레이스홀더 텍스트를 남기지 않는다. 모든 기준에는 실제 명령 출력 또는 스크린샷 경로가 증거로 있어야 한다.

### state.md 업데이트 (PASS)

PASS(또는 max_rounds에서 강제 진행)인 경우, 게임이 빌드되고 QA를 통과했지만 — 배포 작업(admob/build/screenshot/submit) 전에 사용자가 게임을 직접 플레이하고 승인할 수 있도록 기본적으로 **사람 승인 게이트**가 있다.

먼저 `docs/harness/config.md`에서 `skip_admob`과 `auto_deploy`를 읽고 `next_role`을 결정한다:
- `skip_admob: true`이면 → `next_role: build`
- 그 외에는 → `next_role: admob`

그 다음 `auto_deploy`에 따라 분기한다:

**기본(`auto_deploy: false`) — 사람 검수를 위해 PAUSE.**
`state.md`를 `status: paused`, `pause_reason: manual_action`, 위에서 결정한 `next_role`로 작성한다(`docs/harness/protocol.md` §7 규칙 2 참고). `pipeline-log.md`에 행을 추가하고 사용자에게 검수 체크리스트를 출력한다:

> 게임 빌드 + QA 통과. **배포 전 직접 확인하세요:** `cd <app_slug> && flutter run` 으로 플레이하고,
> `docs/harness/screenshots/` 의 QA 스크린샷과 `docs/harness/feedback/round-<N>-qa.md` 를 확인.
> 만족하면 `/flame-harness --resume` 로 배포(admob→build→screenshot→submit)를 진행합니다.

```yaml
status: paused
current_phase: evaluator
next_role: admob   # skip_admob: true이면 "build"
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

오케스트레이터는 `status: paused`에서 중단하며, `--resume` 시 `flame-harness-resume`이 사용자 승인을 확인하고 저장된 `next_role`을 디스패치한다.

**`auto_deploy: true` — pause 없이 배포로 바로 진행.**
같은 `next_role`로 `status: running`을 작성하면 오케스트레이터가 자동으로 계속한다:

```yaml
status: running
current_phase: evaluator
next_role: admob   # skip_admob: true이면 "build"
updated_at: "<ISO-8601 UTC now>"
```

`current_round`, `created_at`, `resume_attempts`는 변경하지 않는다. (`auto_deploy: false` 경우 `pause_reason: manual_action`을 설정하고; `auto_deploy: true` 경우 `pause_reason`은 변경하지 않는다.)

### state.md 업데이트 (FAIL)

FAIL(이고 `current_round < max_rounds`)인 경우, `docs/harness/protocol.md` §2와 §7의 `evaluator → generator` 전이에 따라 `docs/harness/state.md`를 업데이트한다. `current_round`를 증가시키고 `status: running`을 원자적으로 설정한다(`docs/harness/protocol.md` §7 규칙 2 참고):

```yaml
status: running
current_phase: evaluator
next_role: generator
current_round: <N+1>
updated_at: "<ISO-8601 UTC now>"
```

`created_at`, `resume_attempts`, `pause_reason`은 변경하지 않는다.

### build-log.md에 추가

`docs/harness/protocol.md` §6에 따라 `docs/harness/build-log.md`에 한 행을 추가한다:

```
| <N> | evaluator | PASS/FAIL | <소요시간> | <한 줄 요약> |
```

### pipeline-log.md에 추가

`docs/harness/protocol.md` §6에 따라 `docs/harness/pipeline-log.md`에 한 행을 추가한다:

```
| <ISO-8601 UTC now> | PASS/FAIL | evaluator | round <N>; next: admob|build/generator |
```

PASS 경로에서 사람 검수 게이트를 위해 pause한 경우(기본, `auto_deploy: false`), `flame-harness-resume`이 사용자가 승인하는 내용을 확인할 수 있도록 `pause` 이벤트 행을 추가로 추가한다:

```
| <ISO-8601 UTC now> | pause | evaluator | manual_action: play/approve the built game before deploy; next: admob|build |
```

---

## 오류 처리

- `contract.md`가 없거나 `## Status: AGREED`가 없으면 즉시 중단한다.
- `handoff/round-<N>-gen.md`가 없으면 명확한 메시지와 함께 중단한다. FAIL 판정을 설정하지 않는다 — 제너레이터가 아직 실행되지 않은 것이다.
- 시뮬레이터를 부팅할 수 없는 경우(하드웨어 CI), 실패를 문서화하고, Step 7을 건너뛰고, "시뮬레이터를 부팅하고 Step 7을 완료하세요"라는 수정 사항과 함께 판정을 FAIL로 설정한다.
- 6.3의 에이전트가 오류를 반환하면(FAIL이 아닌 툴 오류), 한 번 재시도한 뒤 "agent error — retry required" 메모와 함께 FAIL로 처리한다.
