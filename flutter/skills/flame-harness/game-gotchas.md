# Game Gotchas — 필수 견고성 패턴

Flutter/Flame 게임을 실제 출시하며 얻은 교훈들이다. **제너레이터는 이 패턴들을 반드시 emit**해야 하고, **contract는 이것들을 require**해야 하며, **evaluator는 이것들을 verify**해야 한다 — 이미 해결된 문제들이 생성된 게임에서 조용히 회귀하지 않도록. 이 파일을 인용하라(DRY). 스킬은 이 내용을 재서술하지 않는다.

보편 규칙: **모든 플랫폼 호출(audio, haptics, 광고, persistence, method channel)은 try/catch로 감싸고, `debugPrint`로 로깅하며, 절대 rethrow하지 않는다.** 누락된 에셋/기능은 gracefully degrade된다(무음 오디오, no-op haptic, fallback 사각형) — 게임은 플레이 가능 상태를 유지해야 한다.

---

## Audio

- **빈번한 SFX → `AudioPool`, `FlameAudio.play()` 아님.** `FlameAudio.play()`는 호출마다 새 네이티브 플레이어를 할당해(platform-channel + allocation), 연속 이벤트(코인, 발사, 충격) 시 프레임 끊김을 유발한다. 빈번한 SFX마다 `onLoad()`에서 `AudioPool`을 미리 워밍(플레이어 1–3개)하고 `pool.start()`로 재생한다. 드문 일회성 이벤트(게임오버, 파워업)는 `FlameAudio.play()`를 그대로 써도 된다.
- **빠른 반복 재생 스로틀** (~70 ms): `Map<String,double> _lastPlayed`를 유지하고 해당 키가 윈도우 내에서 이미 발화됐으면 건너뛴다. 연속 버스트를 안정적인 클릭 소리 하나로 접는다.
- **Graceful fallback**: pool 생성과 모든 재생을 try/catch로 감싼다. 에셋이 없으면 pool을 null로 표시하고 재생을 skip한다. 잘못된/오타난 오디오 경로에서 절대 크래시하지 않는다(릴리즈에서 hard fail).
- **BGM 라이프사이클**: BGM은 `playing` 상태에서만 시작한다(메뉴/일시정지 상태 아님). 게임오버 시, 앱 백그라운드 시, `onRemove()`/`onDetach()` 시 `FlameAudio.bgm.stop()`을 호출한다 — 이전 플레이 세션의 BGM이 메뉴나 종료 후에 누출되면 안 된다.
- **볼륨 상한**: 채널별 상한을 정의한다(예: BGM ≤ 0.2, SFX ≤ 0.7). 사용자 슬라이더는 상한의 분율이므로 100% = 안전한 레벨이지, 귀를 쩌렁하게 만드는 볼륨이 아니다.
- **iOS 오디오 포맷**: iOS는 OGG를 안정적으로 재생하지 못한다. OGG/MP3 → 22 kHz 모노 16-bit WAV로 변환(`ffmpeg -i in.ogg -ac 1 -ar 22050 -sample_fmt s16 out.wav`)하고 WAV를 번들한다.

## Haptics

- **`Haptics` 시스템 제공** (`lib/systems/haptics.dart`). 게임플레이 코드에서 `HapticFeedback.*`을 직접 호출하지 않는다. 이 시스템은 다음을 갖춰야 한다:
  - **플랫폼 가드**: `!kIsWeb && (Platform.isIOS || Platform.isAndroid)`가 아니면 no-op.
  - **스로틀** (~60 ms 전역 최소 간격) — 그렇지 않으면 버스트가 진동 모터를 기관총처럼 두드린다.
  - **`enabled` 토글** (prefs에 영속화)하여 사용자가 끌 수 있게 한다.
  - **try/catch** 모든 호출 (에뮬레이터/미지원 기기에서 throw함).
- **iOS 최적화 (haptic-heavy 게임용, 선택)**: `AppDelegate.swift`의 네이티브 MethodChannel에 준비된 `UIImpactFeedbackGenerator` 인스턴스(light/medium/heavy)를 보유하면, 이벤트마다 generator를 생성하는 5–10 ms 메인 스레드 스톨을 피할 수 있다. 대부분의 게임은 Dart `HapticFeedback` 베이스라인 + 스로틀로 충분하다. 이 방법은 업그레이드 경로로 문서화한다.

