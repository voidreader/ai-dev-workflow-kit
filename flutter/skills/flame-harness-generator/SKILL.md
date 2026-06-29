---
name: flame-harness-generator
description: Phase 5 — Flame 게임을 3단계 게이트(코어루프 → 시스템+컴포넌트 → UI+콘텐츠)로 빌드하고, 계약 기준 자체 평가 후 핸드오프를 작성한다.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

# flame-harness-generator

flutter-flame-harness 파이프라인의 Phase 5. Flame 게임을 세 개의 게이트 하위 단계(5a → 5b → 5c)로 빌드한다. 각 하위 단계는 다음 단계 시작 전에 HARD GATE(`flutter analyze` 0개 이슈 + `flutter test` 전부 통과)를 통과해야 한다. Round N > 1이면, 이전 evaluator 피드백을 읽고 나열된 실패 항목만 수정한다.

모든 파일 스키마(`config.md`, `state.md`, `handoff/round-N-gen.md`, `feedback/round-N-qa.md`) 및 단계 전이 테이블은 `docs/harness/protocol.md`에 정의되어 있다 — 해당 문서가 단일 정보 출처(SSOT)다(§2 `state.md` 스키마; §4 handoff 레이아웃; §5 feedback 레이아웃; §7 `generator → evaluator` 전이). 스키마를 여기서 재정의하지 않는다.

`<project_root>`는 사용자가 지정한 프로젝트 생성 디렉토리(기본값: 현재 작업 디렉토리)이다. 이후 `<project_root>/<app_slug>` 형식으로 사용한다.

---

## 라운드 처리 및 피드백 인테이크

### 현재 라운드 확인

`docs/harness/state.md`를 읽는다. `current_round`(정수, ≥ 1)를 추출한다.

### Round 1 — 처음부터 빌드

`current_round`가 1일 때:

1. `docs/harness/config.md`를 읽는다(`app_slug`, `app_name`, `bundle_id`, `default_language`, `skip_admob` 추출).
2. 최신 PRD를 읽는다(`docs/harness/plans/*-prd.md`, 내림차순 정렬, 첫 번째 파일).
3. 최신 디자인 문서를 읽는다(`docs/harness/plans/*-design.md`, 내림차순 정렬, 첫 번째 파일).
4. `docs/harness/contract.md`를 읽는다. `## Status: AGREED`가 있는지 확인한다. 없으면 즉시 중단:
   `flame-harness-generator: contract not AGREED — run flame-harness-contract first`
5. Sub-phase 5a로 진행한다.

### Round N > 1 — 나열된 실패만 수정(피드백 인테이크)

`current_round`가 1보다 클 때:

1. `docs/harness/feedback/round-<N-1>-qa.md`를 읽는다(`docs/harness/protocol.md` §5 레이아웃 기준).
2. `## Failed Criteria` 섹션을 파싱하여 각 실패 기준과 처방된 수정 사항을 추출한다.
3. 실패로 나열되지 않은 영역은 재설계·리팩터링하지 않는다. 나열된 수정 사항을 충족하는 데 필요한 최소한의 변경만 한다.
4. `docs/harness/feedback/round-<N-1>-qa.md`가 존재하지 않으면 중단한다:
   `flame-harness-generator: feedback file for round <N-1> not found — cannot determine fixes`
5. 각 수정을 적용한 후, handoff를 작성하기 전에 영향받는 하위 단계의 HARD GATE를 실행한다.

---

## Sub-phase 5a — 스캐폴드 + 코어 루프

### 5a.1 Flutter 프로젝트 생성(flutter create)

`flutter create`를 실행한다. Dart **패키지 이름**은 snake_case(소문자 + 밑줄, 하이픈 없음)여야 한다 — `app_slug`를 변환한다(예: `swing-line` → `swing_line`). 이 패키지 이름은 bundle id와 별개다.

`<company>`는 `config.md`의 `developer.company`에서 읽는다:

```bash
flutter create --org com.<company> --project-name <app_slug_snake_case> \
  <project_root>/<app_slug>
```

**Bundle id — 양 플랫폼에 명시적으로 동일하게 설정한다(`flutter create`가 파생하는 값을 신뢰하지 않는다).** `flutter create`는 bundle id를 `--org` + project-name으로 조합하므로, 언더스코어·대소문자 차이가 생겨 iOS와 Android가 달라질 수 있다. 양쪽 모두 `config.bundle_id`(`com.<company>.<id>`, 소문자 `[a-z0-9]`만 — `docs/harness/protocol.md` 참조)로 강제 설정한다:

- iOS: `ios/Runner.xcodeproj/project.pbxproj`의 **세 가지** 빌드 구성(Debug/Release/Profile) 모두에서 `PRODUCT_BUNDLE_IDENTIFIER` = `<bundle_id>`로 설정한다.
- Android: `android/app/build.gradle.kts`에서 `applicationId`와 `namespace` **양쪽** 모두 = `<bundle_id>`로 설정한다.
- iOS `PRODUCT_BUNDLE_IDENTIFIER` == Android `applicationId` == `config.bundle_id` 임을 **바이트 단위로** 검증한다(동일 대소문자, `_` 없음, `-` 없음). AdMob 앱과 스토어 레코드는 이 정확한 id를 사용한다.

