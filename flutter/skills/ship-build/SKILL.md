---
name: ship-build
description: 서명 자격증명 부트스트랩 → fastlane 설정 생성 → 서명된 IPA를 TestFlight에, AAB를 Play Store 내부 트랙에 업로드한다.
argument-hint: "app_slug bundle_id app_name credentials_dir project_root ios.asc_key_id android.key_alias"
allowed-tools: [Read, Write, Edit, Bash, Glob]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# ship-build

임의의 Flutter 프로젝트에서 단독으로 실행되는 빌드·배포 스킬이다. 서명 자격증명을 부트스트랩하고, fastlane 설정을 템플릿에서 생성한 뒤, 서명된 IPA를 TestFlight에, 서명된 AAB를 Play Store 내부 트랙에 업로드한다.

**전제 조건:**
- App Store Connect 앱 레코드와 Google Play Console 앱이 **이미 수동으로 생성되어 있어야** 한다. 업로드 레인은 앱 레코드가 없으면 실패한다.
- macOS 머신에 fastlane, Ruby, Xcode, flutter CLI가 설치되어 있어야 한다.

---

## 인자 / 사용법

이 스킬은 `config.md`나 `state.md`를 읽지 않는다. 사용자가 아래 인자를 직접 전달한다.

| 인자 | 설명 | 예시 |
|------|------|------|
| `app_slug` | 앱 식별자 (IPA 명명 등, 소문자·언더스코어) | `my_app` |
| `bundle_id` | iOS Bundle ID / Android Package ID | `com.<company>.my_app` |
| `app_name` | 스토어 표시 앱 이름 (공백 허용) | `My App` |
| `credentials_dir` | 자격증명 파일이 모여 있는 디렉토리 절대경로 | `/path/to/credentials` |
| `project_root` | Flutter 앱 루트 디렉토리 (`pubspec.yaml`이 있는 곳, 기본값: 현재 작업 디렉토리) | `/path/to/projects/my_app` |
| `apple_id` | Apple 계정 이메일 (fastlane Appfile) | `dev@example.com` |
| `ios.team_id` | Apple 개발자 팀 ID | `ABCDE12345` |
| `ios.asc_key_id` | App Store Connect API 키 ID | `ABCDE12345` |
| `ios.asc_issuer_id` | App Store Connect API issuer ID | `00000000-0000-0000-0000-000000000000` |
| `android.key_alias` | Android 서명 키 alias (기본값: `upload`) | `upload` |

> iOS 자격증명 인자(`apple_id`/`ios.team_id`/`ios.asc_key_id`/`ios.asc_issuer_id`)는 직접 넘기거나
> `credentials_dir`의 store-metadata에서 읽는다. 어느 쪽이든 템플릿에 하드코딩하지 않는다.

**앱 루트 경로:** `<project_root>` 자체 (`pubspec.yaml`·`ios/`·`android/`가 있는 곳)
- 이하 문서에서 `<app>` 으로 약칭한다.
- 처음 사용하는 곳에서 실제 경로를 한 번 출력해 확인한다.

**호출 예:**
```
/ship-build app_slug=my_app bundle_id=com.acme.my_app app_name="My App" credentials_dir=/path/to/credentials project_root=/path/to/projects/my_app apple_id=dev@example.com ios.team_id=ABCDE12345 ios.asc_key_id=ABCDE12345 ios.asc_issuer_id=00000000-0000-0000-0000-000000000000 android.key_alias=upload
```

---

## Phase 1 — 자격증명 부트스트랩

`credentials_dir`에 모아 둔 서명 파일을 앱의 플랫폼 디렉토리에 복사한다.
자격증명 경로를 코드에 하드코딩하지 않는다. 항상 인자로 받은 `credentials_dir`을 사용한다.

### iOS 자격증명

```bash
mkdir -p <app>/ios/fastlane/certs
cp <credentials_dir>/AuthKey_<ios.asc_key_id>.p8 <app>/ios/fastlane/
```

`.p8` 파일명은 인자로 받은 `ios.asc_key_id`를 포함한다. `certs/` 디렉토리에는 `fastlane certs`가 내려받는 배포 인증서와 프로비저닝 프로파일이 저장된다.

### Android 자격증명