## 앱 라이프사이클 / 일시정지-재개 / 콜드 스타트

- **백그라운드 = 일시정지**: 앱 호스트 위젯이 `WidgetsBindingObserver`를 구현한다. `AppLifecycleState.paused`/`inactive` 시 `game.pauseEngine()` + BGM 일시정지 호출. `resumed` 시 역으로 복구. 배터리 소모, 백그라운드 BGM, 놓친 일시정지를 방지한다.
- **테어다운 정리**: `onDetach()`/`dispose()`에서 오디오를 정지하고, pool을 dispose하며, 타이머/스트림을 취소한다. 테어다운 중에 game/engine 상태에 다시 접근하지 않는다.
- **재개 시 낡은 입력**: `_canInput` 플래그로 입력을 게이트(일시정지 중 false)하여 일시정지 오버레이의 탭이 재개 시 게임플레이로 흘러들어가지 않도록 한다.
- **콜드 스타트 순서**: 먼저 `super.onLoad()`를 호출한다. 컴포넌트 트리가 마운트되기 전에 피어에 접근하지 않는다. Android `MainActivity`는 콜드 스타트 시 NullPointerException을 피하기 위해 `super.onCreate()` 전에 FlameGame을 init해야 한다.
- **`main()`의 시작 시퀀스**: `WidgetsFlutterBinding.ensureInitialized()` → `await SharedPreferences.getInstance()` (동기 prefs 읽기가 동작하도록) → ATT (첫 프레임/포그라운드 이후) → UMP 동의 → `MobileAds.initialize()` → 오디오 프리로드 → `runApp()`. 동의가 완료되기 전에 광고를 요청해서는 안 된다.
- **ATT 프롬프트가 실제로 나타나야 함 (App Store 2.1)**: ATT 다이얼로그는 앱이 active/foregrounded 상태일 때만 나타난다. 최신 iOS에서 `main()`의 첫 프레임 전에 요청하면 조용히 no-op된다 → "NSUserTrackingUsageDescription이 있지만 알림이 나타나지 않음" 거절. 필수 패턴: **`WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed`가 될 때까지 대기**(최대 ~4초 폴링), **~400 ms settle 지연**, **`notDetermined`일 때만 요청** — post-frame callback에서, **광고 init 전에** await. 프롬프트 텍스트를 현지화한다(locale별 `InfoPlist.strings`).
- **Android 하드웨어 뒤로가기 버튼**: 앱을 `PopScope`로 감싼다 — 뒤로가기로 열린 오버레이를 닫고, (게임 중이면) 일시정지하고, (**루트/메뉴**에서) Flutter `SnackBar`("press back again to exit")를 보여주고, ~2초 내 두 번째 뒤로가기에서만 종료한다. 단 한 번의 뒤로가기로 게임 중에 앱이 종료되면 안 된다.
- **네이티브에서 하나의 방향으로 잠금** — 세로 또는 가로를 결정하고 `Info.plist` `UISupportedInterfaceOrientations`에서 잠근다(`~ipad` 변형 제거) + Android `android:screenOrientation`. `SystemChrome.setPreferredOrientations`만으로는 앱이 잘못된 방향으로 열렸다가 회전하는 현상이 여전히 발생한다(눈에 보이는 시작 깜빡임). 사용하지 않는 방향을 네이티브에서 제거하면 이를 방지할 수 있다.
- **새 플레이 시 모든 런 상태 초기화** — 점수/이펙트/스폰/타이머를 초기화하여 이전 런의 내용이 다음 런으로 누출되지 않게 한다("재시도 시 이상한 상태"의 흔한 원인).

## Input & UI