**중요(`docs/harness/protocol.md` 기준):** `flutter create`가 성공한 후, `docs/harness/` 디렉토리를 게임 프로젝트로 이동하여 모든 아티팩트가 하나의 저장소를 공유하게 한다:

```bash
mv <work_dir>/docs/harness <project_root>/<app_slug>/docs/harness
```

`<work_dir>`는 `flame-harness` 오케스트레이터가 부트스트랩 시 `docs/harness/`를 만든 작업 디렉토리다(보통 현재 작업 디렉토리). 이동 후 harness 파일에 대한 모든 읽기/쓰기는 게임 프로젝트 내부의 새 경로(`<project_root>/<app_slug>/docs/harness`)를 사용한다.

### 5a.2 기본 템플릿 파일 제거

생성된 카운터 데모를 삭제하여 깨끗한 상태에서 시작한다:

```bash
rm <project_root>/<app_slug>/lib/main.dart
rm <project_root>/<app_slug>/test/widget_test.dart
```

이 파일들은 아래의 게임 구현으로 대체된다.

### 5a.3 pubspec.yaml 설정

`pubspec.yaml`에 다음 필드를 설정한다:

- `name`: `<app_slug_snake_case>`(`config.md`에서)
- `description`: `<app_name>`(`config.md`에서)
- `publish_to: none`
- `version: 1.0.0+1` — 명시적 semver `MAJOR.MINOR.PATCH+BUILD`(App Store 마케팅 버전 = `1.0.0`, `1.0` 아님; 빌드 단계에서 업로드마다 `+BUILD`를 증가시킨다)

`dependencies`에 추가한다(최신 호환 버전 사용; 최소 버전 표시):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.37.0
  flame_audio: ^2.0.0
  google_mobile_ads: ^5.0.0
  shared_preferences: ^2.0.0
  flutter_secure_storage: ^9.0.0      # 영구 저장: iOS Keychain (재설치/기기 변경 후에도 유지)
  play_services_block_store: ^0.8.0   # 영구 저장: Android Block Store (재설치/기기 변경 후에도 유지)
```

`dev_dependencies`에 추가한다(`image`는 `tool/gen_icon.dart` + `tool/strip_bg.dart`에서 사용):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  image: ^4.0.0
  flutter_launcher_icons: ^0.14.0
  flutter_native_splash: ^2.4.0
```

`flutter:`에 에셋 디렉토리를 추가한다:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/audio/
    - assets/icons/
```

`flutter pub get`을 실행하고 종료 코드 0임을 확인한다.

### 5a.4 lib/ 디렉토리 구조 생성

다음 디렉토리를 생성한다(`assets/` 디렉토리 포함):

```
lib/
  game/
    components/
    systems/
    data/
  screens/
  ui/
  l10n/
assets/
  images/
  audio/
  icons/
```

이 구조는 PRD의 `lib/` 레이아웃과 일치한다.

### 5a.5 game_config.dart — 모든 튜닝 상수

`lib/game/game_config.dart`를 생성한다. 이 파일은 게임플레이에 영향을 미치는 모든 튜닝 상수(속도, 스폰 속도, 점수, 타이밍, 물리)를 중앙화해야 한다. 다른 게임 파일에서는 매직 넘버가 허용되지 않는다 — 모든 값은 `GameConfig`의 상수를 참조해야 한다.

템플릿:

```dart
// lib/game/game_config.dart
// <app_name>의 모든 튜닝 상수. 게임플레이를 조정하려면 여기를 수정하라 —
// 다른 곳에 숫자를 하드코딩하지 마라.

abstract class GameConfig {
  // 화면 / 월드
  static const double worldWidth  = 360.0;
  static const double worldHeight = 640.0;

  // 플레이어
  static const double playerSpeed     = 200.0;
  static const double playerJumpForce = 500.0;

  // 점수
  static const int scorePerEnemy    = 10;
  static const int scorePerDistance = 1;

  // 난이도
  static const double initialSpawnInterval = 2.0;   // 초
  static const double minSpawnInterval     = 0.4;
  static const double difficultyRampRate   = 0.02;  // 초당

  // 오디오
  static const double bgmVolume = 0.6;
  static const double sfxVolume = 0.9;

