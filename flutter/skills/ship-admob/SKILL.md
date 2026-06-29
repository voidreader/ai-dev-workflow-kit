---
name: ship-admob
description: Flutter 앱의 게임 루프(또는 앱 흐름)를 분석해 리워드 광고 배치 전략을 수립하고, AdMob 콘솔 수동 유닛 생성을 안내한 뒤 google_mobile_ads · iOS ATT · UMP consent 코드를 주입한다.
argument-hint: "app_slug=<앱 슬러그> bundle_id=<번들ID> project_root=<프로젝트 루트>"
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

## 인자 / 사용법

이 스킬은 harness 파이프라인과 무관하게 **단독 실행**된다. 아래 세 인자를 받는다.

| 인자 | 설명 | 예시 |
|------|------|------|
| `app_slug` | 앱 식별자 (소문자, 하이픈) | `my-app` |
| `bundle_id` | 번들 ID (iOS/Android 공통) | `com.<company>.myapp` |
| `project_root` | Flutter 앱 루트 디렉토리 (`pubspec.yaml`이 있는 곳, 기본값: 현재 작업 디렉토리) | `/Users/you/projects/my-app` |

앱 소스 루트는 `<project_root>` 자체다. 이하 `APP_ROOT`로 표기. (`app_slug`는 Dart 패키지명·광고 유닛 이름에만 쓰인다.)

인자가 전달되지 않으면 `AskUserQuestion`으로 세 값을 모두 수집한 뒤 진행한다.

---

## 1단계 — 앱 흐름 분석 및 리워드 광고 배치 전략

`APP_ROOT/lib` 디렉토리를 탐색해 앱의 핵심 흐름(게임 루프, 결제 전환점, 세션 종료 지점 등)을 파악한다. Flame 게임이라면 게임 오버·부활·레벨 클리어 화면을, 일반 Flutter 앱이라면 사용자 액션 완료 후 보상 제공이 자연스러운 지점을 찾는다.

### 리워드 광고 배치 원칙

- **부활 / 계속하기**: 세션 실패 직후 "광고를 시청하고 계속할까요?" — 리워드 광고 중 전환율이 가장 높은 배치.
- **코인 두 배 / 보너스**: 세션 종료 후 획득 점수·코인을 두 배로 주는 리워드 제공.
- **추가 생명 / 실드**: 체력이 임계값 이하일 때 미드-게임 리워드 제공.
- **힌트 공개 / 레벨 스킵**: 퍼즐류 앱에서 힌트나 레벨 스킵을 리워드로 제공.

앱 구조에 맞는 배치를 선택하고 **구체적인 위치**(파일 경로·위젯명)와 함께 명시한다. 이후 단계에서 코드 주입 시 정확히 이 위치에 `RewardedAdHelper.show()`를 삽입한다.

### 삽입하지 않는 광고 유형

앱 흐름을 방해하는 **인터스티셜 광고**는 PRD 또는 사용자가 명시적으로 요청하지 않는 한 추가하지 않는다. 인터스티셜은 리텐션을 해치고 앱 스토어 정책 위반 리스크가 있다.

### 배너 광고 (조건부)

사용자가 명시적으로 요청한 경우에만 추가한다. 배너를 추가할 때는 SafeArea 배너 갭 패턴을 적용한다: 게임(앱) 캔버스를 `Column`으로 감싸고 하단에 `SafeArea`로 패딩된 `BannerAdWidget`을 배치해 광고가 앱 콘텐츠와 겹치지 않도록 한다.

---

## 2단계 — AdMob 콘솔 수동 유닛 생성 안내

Google API는 AdMob 광고 유닛을 프로그래밍 방식으로 생성하지 못한다. 사용자가 콘솔에서 직접 생성해야 한다.

### Step 1 — 앱 ID 수집

`AskUserQuestion`으로 다음을 묻는다:

> "AdMob 콘솔(https://admob.google.com)을 열고:
> 1. iOS 앱 추가 → **iOS App ID** 복사 (형식: `ca-app-pub-XXXX~YYYY`)
> 2. Android 앱 추가 → **Android App ID** 복사 (형식: `ca-app-pub-XXXX~ZZZZ`)
>
> 두 ID를 붙여넣어 주세요. 아직 준비되지 않았다면 'defer'를 입력해 주세요."

사용자가 `defer` 또는 준비 안 됨을 표시하면 다음을 출력하고 즉시 중단한다:

```
AdMob 콘솔 작업이 완료되면 다시 /ship-admob 을 실행해 주세요.
필요한 작업:
  1. https://admob.google.com 에서 iOS 앱 및 Android 앱 등록
  2. 각 App ID(ca-app-pub-XXXX~YYYY 형식) 메모
```

### Step 2 — 광고 유닛 ID 수집

1단계 전략에서 선택한 각 리워드 배치에 대해 `AskUserQuestion`으로 아래를 요청한다 (예: revive 유닛):