- **iOS 엣지 제스처 충돌**: 풀스크린 드래그/조이스틱 게임은 iOS 시스템 스와이프를 트리거한다. `SystemChrome.setEnabledSystemUIMode` / `preferredScreenEdgesDeferringSystemGestures`로 지연시켜 플레이어의 엣지 스와이프가 Control Center 내리기나 뒤로가기를 트리거하지 않도록 한다.
- **SafeArea + 반응형 HUD**: 모든 오버레이/HUD를 `SafeArea`로 감싼다. `LayoutBuilder`/max-width로 바/다이얼로그 너비를 제한하여 노치나 가로 모드에서 클립되거나 늘어나지 않도록 한다.
- **스플래시/전환 중 입력 차단**: 엉뚱한 탭이 게임플레이로 흘러들어가지 않도록 한다.

## Performance

- **핫 패스에서 per-frame `whereType` 금지**: 컴포넌트마다 프레임마다 `world.children.whereType<X>()`를 계산하면 O(n²)이고 GC 부담이 크다. 게임 루트의 `update(dt)`에서 프레임당 한 번 활성 목록을 계산하고 컴포넌트는 캐시를 읽게 한다.
- **`Paint`/shader 캐시**: `static final Paint`를 재사용한다(그래디언트/블러 프리셋 포함). 프레임마다 `Paint`/`createShader`/`MaskFilter.blur`를 재생성하지 않는다. 재사용된 Paint에서 색상만 교체한다.
- **정적 텍스트를 매 프레임 재빌드하지 않기**: `TextPaint`를 캐시하고 값이 바뀔 때만 HUD 텍스트를 재빌드한다.

## Build / 플랫폼

- **번들 id는 두 플랫폼에서 동일** — iOS `PRODUCT_BUNDLE_IDENTIFIER`(모든 빌드 구성) == Android `applicationId` + `namespace` == `config.bundle_id`, 바이트 단위 동일(소문자 `[a-z0-9.]`, `_`/`-`/대문자 없음). `flutter create`는 프로젝트 이름에서 id를 도출하며 언더스코어/대소문자가 남거나 플랫폼 간 다를 수 있다 — 양쪽에서 명시적으로 설정한다. AdMob + 스토어 레코드는 이 정확한 문자열을 사용한다.
- **Android `minSdk = 23`** — `google_mobile_ads`는 API 23+가 필요하다. 더 낮으면 시작 시 실패한다.
- **iOS `Podfile` platform**: `platform :ios, '<x>'`를 가장 높은 플러그인 요구사항으로 올린다. 그렇지 않으면 `pod install`이 실패한다.
- **`Info.plist`**: `NSUserTrackingUsageDescription`(ATT)과 `SKAdNetworkItems`(Google 목록)는 광고 빌드가 App Store 심사를 통과하기 위해 필수다.
- **iOS `PrivacyInfo.xcprivacy` (iOS 17+)**: Privacy Manifest를 포함하고 Xcode 프로젝트에 등록한다. 그렇지 않으면 App Store Connect가 업로드를 거절한다. 필수 이유 API(UserDefaults, 파일 타임스탬프 등)에 대한 이유를 선언한다.
- **Android core library desugaring**: `android/app/build.gradle.kts`에서 `coreLibraryDesugaring`을 활성화한다(일부 플러그인, 예: notifications가 필요로 함). 그렇지 않으면 빌드가 실패한다.
- **현지화된 앱 표시 이름**: 로케일별로 스토어/홈 화면 이름을 설정한다 — iOS `<locale>.lproj/InfoPlist.strings` (`CFBundleDisplayName`), Android 로케일별 `strings.xml`.
- **아이콘 + 스플래시 + 인앱 로고는 하나의 shared painter에서**: 시각적 일관성을 위해. 네이티브 스플래시 `color`는 인앱 스플래시 배경과 일치해야 한다(그렇지 않으면 시작 시 색상 깜빡임). iOS 아이콘은 불투명해야 한다(알파 없음). `flutter_launcher_icons: remove_alpha_ios: true`.
- **에셋 경로 소문자**: Android/Linux는 대소문자를 구분한다. `assets/**` 이름을 소문자로 유지하고 `pubspec.yaml`에 디렉토리(후행 슬래시)를 선언한다.
- **에셋을 항상 번들과 함께 출시(수동 소싱 불필요)**: 오디오는 기본적으로 **코드 합성** WAV(`tool/build_audio.dart`)로 출시하여 게임이 무음이 되지 않게 한다. 비주얼은 기본적으로 **코드 드로잉**(`CustomPainter`/Flame shapes). 소싱된 스프라이트(CC0/AI)는 선택사항이며 배경을 알파로 flood-fill한다(`tool/strip_bg.dart`). 코드/`pubspec.yaml`에서 참조된 모든 에셋은 반드시 존재해야 한다 — 허상 참조는 런타임 크래시/공백이다.
- **CI를 처음부터 포함**: `.github/workflows/ci.yml`에서 push/PR 시 `flutter analyze --no-fatal-infos` + `flutter test`를 실행한다.