  // AdMob (자격증명이 아닌 튜닝 전용 — ID는 config.md에서 가져옴)
  static const int adShowIntervalSeconds = 120;
}
```

PRD의 게임 메커니즘 섹션에서 모든 값을 채운다. 필요에 따라 상수를 추가하고, 특정 게임에서 사용하지 않는 것은 제거한다.

### 5a.6 GameState enum

`lib/game/game_state.dart`를 생성한다:

```dart
// lib/game/game_state.dart
enum GameState {
  menu,
  playing,
  paused,
  gameOver,
  // PRD가 요구하는 상태 추가 (예: levelComplete, shop)
}
```

### 5a.7 FlameGame 서브클래스

`lib/game/<app_slug>_game.dart`를 생성한다. 이것은 루트 `FlameGame`(또는 PRD가 충돌 감지를 요구할 때 `HasCollisionDetection`을 적용한 `FlameGame`)이다. 제거된 `HasTappables` 믹신을 추가하지 말 것 — Flame 1.7에서 삭제되었으며 컴파일 오류를 유발한다. 탭 입력은 개별 컴포넌트의 `TapCallbacks`로 처리한다(§5a.8 참조). 다음을 충족해야 한다:

- `GameState _state = GameState.menu;`와 getter `GameState get state`를 선언한다.
- `_state`를 전이하고 이름으로 Flutter 오버레이를 표시/숨기는 `void startGame()`, `void pauseGame()`, `void resumeGame()`, `void gameOver()` 메서드를 노출한다.
- `onLoad()`를 오버라이드하여 에셋을 로드하고 배경 컴포넌트를 추가한다(`super.onLoad()`를 먼저 호출한다).
- 스크린에 필요한 모든 오버레이 이름을 등록한다(예: `'menu'`, `'hud'`, `'pause'`, `'gameOver'`).
- **성능(`docs/harness/game-gotchas.md` 참조):** 컴포넌트들이 매 프레임마다 동료를 쿼리해야 한다면, 게임 루트의 `update(dt)`에서 활성 목록을 **한 번** 계산하고 컴포넌트들이 그 캐시를 읽게 한다 — 컴포넌트별·프레임별 `world.children.whereType<X>()`를 절대 호출하지 않는다. `static final Paint` 객체를 재사용하고, 매 프레임마다 `Paint`/셰이더/블러를 재생성하지 않는다.

### 5a.8 입력 처리

PRD에 지정된 입력 방식을 연결한다:

- 탭/클릭 → 플레이어 컴포넌트에 `TapCallbacks` 믹신(모바일에 선호).
- 드래그 → `DragCallbacks` 믹신.
- 키보드 → 게임 클래스에 `KeyboardEvents` 믹신.

### 5a.9 main.dart 진입점

`lib/main.dart`를 생성한다:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/<app_slug>_game.dart';
// 5c에서 오버레이 스크린 임포트

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // config.md의 `orientation`에 맞게 잠금 — 세로 또는 가로, 양쪽 모두 허용하지 않음.
  // (네이티브 잠금도 §5c.10에서 설정하므로 실행 시 회전 깜빡임이 없다.)
  await SystemChrome.setPreferredOrientations(
    // 세로 → [portraitUp, portraitDown]; 가로 → [landscapeLeft, landscapeRight]
    <DeviceOrientation>[/* config.orientation에서 채울 것 */],
  );
  runApp(GameWidget(game: <AppSlugGame>()));
}
```

`<AppSlugGame>`을 실제 클래스 이름으로 교체한다.

**시작 순서 및 라이프사이클(필수 — `docs/harness/game-gotchas.md`의 Lifecycle 패턴 참조).** `main()`은 다음 순서로 실행해야 한다: `WidgetsFlutterBinding.ensureInitialized()` → `await SharedPreferences.getInstance()` (이후 동기 prefs 읽기가 동작하도록) → orientation → (광고 있으면) ATT-after-first-frame → UMP 동의 → `MobileAds.initialize()` → `runApp(...)`.

`GameWidget`을 `WidgetsBindingObserver`를 구현하는 `StatefulWidget`에 호스팅한다: `didChangeAppLifecycleState`에서 `paused`/`inactive` → `game.pauseEngine()` + BGM 일시정지; `resumed` → 재개. 게임의 `onDetach()`/`onRemove()`에서 정리한다(오디오 중지, 풀 해제, 타이머 취소). 재개 시 `_canInput` 플래그로 오래된 입력을 게이트한다.

### 5a.10 최소 통과 테스트

`test/game_config_test.dart`를 생성한다:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:<app_slug>/game/game_config.dart';