```bash
mkdir -p <app>/android/fastlane
cp <credentials_dir>/play-store-key.json <app>/android/fastlane/
```

### Android 키스토어

`<credentials_dir>/upload-keystore.jks` 존재 여부를 확인한다.

- **존재하는 경우:** 복사한다.

  ```bash
  cp <credentials_dir>/upload-keystore.jks <app>/android/upload-keystore.jks
  ```

- **없는 경우:** `keytool`로 새 키스토어를 생성한다. alias는 인자 `android.key_alias`를 사용하며, store/key 비밀번호는 모두 `111111`이다.

  ```bash
  keytool -genkey -v \
    -keystore <app>/android/upload-keystore.jks \
    -alias <android.key_alias> \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass 111111 -keypass 111111 \
    -dname "CN=<company>, OU=Dev, O=<company>, L=Seoul, S=Seoul, C=KR"
  ```

### android/key.properties 작성

`templates/key.properties.template`의 플레이스홀더를 치환하여 `<app>/android/key.properties`를 작성한다. `storeFile` 경로는 Gradle이 `android/` 기준으로 읽으므로 상대경로로 지정한다.

```
storePassword=111111
keyPassword=111111
keyAlias=<android.key_alias>
storeFile=upload-keystore.jks
```

---

## Phase 2 — Fastlane 설정 생성

이 스킬 디렉토리의 `templates/fastlane/`에 있는 4개의 템플릿에서 플레이스홀더를 치환하여 각 플랫폼의 `Appfile`과 `Fastfile`을 생성한다.

### 플레이스홀더 치환 규칙

| 플레이스홀더 | 치환값 |
|---|---|
| `__APP_ID__` | `bundle_id` 인자값 |
| `__PACKAGE__` | `bundle_id` 인자값 |
| `__IPA_NAME__` | `<app_name>.ipa` (`app_name` 값 그대로; 공백 허용) |
| `__PROFILE_NAME__` | `<bundle_id> AppStore` (예: `com.acme.my_app AppStore`) |
| `__APPLE_ID__` | `apple_id` 인자값 (Apple 계정 이메일) |
| `__TEAM_ID__` | `ios.team_id` 인자값 (Apple 개발자 팀 ID) |
| `__ASC_KEY_ID__` | `ios.asc_key_id` 인자값 (ASC API 키 ID, `AuthKey_<id>.p8` 파일명에도 사용) |
| `__ASC_ISSUER_ID__` | `ios.asc_issuer_id` 인자값 (ASC API issuer ID) |

> **자격증명 플레이스홀더**(`__APPLE_ID__`/`__TEAM_ID__`/`__ASC_KEY_ID__`/`__ASC_ISSUER_ID__`)는
> 절대 하드코딩하지 않는다. 항상 인자(또는 `credentials_dir`의 store-metadata)에서 읽어 치환한다.
> 템플릿에는 실제 값이 없고 플레이스홀더만 있다.

`__PROFILE_NAME__`은 Xcode 코드 사이닝 프로파일 이름과 `.mobileprovision` 파일명(fastlane이 `.mobileprovision` 확장자를 붙임) 양쪽에 모두 쓰인다. 공백은 허용된다.

### iOS fastlane 생성

```bash
mkdir -p <app>/ios/fastlane/certs
# Appfile 생성
sed -e 's/__APP_ID__/<bundle_id>/g' \
    -e 's/__APPLE_ID__/<apple_id>/g' \
    -e 's/__TEAM_ID__/<ios.team_id>/g' \
    templates/fastlane/ios-Appfile.template \
    > <app>/ios/fastlane/Appfile
# Fastfile 생성
sed -e 's/__APP_ID__/<bundle_id>/g' \
    -e 's/__IPA_NAME__/<app_name>.ipa/g' \
    -e 's/__PROFILE_NAME__/<bundle_id> AppStore/g' \
    -e 's/__TEAM_ID__/<ios.team_id>/g' \
    -e 's/__ASC_KEY_ID__/<ios.asc_key_id>/g' \
    -e 's/__ASC_ISSUER_ID__/<ios.asc_issuer_id>/g' \
    templates/fastlane/ios-Fastfile.template \
    > <app>/ios/fastlane/Fastfile
```

### Android fastlane 생성

