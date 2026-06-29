---
name: ship-screenshot
description: integration_test 기반으로 로케일별 스토어 스크린샷을 캡처하고, ASO 메타데이터를 채운 뒤 fastlane으로 iOS/Android 스토어에 업로드한다.
argument-hint: "app_slug bundle_id project_root default_language [extra_locales] [ios_device_id] [android_device_id]"
allowed-tools: [Read, Write, Edit, Bash, Glob]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# ship-screenshot

임의의 Flutter 프로젝트에서 단독으로 실행할 수 있는 스크린샷 캡처·업로드 스킬이다.
`integration_test` 드라이버로 광고를 숨긴 상태에서 지정된 기기 크기·로케일별 PNG를 캡처하고,
ASO 메타데이터(키워드·제목·설명)를 채운 뒤 fastlane으로 App Store Connect / Google Play에 업로드한다.

---

## 인자 / 사용법

이 스킬은 외부 상태 파일을 읽지 않는다. 필요한 모든 값은 호출 시 인자로 전달한다.

| 인자 | 필수 | 설명 |
|------|------|------|
| `app_slug` | 필수 | 앱 식별자 (예: `my-app`). Dart 패키지명 변환 시 `-` → `_`. |
| `bundle_id` | 필수 | iOS/Android 공통 bundle ID (예: `com.<company>.myapp`). |
| `project_root` | 필수 | Flutter 프로젝트 루트 절대 경로 (예: `/Users/me/projects/my-app`). |
| `default_language` | 필수 | 기본 언어 코드 (예: `ko`). |
| `extra_locales` | 선택 | 추가 로케일 목록 (예: `en`). 미지정 시 `default_language` 하나만 캡처. |
| `ios_device_id` | 선택 | iOS 시뮬레이터 ID. 미지정 시 `flutter devices`로 확인 후 6.7" 모델 선택. |
| `android_device_id` | 선택 | Android 에뮬레이터 ID. 미지정 시 `flutter devices`로 확인 후 phone 모델 선택. |
| `credentials_dir` | 선택 | fastlane 인증 파일 디렉토리. 미지정 시 `<project_root>/credentials`로 간주. |

**호출 예:**
```
/ship-screenshot app_slug=my-app bundle_id=com.mycompany.myapp \
  project_root=/Users/me/projects/my-app default_language=ko extra_locales=en \
  ios_device_id=<simulator-udid> android_device_id=emulator-5554
```

**전제 조건:** Flutter 프로젝트가 빌드·업로드된 상태여야 한다. 개발자 macOS 머신에 `flutter drive` 및 fastlane이 설치되어 있어야 한다.

---

## Phase 1 — 테스트 하네스 설정

### integration_test 템플릿 복사

이 스킬의 `templates/screenshots_test.dart.template`을 프로젝트 `integration_test/` 디렉토리에 복사한다:

```bash
mkdir -p <project_root>/integration_test
cp templates/screenshots_test.dart.template \
   <project_root>/integration_test/screenshots_test.dart
```

### TODO 마커 적용

`<project_root>/integration_test/screenshots_test.dart`를 열고 모든 `// TODO(generator):` 블록을 실제 앱 동작 코드로 교체한다:

- `<__APP_SLUG__>` import를 실제 패키지명으로 교체한다 (`app_slug`의 `-` → `_`).
- SharedPreferences / Hive / Isar 등의 목 데이터를 세팅해 첫 실행 튜토리얼을 건너뛰고 대표적인 UI 상태(고득점, 코인, 잠금 해제된 스킨 등)를 표시한다.
- `SCREENSHOT_LOCALE` dart-define 값으로 앱 로케일을 강제 지정한다. 시뮬레이터 시스템 로케일과 무관하게 언어가 결정적으로 고정되어야 한다.
- 플레이스홀더 화면 목록을 앱의 실제 핵심 화면(홈, 게임플레이, 결과 화면, 부가 화면 등)으로 교체한다. 파일명은 두 자리 영문 접두사(01_, 02_, …)를 붙여 fastlane / App Store Connect에서 순서가 유지되도록 한다.

### 테스트 드라이버

`<project_root>/test_driver/integration_test.dart`가 없으면 생성한다 (표준 Flutter integration_test 보일러플레이트):

```dart
import 'package:integration_test/integration_test_driver_extended.dart';
Future<void> main() => integrationDriver();
```

---

## Phase 2 — 스크린샷 캡처

### 기기 크기

| 플랫폼 | 권장 기기 |
|--------|----------|
| iOS | 6.7" iPhone 시뮬레이터 (예: iPhone 15 Pro Max) |
| Android | Phone 에뮬레이터 (예: Pixel 7, 1080 × 2400) |