> "AdMob 콘솔에서 앱 → 광고 유닛 → 광고 유닛 추가 → 리워드:
> - 유닛 이름: `<app_slug>_rewarded_revive`
> - **iOS 유닛 ID** (`ca-app-pub-XXXX/IIII`)와 **Android 유닛 ID** (`ca-app-pub-XXXX/AAAA`)를 복사해 붙여넣어 주세요.
>
> 준비되지 않았다면 'defer'를 입력해 주세요."

defer 시 위와 동일하게 중단하고 안내 메시지를 출력한다.

---

## 3단계 — 코드 주입

ID를 모두 수집한 뒤 `APP_ROOT` 아래 코드를 주입한다.

### 3-1. pubspec.yaml — 의존성 추가

`APP_ROOT/pubspec.yaml`의 `dependencies:` 블록에 추가한다:

```yaml
dependencies:
  google_mobile_ads: ^5.1.0
  app_tracking_transparency: ^2.0.6
```

편집 후 `flutter pub get`을 실행한다.

### 3-2. iOS ATT 권한 — Info.plist

`APP_ROOT/ios/Runner/Info.plist`에 추가한다:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>광고를 개인화하고 앱 개선을 위해 사용합니다.</string>
```

AdMob App ID도 추가한다:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXX~YYYY</string>
```

`SKAdNetworkItems`(Google 공식 `google_mobile_ads` 문서에서 제공하는 SKAdNetwork ID 목록)도 추가한다 — App Store 심사 통과를 위해 필수다. ATT 관련 주의사항은 `docs/harness/game-gotchas.md`가 있으면 참조하고, 핵심은 아래 §3-4 주석에 인라인으로 포함되어 있다.

### 3-3. Android — AndroidManifest.xml + minSdk

`APP_ROOT/android/app/build.gradle.kts`에서 `minSdk`를 23으로 설정한다 — `google_mobile_ads`는 API 23 미만에서 시작 시 크래시가 발생한다. (`docs/harness/game-gotchas.md` 참조)

`APP_ROOT/android/app/src/main/AndroidManifest.xml`의 `<application>` 안에 추가한다:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXX~ZZZZ"/>
```

### 3-4. ATT 헬퍼 — lib/admob/att_helper.dart

`APP_ROOT/lib/admob/att_helper.dart`를 생성한다:

```dart
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// iOS App Tracking Transparency 권한을 요청한다. Android에서는 no-op.
///
/// CRITICAL — App Store 가이드라인 2.1: ATT 시스템 다이얼로그는 앱이
/// active/foregrounded 상태일 때만 표시된다. 첫 실행 시 앱이 아직
/// `resumed` 상태가 아니면 요청이 조용히 no-op 처리되어 프롬프트가 영영
/// 나타나지 않는다 — 최신 iOS에서 "NSUserTrackingUsageDescription이 있지만
/// ATT 알림이 표시되지 않는" 2.1 거절의 실제 원인이다.
/// 따라서: resumed 상태까지 대기 → 소폭 settle 딜레이 → notDetermined일 때만 요청.
Future<void> requestATT() async {
  if (!Platform.isIOS) return;
  try {
    await _waitUntilResumed();
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('ATT request failed: $e');
  }
}