void main() {
  test('GameConfig constants are positive', () {
    expect(GameConfig.worldWidth,  greaterThan(0));
    expect(GameConfig.worldHeight, greaterThan(0));
    expect(GameConfig.bgmVolume,   inInclusiveRange(0.0, 1.0));
    expect(GameConfig.sfxVolume,   inInclusiveRange(0.0, 1.0));
  });
}
```

### 5a.11 CI 워크플로우

이 스킬 디렉토리의 `templates/ci.yml.template`을 `.github/workflows/ci.yml`로 복사한다(GitHub Actions: push/PR 시 `flutter analyze --no-fatal-infos` + `flutter test` 실행). 출시된 게임들의 CI를 그대로 반영한다.

### 5a HARD GATE

5a.1–5a.11 완료 후, 두 명령을 실행하고 Sub-phase 5b로 진행하기 전에 모두 종료 코드 0임을 확인한다:

```bash
cd <project_root>/<app_slug>
flutter analyze
flutter test
```

`flutter analyze`는 **0개 이슈**를 보고해야 한다. `flutter test`는 **0개 실패**를 보고해야 한다.

**어느 하나라도 실패하면, 모든 보고된 이슈를 수정한 후 진행한다. 이 게이트가 통과될 때까지 5b를 시작하지 않는다.**

---

## Sub-phase 5b — 시스템과 컴포넌트

Sub-phase 5b는 PRD에 지정된 모든 게임 엔티티, 시스템, 데이터 카탈로그를 구현한다. 5a HARD GATE 통과 후에만 시작한다.

### 5b.1 Player 컴포넌트

`lib/game/components/player_component.dart`를 생성한다. 플레이어 컴포넌트는 다음을 충족해야 한다:

- `SpriteAnimationComponent`(또는 정적 스프라이트의 경우 `SpriteComponent`)를 확장한다.
- 5a.8의 입력 콜백을 구현한다.
- 속도, 점프력, 기타 튜닝 가능한 값에 `GameConfig`의 상수를 사용한다.
- PRD가 요구하면 충돌 감지용 히트박스를 포함한다.

### 5b.2 적/장애물 컴포넌트

PRD에 명명된 각 적 또는 장애물 유형에 대해 `lib/game/components/` 아래에 별도 파일을 생성한다. 각 컴포넌트:

- `SpriteAnimationComponent` 또는 `SpriteComponent`를 확장한다.
- 속도 및 행동 파라미터에 `GameConfig` 상수를 사용한다.
- 충돌 시 콜백을 호출한다.

### 5b.3 스폰 시스템

`lib/game/systems/spawn_system.dart`를 생성한다. 이 시스템은:

- `GameConfig`에서 스폰 간격 및 난이도 파라미터를 읽는다.
- PRD에 정의된 난이도 램프를 구현한다(시간이 지남에 따라 스폰 속도 증가).
- `add(SpawnSystem())`으로 게임 클래스에 등록된다.
- 데이터 카탈로그(5b.6 참조)에서 엔티티 정의를 가져온다.

### 5b.4 충돌 시스템

`lib/game/systems/collision_system.dart`를 생성한다(또는 더 간단하면 각 컴포넌트의 `CollisionCallbacks`로 통합). 처리 사항:

- 플레이어 vs 적/장애물: PRD가 지정하는 대로 게임 오버 또는 체력 감소를 트리거한다.
- 플레이어 vs 수집품: 점수를 증가시키고 SFX를 재생한다.

### 5b.5 점수 시스템

`lib/game/systems/score_system.dart`를 생성한다. 이 시스템은:

- 현재 점수를 `int`로 유지한다.
- `void addScore(int points)`와 `int get score`를 노출한다.
- 점수가 변경될 때 HUD가 업데이트할 수 있도록 콜백 또는 `ValueNotifier` 업데이트를 발생시킨다.
- `shared_preferences`를 통해 최고 점수를 유지한다(키: `highScore`).

### 5b.6 오디오 시스템

**오디오 에셋(기본값 = 코드 합성 — 게임이 항상 소리와 함께 출시됨).** 이 스킬 디렉토리의 `templates/build_audio.dart.template`을 `tool/build_audio.dart`로 복사하고, 게임의 분위기에 맞게 음표/템포를 조정한 뒤, `dart run tool/build_audio.dart`를 실행하여 `assets/audio/*.wav`(22 kHz 모노 16비트, iOS 안전)를 생성한다. 디자인 에셋 계획이 실제 오디오를 소싱한 경우에는 그것을 사용한다(`docs/harness/game-gotchas.md`에 따라 WAV로 변환). 어느 경우든 게임은 존재하는 오디오 파일만 참조해야 한다.

`lib/game/systems/audio_system.dart`를 생성한다. `docs/harness/game-gotchas.md`의 **Audio** 패턴을 따른다(인용할 것; 재서술하지 않는다). 구체적으로 이 시스템은:

- `onLoad()`에서 각 **빈번한** SFX에 대해 `AudioPool`을 사전 워밍업한다(플레이어 1–3개); `playSfx(name)`은 `pool.start()`를 호출한다. 드문 일회성 SFX는 `FlameAudio.play()`를 사용할 수 있다.
- 반복되는 SFX를 제한한다(키당 ~70 ms)하여 버스트 끊김을 방지한다.
- 풀 생성과 모든 play/BGM 호출을 **try/catch**로 감싸고 `debugPrint`를 사용한다 — 누락되거나 잘못된 오디오 에셋은 절대 충돌을 유발해서는 안 된다; 재생은 조용히 건너뛴다.
- BGM: `playing` 상태에서만 `FlameAudio.bgm.play(...)`; 게임 오버, 앱 백그라운드, `onRemove()`/`onDetach()`에서 `FlameAudio.bgm.stop()`.
- `GameConfig`의 채널별 볼륨 상한(예: `bgmVolume`, `sfxVolume`은 안전 상한; 사용자 슬라이더는 상한의 분수)을 적용하고, `shared_preferences`의 음소거 토글(`bgmEnabled`, `sfxEnabled`)을 존중한다.

### 5b.6a 햅틱 시스템

`lib/systems/haptics.dart`를 생성한다 — `docs/harness/game-gotchas.md`의 **Haptics** 패턴에 따른 순수 Dart 햅틱 헬퍼. 게임플레이에서는 `HapticFeedback.*`을 직접 호출하지 않는다. 헬퍼:

- `!kIsWeb && (Platform.isIOS || Platform.isAndroid)`가 아니면 아무것도 하지 않는다.
- 전역 스로틀을 적용한다(~60 ms 최소 간격)하여 버스트가 모터를 연속 타격하지 않게 한다.
- 영속적인 `Haptics.enabled` 토글을 가지며, 모든 호출을 try/catch로 감싼다.
- `HapticFeedback`을 통해 의도 메서드(예: `light()`, `medium()`, `heavy()`)를 노출한다.

(햅틱이 많은 게임의 경우 선택 사항: 네이티브 iOS `UIImpactFeedbackGenerator` MethodChannel — `docs/harness/game-gotchas.md` 참조. 기본 Dart로도 충분하다.)

### 5b.7 난이도 시스템

`lib/game/systems/difficulty_system.dart`를 생성한다. 이 시스템은:

- 경과 플레이 시간을 추적한다.
- `GameConfig.difficultyRampRate`와 `GameConfig.minSpawnInterval`을 사용하여 스폰 간격과 적 속도를 업데이트한다.

### 5b.8 데이터 카탈로그

PRD가 정의하는 각 데이터 기반 요소(적, 레벨, 웨이브, 수집품, 상점 아이템)에 대해 `lib/game/data/` 아래에 데이터 파일을 생성한다. 각 카탈로그는 일반 데이터 객체의 Dart 목록이다. 스폰 또는 컴포넌트 로직에서 적/레벨/웨이브 값을 하드코딩하지 않는다 — 모든 값은 카탈로그에서 가져와야 한다.

### 5b.9 시스템 테스트

`test/` 아래에 다음에 대한 테스트를 추가한다:

- `ScoreSystem.addScore`가 올바르게 증가한다.
- `DifficultySystem`이 시간이 지남에 따라 스폰 속도를 증가시킨다.
- 데이터 카탈로그 항목이 비어 있지 않고 모든 숫자 필드가 양수다.

### 5b HARD GATE

5b.1–5b.9 완료 후, 실행한다:

```bash
cd <project_root>/<app_slug>
flutter analyze
flutter test
```

`flutter analyze`는 **0개 이슈**를 보고해야 한다. `flutter test`는 **0개 실패**를 보고해야 한다.

**어느 하나라도 실패하면, 모든 보고된 이슈를 수정한 후 진행한다. 이 게이트가 통과될 때까지 5c를 시작하지 않는다.**

---

## Sub-phase 5c — UI, 콘텐츠, 폴리시

Sub-phase 5c는 모든 Flutter 스크린과 오버레이를 연결하고, l10n을 추가하고, 디자인 토큰을 적용하며, `shared_preferences` 영속성을 완성한다. 5b HARD GATE 통과 후에만 시작한다.

### 5c.1 디자인 토큰

디자인 문서의 `## Design tokens` 섹션에서 `lib/ui/design_tokens.dart`를 생성한다(디자인 문서에 지정된 정확한 파일 템플릿 사용). 모든 색상, 간격, 반경 값은 이 파일에서 가져와야 한다 — UI 코드에 원시 16진수 또는 숫자 리터럴을 사용하지 않는다.

### 5c.2 Flutter 스크린과 오버레이

PRD가 요구하는 각 스크린에 대해 `lib/screens/` 아래에 파일을 생성한다. 각 스크린은 게임 인스턴스를 받아 상태 전이 메서드를 호출하는 `StatefulWidget` 또는 `StatelessWidget`이다. 필요한 스크린(PRD 기준으로 추가 또는 제거):

| 파일 | 오버레이 이름 | 트리거 |
|---|---|---|
| `lib/screens/main_menu_screen.dart` | `'menu'` | 게임 시작 |
| `lib/screens/hud_screen.dart` | `'hud'` | 게임 중 |
| `lib/screens/pause_screen.dart` | `'pause'` | 일시정지 버튼 탭 |
| `lib/screens/game_over_screen.dart` | `'gameOver'` | 플레이어 사망 |
| `lib/screens/settings_screen.dart` | `'settings'` | 설정 버튼 |

PRD가 상점을 정의하면 `lib/screens/shop_screen.dart`를 추가한다(오버레이 이름 `'shop'`).

`main.dart`의 `GameWidget.overlayBuilderMap`에 모든 오버레이 빌더 함수를 등록한다.

### 5c.3 HUD 위젯

`lib/ui/hud.dart`를 생성한다(Flame 컴포넌트가 아닌 Flutter 위젯 오버레이). HUD는 현재 점수, 체력 또는 목숨(PRD가 정의한 경우), 일시정지 버튼을 표시해야 한다. 모든 크기와 색상은 `DesignTokens` 상수를 사용한다.

### 5c.4 KO/EN 현지화

ARB 파일을 생성한다:

- `lib/l10n/app_<default_language>.arb` — 주 언어 문자열(`default_language`); `default_language`가 `en`이 아닐 때 `app_en.arb`를 보조 로케일로 추가한다.
- `lib/l10n/app_en.arb` — 영어 문자열.

모든 스크린과 오버레이의 모든 사용자 표시 문자열은 ARB 항목을 가져야 한다. 위젯 코드에서 문자열 리터럴을 사용하지 않는다 — `AppLocalizations.of(context).<key>`를 사용한다.

`pubspec.yaml`에 추가한다:

```yaml
flutter:
  generate: true

dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

l10n이 완전한지 검증한다:

```bash
cd <project_root>/<app_slug>
flutter gen-l10n
```

### 5c.5 영속성 — 재설치·기기 변경 후에도 생존하는 영구 저장(기본 ON)

최고 점수, BGM/SFX 활성화 플래그, 경제 관련 총합을 단일 `PreferencesService` 클래스를 통해 영속화한다. 해당 클래스 외부에서 원시 `SharedPreferences` 호출을 하지 않는다.

영속성은 **기본적으로 영구** — 저장이 앱 재설치 *및* 새 기기로의 이전 후에도 생존한다(`shared_preferences`는 iOS에서 삭제 시 사라짐). 출시된 게임들의 검증된 패턴을 적용한다(R9 — `docs/harness/game-gotchas.md` 참조):

1. 이 스킬 디렉토리의 `templates/save_repository.dart.template`을 `lib/data/save_repository.dart`로 복사하고, `__SAVE_KEY__`를 `<app_slug_snake_case>_save_v1`로 교체한다. 세 가지 계층에 걸쳐 하나의 JSON 블롭을 저장한다 — **iOS Keychain**(`flutter_secure_storage`, `first_unlock`), **Android Block Store**(`play_services_block_store`), **`shared_preferences` 미러** — 영구 저장을 우선 읽고, 모든 계층에 쓰며, 모든 호출은 try/catch로 감싸 백엔드 실패 시 크래시 대신 저하된다.
2. `PreferencesService`는 `SaveRepository`로 지원된다: 시작 시 `readMap()`을 한 번 로드하여 인메모리 맵으로; 각 세터는 맵을 변경하고 `SaveRepository.write(jsonEncode(map))`를 쓴다. 모든 게터/세터는 이를 통한다 — 다른 곳에서 원시 `SharedPreferences` 및 직접 `SaveRepository` 호출 없음.

이것은 실시간 클라우드 동기화가 아님 — 새 설치/기기에서의 last-write-wins 복원이다. `docs/harness/game-gotchas.md`(Persistence) 참조.

### 5c.6 AdMob 연결(config.md의 skip_admob이 false인 경우)

`skip_admob`이 `false`이면:

- `main.dart`에서 `runApp` 이전에 `MobileAds.instance.initialize()`를 초기화한다.
- AdMob 앱 ID와 광고 단위 ID를 `config.md`에서 읽는다 — Dart 소스에 절대 하드코딩하지 않는다.
- `lib/ui/banner_ad_widget.dart`에 배너 광고 위젯을 구현한다.
- HUD 오버레이 하단에 배너를 표시한다.

### 5c.7 스텁 방지 검증

최종 HARD GATE 이전에 실행한다:

```bash
grep -rn "TODO\|stub\|placeholder\|스텁\|미구현" \
  <project_root>/<app_slug>/lib/ --include="*.dart"
```

이 명령이 출력을 반환하면, 모든 일치 항목을 수정하거나 제거한다. 계약은 게임 로직에서 0개의 스텁을 요구한다(`docs/harness/protocol.md` §3, Hard Gate 3 기준).

### 5c.8 전체 테스트

다음을 커버하는 테스트를 추가하거나 확장한다:

- 메인 메뉴가 예외 없이 렌더링된다.
- 게임 오버 스크린이 올바른 점수를 표시한다.
- 현지화: 모든 설정된 `app_<locale>.arb`에 필요한 ARB 키가 있다(`default_language`, 그리고 `default_language`가 `en`이 아니면 `app_en.arb`).
- `PreferencesService` 읽기/쓰기 왕복(mock `SharedPreferences` 사용).

### 5c.9 앱 브랜딩 — 아이콘 · 스플래시 · 표시 이름

출시된 게임은 기본 Flutter 아이콘, 기본 스플래시, 슬러그 같은 이름을 가져서는 안 된다. `docs/harness/game-gotchas.md`의 **Build/platform** + **Store rejections** 패턴을 따른다.

1. **아이콘 + 스플래시 아트.** 기본값: 이 스킬 디렉토리의 `templates/gen_icon.dart.template`을 `tool/gen_icon.dart`로 복사하고, `design_tokens`(Background / Primary / Accent RGB)의 색상 상수를 채우고 `kGlyph`를 `app_name`의 첫 글자로 설정하고, `dev_dependencies`에 `image: ^4.0.0`을 추가한 다음, `dart run tool/gen_icon.dart`를 실행한다 → `assets/icons/icon.png`(1024×1024, **불투명/알파 없음**), `assets/images/splash.png`, **`assets/store/play_icon.png`(512×512 Play 고해상도 아이콘)**, **`assets/store/feature_graphic.png`(1024×500 Play 기능 그래픽)**을 생성한다. 스크린샷 단계가 마지막 두 개를 Android 목록에 배치한다. 디자인 에셋 계획이 AI 생성 아트를 선택했다면, 해당 이미지를 `assets/icons/icon.png`에 **불투명**하게(알파 없음) 평탄화하여 사용한다.
2. **도구 설정 및 실행.** `flutter_launcher_icons`(`remove_alpha_ios: true`, `image_path: assets/icons/icon.png` 포함) 및 `flutter_native_splash`(`color:` = 디자인 Background, `image: assets/images/splash.png`) 블록을 `pubspec.yaml`에 추가한 다음 실행한다:
   ```bash
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```
3. **현지화된 표시 이름.** `app_name`을 홈 화면 이름으로 설정한다: iOS `CFBundleDisplayName`(기본 `Info.plist` + 로케일별 `<locale>.lproj/InfoPlist.strings`, Xcode 프로젝트에 등록); Android `android:label="@string/app_name"` + `values/strings.xml`(+ `default_language`와 영어에 대한 `values-<locale>/strings.xml`). "Runner" 또는 슬러그가 아님.

### 5c.10 네이티브 플랫폼 설정

`docs/harness/game-gotchas.md`(Build/platform + Store rejections)에 따라 적용한다:

1. **방향 잠금(네이티브 — 사용하지 않는 방향 제거).** `config.orientation`을 읽는다.
   - iOS `Info.plist` `UISupportedInterfaceOrientations` = 선택한 집합만(세로 → `UIInterfaceOrientationPortrait`; 가로 → `…LandscapeLeft` + `…LandscapeRight`), 그리고 `UISupportedInterfaceOrientations~ipad`를 **제거**한다.
   - Android: 메인 `<activity>`에서 `android:screenOrientation="portrait"`(또는 가로의 경우 `"sensorLandscape"`)을 설정한다.
   이렇게 하면 다른 방향이 완전히 제거되어 앱이 그 방향으로 바로 열린다(`main.dart`의 `setPreferredOrientations`만으로는 충분하지 않다).
2. **iPadOS 제거.** `ios/Runner.xcodeproj`에서 `TARGETED_DEVICE_FAMILY = 1`을 설정한다(iPhone 전용, 양쪽 빌드 구성 모두).
3. **내보내기 규정 준수.** `ios/Runner/Info.plist`에 `ITSAppUsesNonExemptEncryption = false`를 추가한다(업로드마다 나오는 내보내기 규정 준수 프롬프트를 건너뜀).
4. **루트 뒤로 버튼(Android).** 루트/메뉴 스크린을 `PopScope(canPop: false, ...)`로 감싼다: 오버레이가 열려 있으면 닫고; 그렇지 않으면 Flutter `SnackBar`를 표시하고("뒤로 한 번 더 누르면 종료" / "Press back again to exit", 현지화됨), ~2초 내에 두 번째 뒤로를 눌러야만 종료한다. (게임 중 뒤로 = 일시정지 — game-gotchas 참조.)

### 5c.11 게임 에셋(비주얼)

기본값: **코드 드로잉 비주얼** — `design_tokens` 팔레트를 사용하는 `CustomPainter` / Flame 도형으로 플레이어/적/UI를 렌더링한다(외부 이미지 파일 0개, 항상 렌더링됨). 디자인 에셋 계획이 **스프라이트 아트**(AI 생성 또는 무료/CC0 팩)를 선택한 경우에만: 이미지를 구하고, `templates/strip_bg.dart.template`에서 복사한 `tool/strip_bg.dart`를 실행하여 배경을 알파로 플러드 채우고, 정리된 PNG를 `assets/images/` 아래에 배치한다. **코드 또는 `pubspec.yaml`에서 선언된 모든 에셋 경로는 디스크에 존재해야 한다** — 끊어진 참조 없음(누락된 에셋은 런타임 크래시 / 빈 화면). 하네스는 미소싱 아트에 의존하지 않는다: 아무것도 소싱되지 않았다면, 게임은 완전히 코드 드로잉으로 출시된다.

### 5c HARD GATE

5c.1–5c.11 완료 후, 실행한다:

```bash
cd <project_root>/<app_slug>
flutter analyze
flutter test
```

`flutter analyze`는 **0개 이슈**를 보고해야 한다. `flutter test`는 **0개 실패**를 보고해야 한다. 또한 브랜딩(5c.9)을 확인한다: **커스텀** 아이콘 + 스플래시가 생성되었고(기본 Flutter 아트 아님), 아이콘이 **불투명(알파 없음)**이고, 네이티브 표시 이름이 `app_name`과 같은지(Runner/슬러그 아님). 그리고 네이티브 설정(5c.10): 방향이 `config.orientation`에 맞게 네이티브로 잠겨 있고(미사용 방향 제거), iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`), `ITSAppUsesNonExemptEncryption = false`, 루트 뒤로 버튼 SnackBar. 그리고 에셋/CI(5b.6 / 5c.11 / 5a.11): 게임은 **합성(또는 소싱된) 오디오**와 **코드 드로잉(또는 정리된 스프라이트) 비주얼**, **누락된 에셋 참조 없음**, `.github/workflows/ci.yml` 존재와 함께 출시된다.

**이것이 최종 게이트다. 두 명령이 모두 통과될 때까지 handoff를 작성하지 않는다. 어느 하나라도 실패하면, 보고된 모든 이슈를 수정하고 두 명령을 다시 실행한다.**

---

## 자체 평가 및 핸드오프

5c HARD GATE 통과 후, 생성기 핸드오프를 작성하고 파이프라인 상태를 업데이트한다.

### handoff/round-N-gen.md 작성

`docs/harness/protocol.md` §4에 정의된 레이아웃에 따라 게임 프로젝트 내부의 `docs/harness/handoff/round-<N>-gen.md`를 생성한다:

```markdown
# Generator Handoff — Round <N>

## What Was Built / Fixed

<!-- 구현된 기능(라운드 1) 또는 수정된 버그(라운드 N>1)의 글머리 목록. -->

## Contract Self-Assessment

| Criterion | Status | Notes |
|---|---|---|
| flutter analyze zero errors          | DONE / PARTIAL / FAIL | … |
| flutter test zero failures           | DONE / PARTIAL / FAIL | … |
| No TODO/stub in game logic           | DONE / PARTIAL / FAIL | … |
| game_config.dart for all tuning      | DONE / PARTIAL / FAIL | … |
| Content defined as data              | DONE / PARTIAL / FAIL | … |
| l10n complete (all configured locales) | DONE / PARTIAL / FAIL | … |
| Core loop end-to-end                 | DONE / PARTIAL / FAIL | … |
| Zero crashes on simulator            | DONE / PARTIAL / FAIL | … |
| <game-specific criterion>            | DONE / PARTIAL / FAIL | … |

## Test Results

\`\`\`
<flutter analyze 출력의 마지막 20줄>
\`\`\`

\`\`\`
<flutter test 출력의 마지막 20줄>
\`\`\`

## Environment Detection

- Flutter version: <`flutter --version` 출력>
- Dart version: <위에서>
- Device/emulator used for smoke test: <이름>

## Known Issues

<!-- 알려진 이슈 또는 지연된 항목을 나열한다. 깨끗하면 "none"으로 표시. -->
```

모든 섹션을 실제 출력과 실제 평가로 채운다. 자리 표시자 텍스트를 남기지 않는다.

### state.md 업데이트

`docs/harness/protocol.md` §2와 §7의 `generator → evaluator` 전이에 따라 `docs/harness/state.md`를 업데이트한다. §7 규칙 2에 따라, 성공적인 단계 완료는 동일한 원자적 쓰기에서 `status: running`을 설정한다:

```yaml
status: running
current_phase: generator
next_role: evaluator
updated_at: "<ISO-8601 UTC now>"
```

`current_round`, `created_at`, `resume_attempts`, 기타 모든 키는 변경하지 않는다. 타겟 업데이트에는 `Edit`을 사용한다.

> **참고:** `current_round`는 evaluator가 FAIL을 반환할 때 증가시킨다; generator는 읽기만 하고 쓰지 않는다.

### pipeline-log.md에 추가

`docs/harness/protocol.md` §6에 따라 `docs/harness/pipeline-log.md`에 한 행을 추가한다:

```
| <ISO-8601 UTC now> | handoff | generator | round <N> built; analyze 0; test 0; next: evaluator |
```

---

## 오류 처리

- `contract.md`가 없거나 `## Status: AGREED`를 포함하지 않으면 즉시 중단한다.
- HARD GATE가 실패하면(`flutter analyze` 이슈 또는 실패하는 테스트가 0이 아님), 해당 하위 단계에서 멈추고, 실패를 수정하고, 게이트를 다시 실행한다. 다음 하위 단계로 진행하지 않는다.
- 라운드 > 1에서 N-1 라운드의 피드백 파일이 없으면, 명확한 메시지와 함께 중단하고 `state.md`를 `status: paused`, `pause_reason: manual_action`으로 설정한다.
- `flutter create`가 실패하면, 즉시 중단하고 5a.3으로 진행하지 않는다.
- `flutter pub get`이 실패하면, 계속하기 전에 버전 충돌에 대해 `pubspec.yaml`을 확인하고 해결한다.