`flutter devices`로 기기 ID를 확인한다. 정확한 기기를 지정하려면 `-d` 플래그를 사용한다.

### 광고 숨김 처리

모든 `flutter drive` 호출에 `--dart-define=screenshots=true`를 전달한다.
앱의 광고 헬퍼는 이 플래그를 확인해 캡처 중 모든 광고 단위(배너, 전면, 리워드)를 숨겨야 한다.
스크린샷 모드에서는 ATT 프롬프트도 건너뛰고 오디오도 음소거해야 한다(네이티브 프롬프트와 사운드가 자동 캡처를 방해함).

**알파 채널 금지** (App Store 반려 원인): 스토어 스크린샷과 iOS 앱 아이콘은 불투명 RGB로 평탄화해야 한다.
업로드 전 투명도를 제거한다 (예: `sips -s format png`로 불투명 배경에 합성, 또는 알파 없이 내보내기).

```dart
// 광고 헬퍼 예시:
const bool isScreenshotMode =
    bool.fromEnvironment('screenshots', defaultValue: false);
```

### 로케일 루프

`default_language`와 `extra_locales`의 각 로케일마다 캡처를 실행한다. `--dart-define=SCREENSHOT_LOCALE=`로 로케일을 주입한다:

```bash
IOS_DEVICE="<ios_device_id>"
ANDROID_DEVICE="<android_device_id>"
APP_ROOT="<project_root>"

for LOCALE in <default_language> <extra_locales...>; do
  # iOS 캡처
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshots_test.dart \
    -d "$IOS_DEVICE" \
    --dart-define=SCREENSHOT_LOCALE=$LOCALE \
    --dart-define=screenshots=true

  # Android 캡처
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshots_test.dart \
    -d "$ANDROID_DEVICE" \
    --dart-define=SCREENSHOT_LOCALE=$LOCALE \
    --dart-define=screenshots=true
done
```

### 스크린샷 출력 경로

`IntegrationTestWidgetsFlutterBinding.takeScreenshot`은 기본적으로 `<project_root>/` 에 PNG 파일을 저장한다.
각 실행 직후 Phase 4의 fastlane 예상 경로로 이동한다 (아래 Phase 4 참조).

---

## Phase 3 — ASO 메타데이터

`default_language`와 `extra_locales` 모든 로케일에 대해 ASO 메타데이터를 채운다.

### iOS keywords.txt

각 로케일마다 `<project_root>/ios/fastlane/metadata/<locale>/keywords.txt`를 작성한다.
문자열은 쉼표 포함 **95~100자**여야 한다 (App Store Connect는 100자에서 잘림).

길이 검증:
```bash
echo -n "your,keyword,string" | wc -c   # 95~100 이어야 함
```

### iOS 현지화 제목·설명

각 로케일의 `<project_root>/ios/fastlane/metadata/<locale>/` 아래에 작성한다:

- `name.txt` — 현지화된 앱 표시 이름 (≤ 30자).
- `subtitle.txt` — 현지화된 부제목 (≤ 30자).
- `description.txt` — 전체 App Store 설명 (≤ 4000자, 키워드 남용 금지).
- `promotional_text.txt` — 선택적 홍보 문구 (≤ 170자).
- `release_notes.txt` — 이번 버전의 새로운 기능.

### Android 현지화 제목·설명

각 로케일의 `<project_root>/android/fastlane/metadata/android/<locale>/` 아래에 작성한다.
Android 경로 로케일 코드는 `ko` → `ko-KR`, `en` → `en-US` 형식을 사용한다:

- `title.txt` — 현지화된 앱 제목 (≤ 50자).
- `short_description.txt` — 현지화된 짧은 설명 (≤ 80자).
- `full_description.txt` — 현지화된 전체 설명 (≤ 4000자).
- `changelogs/<version-code>.txt` — 새로운 기능.

---

## Phase 4 — 업로드

### 스크린샷 파일 배치

캡처 후, fastlane이 기대하는 디렉토리 구조로 PNG 파일을 이동한다:

**iOS** — fastlane screenshots 폴더 아래 로케일별 하위 디렉토리:

```
<project_root>/ios/fastlane/screenshots/<locale>/          ← 예: ko/
<project_root>/ios/fastlane/screenshots/en-US/             ← en 로케일
```

**Android** — 로케일별 phone 스크린샷 디렉토리:

```
<project_root>/android/fastlane/metadata/android/<locale>-<region>/images/phoneScreenshots/
```
예: `ko-KR/images/phoneScreenshots/`, `en-US/images/phoneScreenshots/`