## 광고 (초기화 조율 — admob 스킬도 참조)

- **광고 SDK를 모바일 전용으로 게이트**: 웹/데스크톱에서 `MobileAds`를 init하거나 광고를 로드하지 않는다. `!kIsWeb && (Platform.isIOS || Platform.isAndroid)`로 가드한다. 그렇지 않으면 조용한 no-op/오류가 발생한다.
- **광고 매니저를 `MobileAds.initialize()`와 조율** — init이 완료되기 전에 광고를 요청하지 않는다(조용한 no-op). 디버그에서는 테스트 ID, 릴리즈에서는 실제 ID(config에서)를 사용한다.

## 스토어 스크린샷

- **스크린샷 모드 플래그** (`--dart-define=screenshots=true`): 캡처 중 광고, ATT 프롬프트, 오디오를 비활성화하여 프레임이 깔끔하게 나오도록 한다.
- **Android: Flutter 서피스를 이미지로 한 번만 변환** (샷마다 아님). 그렇지 않으면 다중 샷 캡처가 첫 프레임 이후 실패한다.

## Persistence

- **코인/점수 즉시 영속화**: 획득 시(또는 런 종료 시, 비동기 저장 전 동기적으로) prefs에 쓴다. 런 중간 크래시에서 진행 상황이 손실되지 않도록.
- **레거시 키 마이그레이션**: 한 번만 수행한다(예: 기존 int `high_score` → 새 JSON 프로필). 이후 기존 키를 삭제한다.

## 스토어 거절 (App Review) — 실제 발생한 사례

실제 App Store / Play 거절을 유발했으며 수정된 사례들이다. 처음부터 방지하라.