/// 앱이 foreground/active 상태에 진입할 때까지 최대 ~4초 대기한다.
/// ATT 프롬프트가 실제로 표시되려면 이 상태가 필요하다.
Future<void> _waitUntilResumed() async {
  for (var i = 0; i < 40; i++) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
```

`requestATT()`는 반드시 **첫 프레임 이후 콜백**(`WidgetsBinding.instance.addPostFrameCallback`)에서 호출하고, `loadConsentForm()`과 `MobileAds.instance.initialize()` **이전에 await**해야 한다 (§3-5 참조). `main()`에서 첫 프레임 전에 동기 호출하면 2.1 거절 원인이 된다.

### 3-5. UMP Consent 플로우 — lib/admob/consent_helper.dart

`APP_ROOT/lib/admob/consent_helper.dart`를 생성한다:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP consent form을 로드하고 (필요 시) 표시한다.
/// 이 Future가 완료되기 전에 광고를 요청하면 안 된다.
Future<void> loadConsentForm() async {
  final completer = Completer<void>();
  final params = ConsentRequestParameters();
  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
      if (!completer.isCompleted) completer.complete();
    },
    (FormError error) {
      debugPrint('UMP consent error: ${error.message}');
      if (!completer.isCompleted) completer.complete(); // non-fatal, 계속 진행
    },
  );
  return completer.future;
}
```

`main()`의 시작 순서:

```dart
WidgetsFlutterBinding.ensureInitialized();
await requestATT();          // iOS 전용 — Android에서는 no-op
await loadConsentForm();     // UMP consent 결정까지 대기
await MobileAds.instance.initialize();
// 이 시점 이후에 광고 사전 로드 / runApp 호출
```

### 3-6. ID 스위치 — lib/admob/ad_ids.dart

`APP_ROOT/lib/admob/ad_ids.dart`를 생성한다. 디버그 빌드에서는 Google 공식 테스트 ID를 사용해 정책 위반을 방지하고, 릴리즈 빌드에서 실제 ID로 전환한다:

```dart
import 'dart:io';

const bool _isDebug = bool.fromEnvironment('dart.vm.product') == false;

class AdIds {
  // ── Rewarded: revive ────────────────────────────────────────────────────
  static String get rewardedRevive {
    if (_isDebug) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'   // Google iOS 테스트 ID
          : 'ca-app-pub-3940256099942544/5224354917';  // Google Android 테스트 ID
    }
    return Platform.isIOS
        ? 'ca-app-pub-XXXX/IIII'   // Step 2에서 수집한 iOS 유닛 ID
        : 'ca-app-pub-XXXX/AAAA';  // Step 2에서 수집한 Android 유닛 ID
  }
  // 광고 유닛 배치마다 getter를 하나씩 추가한다.
}
```

플레이스홀더(`ca-app-pub-XXXX/IIII` 등)를 사용자에게서 수집한 실제 ID로 교체한다.

### 3-7. 리워드 헬퍼 — lib/admob/rewarded_ad_helper.dart

`APP_ROOT/lib/admob/rewarded_ad_helper.dart`를 생성한다:

```dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 단일 배치에 대한 리워드 광고를 로드하고 표시한다.
/// 생성 시 [AdIds]에서 광고 유닛 ID를 전달하면 동일 클래스를
/// 서브클래싱 없이 모든 배치(부활, 보너스 코인 등)에 재사용할 수 있다.
///
/// 예:
///   final _reviveAd = RewardedAdHelper(AdIds.rewardedRevive);
///   final _bonusAd  = RewardedAdHelper(AdIds.rewardedBonus);
///
/// [onRewarded]: 사용자가 리워드를 획득할 때 호출됨.
/// [onDismissed]: 광고가 닫힐 때 (리워드 여부 무관) 호출됨.
class RewardedAdHelper {
  RewardedAdHelper(this.adUnitId);

  final String adUnitId;
  RewardedAd? _ad;

  Future<void> load() async {
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _ad = null;
        },
      ),
    );
  }

  /// 광고가 준비되었으면 true를 반환한다.
  bool get isLoaded => _ad != null;

  /// 광고를 표시한다. [onRewarded]는 사용자가 리워드를 획득할 때 호출된다.
  void show({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) {
    final ad = _ad;
    if (ad == null) {
      onDismissed?.call();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        onDismissed?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onRewarded());
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
```

### 3-8. 앱 통합

1단계에서 파악한 적절한 지점(게임 오버 오버레이, 세션 종료 화면 등)에서 다음과 같이 호출한다:

```dart
if (_rewardedAdHelper.isLoaded) {
  _rewardedAdHelper.show(
    onRewarded: () {
      // 리워드 지급: 체력 회복, 추가 생명, 코인 두 배 등
    },
    onDismissed: () {
      // 사용자가 광고를 스킵 — 일반 게임 오버 흐름으로 진행
    },
  );
}
```

앱 세션이 시작될 때 광고를 사전 로드한다. 배치마다 `RewardedAdHelper` 인스턴스를 하나씩 생성하고 매핑된 `AdIds` getter를 전달한다:

```dart
_reviveAdHelper = RewardedAdHelper(AdIds.rewardedRevive);
await _reviveAdHelper.load();
// 배치마다 한 줄씩 추가 (예: RewardedAdHelper(AdIds.rewardedBonus))
```

---

## 4단계 — 검증 및 완료

코드 주입 완료 후:

1. `flutter analyze`를 실행해 이슈가 0개인지 확인한다. 이슈가 있으면 모두 수정한 뒤 다음 단계로 넘어간다.
2. 아래 요약을 출력한다:

```
ship-admob 완료

앱 루트    : <APP_ROOT>
bundle_id  : <bundle_id>

생성된 파일:
  lib/admob/att_helper.dart
  lib/admob/consent_helper.dart
  lib/admob/ad_ids.dart
  lib/admob/rewarded_ad_helper.dart

수정된 파일:
  pubspec.yaml            (google_mobile_ads, app_tracking_transparency 추가)
  ios/Runner/Info.plist   (ATT, GADApplicationIdentifier, SKAdNetworkItems)
  android/app/build.gradle.kts  (minSdk = 23)
  android/app/src/main/AndroidManifest.xml  (APPLICATION_ID meta-data)

리워드 배치:
  <1단계에서 결정한 배치 목록>

다음 단계:
  실제 기기에서 디버그 빌드로 ATT 프롬프트 및 UMP consent 팝업 동작을 확인하세요.
  릴리즈 빌드 전에 AdIds 클래스의 테스트 ID가 실제 ID로 교체되었는지 검토하세요.
```

---

## 에러 처리

- `flutter analyze` 실패 시: 모든 이슈를 수정한 후 완료 메시지를 출력한다.
- 사용자가 AdMob ID를 제공하지 못하는 경우 (콘솔 접근 불가, 승인 대기 등): 필요한 작업을 명확히 안내하고 중단한다. 준비 완료 후 `/ship-admob`을 다시 실행하도록 안내한다.
- `app_tracking_transparency` 또는 `google_mobile_ads` 패키지를 찾을 수 없는 경우: `flutter pub search google_mobile_ads`로 현재 패키지명을 확인하고 버전을 갱신한다.