디렉토리 생성:

```bash
# iOS
for LOCALE in <default_language> <extra_locales...>; do
  mkdir -p "<project_root>/ios/fastlane/screenshots/$LOCALE"
done

# Android (locale → locale-REGION 매핑: ko→ko-KR, en→en-US 등)
for LOC_REGION in ko-KR en-US; do
  mkdir -p "<project_root>/android/fastlane/metadata/android/$LOC_REGION/images/phoneScreenshots"
done
```

### iOS — fastlane screenshots 레인

iOS fastlane 디렉토리에서 실행해 App Store Connect에 스크린샷·메타데이터를 업로드한다:

```bash
cd <project_root>/ios
fastlane screenshots
```

`screenshots` 레인은 `deliver` (또는 `upload_to_app_store`에 `skip_binary_upload: true` 옵션)를 호출해
모든 로케일 스크린샷 디렉토리와 메타데이터 파일을 Push한다.
`<project_root>/ios/fastlane/Fastfile`에 `screenshots` 레인이 있는지 확인한다.

### Android — Play 리스팅 그래픽 (필수)

Google Play는 리스팅에 **hi-res 아이콘(512×512)**과 **피처 그래픽(1024×500)**이 필요하다.
없으면 리스팅을 게시할 수 없다. 해당 파일은 `assets/store/play_icon.png`와
`assets/store/feature_graphic.png`에 있어야 한다. 각 로케일 디렉토리로 복사한다:

```bash
for LOC_REGION in ko-KR en-US; do
  d="<project_root>/android/fastlane/metadata/android/$LOC_REGION/images"
  mkdir -p "$d"
  cp "<project_root>/assets/store/play_icon.png"       "$d/icon.png"            # 512×512 hi-res 아이콘
  cp "<project_root>/assets/store/feature_graphic.png" "$d/featureGraphic.png"  # 1024×500 피처 그래픽
done
```

(App Store는 피처 그래픽이 필요 없다 — iOS 아이콘은 빌드에 내장되며, iOS `screenshots` 레인으로 스크린샷만 업로드된다.)

### Android — fastlane images 레인

Android fastlane 디렉토리에서 실행해 스크린샷·hi-res 아이콘·피처 그래픽을 Google Play에 업로드한다:

```bash
cd <project_root>/android
fastlane images
```

`images` 레인은 `upload_to_play_store`에 `skip_upload_apk: true`와 `skip_upload_aab: true`를 설정해
메타데이터·이미지만 Push한다(트랙 지정 불필요).
`<project_root>/android/fastlane/Fastfile`에 `images` 레인이 있는지 확인한다.

### 스토어 에셋 아카이브

최종 PNG를 프로젝트 `store-assets/` 디렉토리에 복사해 보관한다:

```bash
mkdir -p "<project_root>/store-assets/ios/ko" "<project_root>/store-assets/ios/en-US"
mkdir -p "<project_root>/store-assets/android/ko-KR" "<project_root>/store-assets/android/en-US"

cp "<project_root>/ios/fastlane/screenshots/ko/"*.png       "<project_root>/store-assets/ios/ko/"
cp "<project_root>/ios/fastlane/screenshots/en-US/"*.png    "<project_root>/store-assets/ios/en-US/"
cp "<project_root>/android/fastlane/metadata/android/ko-KR/images/phoneScreenshots/"*.png \
   "<project_root>/store-assets/android/ko-KR/"
cp "<project_root>/android/fastlane/metadata/android/en-US/images/phoneScreenshots/"*.png \
   "<project_root>/store-assets/android/en-US/"
```

---

## 오류 처리

스크린샷 캡처 또는 업로드가 실패하고 즉시 해결할 수 없는 경우:

1. 실패한 단계와 오류 메시지를 명확히 출력한다.
2. 필요한 수동 조치를 설명한다 (예: 시뮬레이터 재부팅, 인증서 갱신, fastlane 레인 확인).
3. 수동 조치 완료 후 해당 Phase부터 재실행할 수 있음을 안내한다.

자주 발생하는 문제:
- `flutter drive` 타임아웃: 앱 시작 대기 시간 부족 → `wait()` 호출 시간 늘리기.
- 알파 채널 거부: `sips`로 불투명 배경에 평탄화 후 재업로드.
- fastlane 인증 오류: `credentials_dir` 내 인증 파일(API 키, 서비스 계정 JSON) 확인.
- Android hi-res 아이콘 누락: `assets/store/play_icon.png` (512×512) 존재 여부 확인.