- **2.1 — ATT 프롬프트가 나타나지 않음** (여기서 가장 흔한 사례): *라이프사이클* 섹션의 ATT 패턴 참조(resumed 대기 + settle + notDetermined, post-frame, 광고 전). 심사 응답 시, 물리 기기에서 새로 설치 → ATT 프롬프트 등장 전 어떤 추적도 없음 → 이후 흐름을 보여주는 **화면 녹화**를 첨부하고 App Review Information → Notes에 넣는다.
- **알파 채널이 있는 앱 아이콘/스크린샷은 거절** — iOS 아이콘과 모든 스토어 스크린샷을 불투명 RGB로 평탄화한다(투명도 없음).
- **Play 리스팅은 hi-res 아이콘 (512×512) + feature graphic (1024×500)이 필요** — shared painter에서 둘 다(불투명) 생성하고 `android/fastlane/metadata/android/<locale>/images/icon.png` + `featureGraphic.png`에 배치하여 `supply`가 업로드하도록 한다. 없으면 Play 리스팅을 게시할 수 없다. (App Store는 feature graphic이 필요 없다.)
- **ASC는 중복 빌드 번호를 거절** — 매 업로드마다 빌드 번호를 올린다(`1`을 재사용하지 않는다).
- **매 업로드마다 수출 규정 준수 프롬프트** — 앱이 비면제 암호화를 사용하지 않으면 `Info.plist`에 `ITSAppUsesNonExemptEncryption = false`를 설정하여 향후 빌드에서 프롬프트를 건너뛴다.
- **AdMob "Publisher data not found" / 광고 없음** — 광고 단위의 publisher prefix가 AdMob 앱과 일치해야 하며, bundle id / package name이 AdMob에 등록된 것과 정확히 일치해야 한다(전파에 몇 분~몇 시간 소요될 수 있음).
- **4.1 / 4.3 모방작** — 유명 타이틀의 복제본으로 읽히는 실루엣/팔레트를 피한다(예: 클래식 녹색 파이프 + 횡스크롤 = Flappy 클론 플래그). 뚜렷한 시각/메카닉 요소를 추가한다.
- **알림 권한을 사용자가 이유를 이해하기 전에 자동으로 요청하지 않는다** (Apple/Play는 cold permission 프롬프트를 권장하지 않음).
- **스토어 리스팅 + App Review 정보가 채워져 있어야 함** (`config.md` developer block에서): 개인정보 정책 URL, 지원/마케팅 URL, copyright, App Review 연락처(이름, 전화, 이메일). iOS: `ios/fastlane/metadata/{copyright.txt,<locale>/support_url.txt,marketing_url.txt,privacy_url.txt,review_information/*}`에 써서 `deliver`가 업로드하도록 한다. Android: 연락처 이메일/웹사이트는 `supply` 필드가 없음 → Publisher API(`set_contact_details.rb`)로 설정. 개인정보 URL + Data Safety는 콘솔에서 수동 입력. 심사 연락처 정보가 없으면 심사가 지연/차단된다.
- **4.2 최소 기능** — 얇은 앱을 출시하지 않는다. 충분한 콘텐츠(예: 의미 있는 수의 레벨/모드) + 인게임 튜토리얼 + 메카닉별 첫 등장 팁이 있어야 한다. 그렇지 않으면 "최소 앱" 거절 위험이 있다.
- **2.3.10 — 메타데이터에 다른 플랫폼 언급 금지** — App Store는 설명에 "Android …"가 있으면 거절한다. 스토어별 카피를 분리한다(App Store 버전 vs Play 버전).
- **ASCII 안전한 설명** — App Store Connect의 linter는 장식적 유니코드(박스 그리기 문자 ▌ — × 등)를 거절한다. 일반 ASCII 헤더/구두점을 사용한다.
- **iPhone 전용 타겟** (`TARGETED_DEVICE_FAMILY = 1`)은 전화기 전용 게임에서 iPad 스크린샷 요구사항을 피할 수 있다(그리고 `~ipad` 방향 키를 제거한다).
- **AdMob "Made for kids" = No** — AdMob 앱 설정에서(진정한 아동용이 아닌 한). 그렇지 않으면 광고가 게재되지 않는다.

---

## Long-tail (전체 커밋 히스토리 감사)

빈도는 낮지만 실제로 발생한 사례들로, 모든 repo의 커밋과 문서를 전체 읽은 결과다.

**라이프사이클 / 크래시**
- **이른 백그라운드 시 `LateInitializationError`** — `didChangeAppLifecycleState`(또는 재사용된 컴포넌트의 `launch()`)가 `onLoad` 실행 전에 `late` 필드에 접근한다. `if (!game.isLoaded) return;`으로 핸들러를 가드하고, `onLoad`에서 초기화되는 nullable 필드를 선호한다.
- **`OpacityEffect`는 `OpacityProvider`에서만 동작** — 일반 `TextComponent`에 적용하면 throw된다. `update()`에서 수동으로 opacity를 애니메이션한다.
- **변경 전 반복 대상 스냅샷** — 적을 죽이는 충돌 판정이 루프 중간에 자식을 스폰하면 concurrent-modification 크래시가 발생한다. `.toList()` 스냅샷을 순회한다.

**Performance (heavy/bullet-hell 게임)**
- **per-frame 할당 피하기**: `setValues`로 `Vector2`를 재사용하고, `static final Paint`를 재사용하며, `paint.filterQuality = FilterQuality.none`을 설정하고, 타일별 스프라이트 루프 대신 솔리드 fill에는 `canvas.drawRect`를 사용한다.
- **per-frame `MaskFilter.blur`/`saveLayer` 금지** — 글로우/그림자를 반투명 flat fill, 겹쳐진 솔리드 디스크, 또는 하드 오프셋 그림자로 교체한다. "high FX" 토글을 제공한다(약한 기기에서 기본 off).
- **프레임당 스폰 수 제한** — 대량 킬 VFX / 플로팅 텍스트 / 총알은 프레임당 제한하고 풀링해야 한다(상한 초과 시 가장 오래된 것 retire). 화면 밖 렌더를 컬링하고 화면 밖 AI를 스로틀한다.