```bash
mkdir -p <app>/android/fastlane
# Appfile 생성
sed -e 's/__PACKAGE__/<bundle_id>/g' \
    templates/fastlane/android-Appfile.template \
    > <app>/android/fastlane/Appfile
# Fastfile 생성
sed -e 's/__PACKAGE__/<bundle_id>/g' \
    templates/fastlane/android-Fastfile.template \
    > <app>/android/fastlane/Fastfile
```

### 치환 검증

치환 후 미해결 플레이스홀더가 없는지 반드시 확인한다.

```bash
grep '__' \
  <app>/ios/fastlane/Appfile \
  <app>/ios/fastlane/Fastfile \
  <app>/android/fastlane/Appfile \
  <app>/android/fastlane/Fastfile
```

출력이 비어 있어야 한다. 미해결 플레이스홀더가 남아 있으면 중단하고 원인을 확인한다.

---

## Phase 3 — 빌드 및 업로드

모든 빌드 명령은 앱 루트(`<app>`)를 기준으로 실행한다.

### 빌드 전 플랫폼 점검 사항

아래 항목은 스토어 거절의 주요 원인이므로 빌드 전에 반드시 확인한다:

- **iOS:** `PrivacyInfo.xcprivacy` 등록 (iOS 17+), `Podfile` platform 최소 버전 설정, `Info.plist`에 ATT 문구 및 `SKAdNetworkItems` 포함, `ITSAppUsesNonExemptEncryption = false` (내보내기 컴플라이언스 프롬프트 건너뜀)
- **Android:** `minSdk = 23` 이상, core-library desugaring 활성화
- **공통:** 업로드할 때마다 **빌드 번호를 반드시 증가**시킨다. App Store Connect는 중복 빌드 번호를 거부한다.

### iOS — 서명 IPA → TestFlight

```bash
cd <app>/ios
fastlane certs          # 배포 인증서 + 프로비저닝 프로파일 다운로드/갱신 (certs/에 저장)
fastlane beta           # 서명된 IPA 빌드 후 TestFlight 업로드
```

`fastlane beta` 레인은 `get_provisioning_profile`, `update_code_signing_settings`, `build_app`, `upload_to_testflight`을 순서대로 실행한다. Apple 처리 대기를 차단하지 않도록 `skip_waiting_for_build_processing: true`가 설정되어 있다.

### Android — 서명 AAB → 내부 트랙

```bash
cd <app>
flutter build appbundle --release   # build/app/outputs/bundle/release/app-release.aab 생성

cd android
fastlane internal                   # Play Store 내부 트랙에 AAB 업로드
```

`fastlane internal` 레인은 `upload_to_play_store`를 `track: "internal"`과 상대경로 `../build/app/outputs/bundle/release/app-release.aab`로 호출한다.

### 빌드 실패 처리

| 오류 | 조치 |
|------|------|
| `fastlane certs` 인증서 오류 | Keychain Access에서 Apple Distribution 인증서 유효성 확인 후 재실행 |
| `fastlane beta` 프로파일 미발견 | App Store Connect에 앱 레코드가 있는지 확인하고 `fastlane certs` 먼저 재실행 |
| `flutter build appbundle --release` 실패 | `flutter analyze`로 컴파일 오류 파악 후 수정 |
| `fastlane internal` 401 또는 자격증명 오류 | `android/fastlane/play-store-key.json`이 올바르게 복사됐는지, Play Console에서 서비스 계정에 Release Manager 역할이 있는지 확인 |

---

## 결과 요약

빌드 및 업로드가 완료되면 다음 정보를 사용자에게 출력한다.

```
## 빌드 완료 — <app_name>

### IPA
- 경로: <app>/ios/build/<app_name>.ipa
- 업로드: TestFlight — 성공 (빌드 번호: <N>)

### AAB
- 경로: <app>/build/app/outputs/bundle/release/app-release.aab
- 업로드: Play Store 내부 트랙 — 성공 (버전 코드: <N>)
```

`<N>`은 fastlane 출력에서 확인한 실제 빌드 번호 / 버전 코드로 채운다.

업로드 중 하나라도 실패하면 즉시 중단하고 필요한 수동 조치를 설명한다. 이 스킬은 상태 파일을 쓰지 않으므로 수정 후 스킬을 다시 호출하면 된다.