**Input & UI**
- **저지연 액션 입력**: raw `Listener`(`onPointerDown/Move/Up`)를 사용하고, 제스처 중간에 스와이프를 분류하며(임계값 도달 시 발화, 제스처당 한 번 래치), 포인터 업 시 탭을 발화한다. `_inputActive` 플래그로 게이트하여 탭이 오버레이로 누출되지 않게 한다. `GestureDetector`의 arena는 지연을 추가한다.
- **Flame 오버레이를 (투명) `Material`로 감싸기** — Flame 오버레이의 `InkWell`/ripple은 디버그에서 "No Material widget"을 assert하고 ripple을 보여주지 않는다. 투명 `Material` 부모가 이를 수정한다.
- **`MediaQuery.withNoTextScaling`** 픽셀 폰트/타이트한 가로 레이아웃에서 OS 폰트 스케일링이 HUD를 깨뜨리지 않도록.

**광고 / 동의**
- **UMP에 5초 타임아웃** (`requestConsentInfoUpdate` + `loadAndShowConsentFormIfRequired`) — 불안정한 시뮬레이터 네트워크가 그렇지 않으면 영원히 hang된다(콜백 없음).
- **UMP 폼은 AdMob 콘솔에서 GDPR 메시지가 생성되어야 한다** (앱별, 플랫폼별) — 코드만으로는 폼이 표시되지 않는다.

**Build / 플랫폼**
- **iOS Podfile 정적 링킹** — `use_frameworks! :linkage => :static` + `use_modular_headers!`는 AdMob/secure-storage pods에서 반복되는 "Failed to verify code signature (0xe8008014)"를 수정하고 설치마다 `flutter clean`을 피할 수 있게 한다.
- **iOS 플러그인 추가/변경 후 `pod install` 실행** — 그렇지 않으면 iOS 빌드가 실패한다.

**Persistence**
- **고빈도 쓰기 배치** — 킬/이벤트마다 `SharedPreferences.setInt`를 호출하지 않는다(I/O를 블록함). 메모리를 변경 + dirty 플래그를 설정하고 게임오버/테어다운 시 flush한다. (코인 같은 중요 통화는 런 종료 시 즉시/동기적으로 여전히 영속화한다.)
- **저장 스키마에 버전 부여** (`save_v1` 키 + 필드별 마이그레이션 기본값). 새 필드가 기존 저장을 손상시키지 않도록.
- **Durable save (기본 ON, R9 게이트)** — `shared_preferences`만으로는 **충분하지 않다**: iOS는 앱 삭제 시 이를 삭제하므로 재설치/새 기기에서 진행 상황이 사라진다. 하나의 JSON blob을 **iOS Keychain** (`flutter_secure_storage`, `first_unlock`) + **Android Block Store** (`play_services_block_store`) + `shared_preferences` 캐시(Android Auto Backup 페이로드도 겸함)에 미러링하는 `SaveRepository`를 통해 persistence를 라우팅한다. durable-first로 읽고, 모든 계층에 쓰고, 모든 호출을 try/catch로 감싼다. 이것은 새로 설치/기기에서의 last-write-wins 복원이며, **실시간 클라우드 동기화가 아니다**.

**Physics (Forge2D 게임 전용)**
- **Forge2D 단위는 픽셀이 아닌 미터** — body는 약 0.5–2 m으로 크기를 설정하고 카메라 zoom이 변환하도록 한다. 픽셀 크기를 physics에 혼입하지 않는다.
- **임펄스에 속도 게이트를 두고 스폰 겹침을 제거** — 스프링/범퍼는 접촉 속도 임계값 이상에서만 발화한다(그렇지 않으면 정지 상태의 body가 스폰 시 발사됨). level-gen 시 겹치는 body를 제거한다(Box2D는 겹침을 폭발시킨다).
