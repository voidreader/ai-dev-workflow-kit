---
name: ship-submit
description: 스토어 텍스트 메타데이터를 fastlane으로 업로드하고, Android 연락처를 Publisher API로 설정한 뒤, iOS 심사 제출 및 Android 프로덕션 프로모션을 위한 정확한 수동 단계를 안내한다.
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

## 개요

임의의 Flutter 프로젝트에서 단독 실행 가능한 스토어 제출 스킬이다. fastlane으로 양 플랫폼의 텍스트 메타데이터와 카테고리를 업로드하고, Android Publisher API로 연락처를 설정한다. Apple과 Google API는 사람의 확인 없이 최종 제출을 완전히 자동화할 수 없으므로, 최종 "심사 제출(iOS)" 및 "프로덕션 프로모션(Android)"은 수동 단계 안내로 처리한다.

**경계:** 텍스트 메타데이터 업로드는 자동화된다. iOS의 "Submit for Review" 탭 및 Android의 "Promote to production" 동작은 **수동**이다.

---

## 인자 / 사용법

이 스킬은 harness 상태머신과 독립적으로 실행된다. `config.md`·`state.md`를 읽거나 쓰지 않는다. 모든 필요 정보는 호출 시 인자로 전달한다.

### 필수 인자

| 인자 | 설명 | 예시 |
|------|------|------|
| `app_slug` | 앱 식별자 (메타데이터 명명 등) | `my_game` |
| `bundle_id` | 앱 번들 ID | `com.<company>.<app_slug>` |
| `project_root` | Flutter 앱 루트 디렉토리 (`pubspec.yaml`이 있는 곳, 기본값: 현재 작업 디렉토리) | `/path/to/projects/my_game` |
| `default_language` | 기본 로캘 코드 | `ko`, `en-US` |

### developer 인자

| 인자 | 설명 | 예시 |
|------|------|------|
| `developer.company` | 회사명 | `<company>` |
| `developer.first_name` | 앱 심사 담당자 이름 | `Gildong` |
| `developer.last_name` | 앱 심사 담당자 성 | `Hong` |
| `developer.email` | 연락처 이메일 | `dev@<company>.com` |
| `developer.phone` | 연락처 전화번호 | `+82-10-0000-0000` |
| `developer.privacy` | 개인정보 처리방침 URL | `https://<company>.com/privacy` |
| `developer.homepage` | 홈페이지 / 지원 URL | `https://<company>.com` |
| `developer.copyright` | 저작권 문자열 | `© 2026 <company>` |

### 호출 예시

```
/ship-submit
app_slug=my_game
bundle_id=com.mycompany.my_game
project_root=/path/to/projects/my_game
default_language=ko
developer.company=mycompany
developer.first_name=Gildong
developer.last_name=Hong
developer.email=dev@mycompany.com
developer.phone=+82-10-0000-0000
developer.privacy=https://mycompany.com/privacy
developer.homepage=https://mycompany.com
developer.copyright=© 2026 mycompany
```

> `project_root` 미지정 시 현재 작업 디렉토리를 사용한다.  
> 앱 프로젝트 경로: `<project_root>` 자체 (이하 `<app>` 으로 표기).

---

## Phase 0 — 스토어 정보 파일 생성

메타데이터 업로드 전에, 인자로 받은 `developer` 정보를 실제 fastlane 메타데이터 파일로 기록한다. 이 파일들은 deliver/supply가 자동으로 읽어 업로드한다.

### iOS (deliver가 자동 인식)

아래 파일을 생성·덮어쓴다:

- `<app>/ios/fastlane/metadata/copyright.txt` ← `developer.copyright`
- 각 로캘 디렉토리 (`ko`, `en-US` 등):
  - `support_url.txt` ← `developer.homepage`
  - `marketing_url.txt` ← `developer.homepage`
  - `privacy_url.txt` ← `developer.privacy`
- `<app>/ios/fastlane/metadata/review_information/`:
  - `first_name.txt` ← `developer.first_name`
  - `last_name.txt` ← `developer.last_name`
  - `phone_number.txt` ← `developer.phone`
  - `email_address.txt` ← `developer.email`
  - `notes.txt` ← 심사 노트 (ATT 화면 녹화 첨부 안내 등; 필요 시 사용자에게 확인)

### Android (Publisher API로 연락처 설정)

Google Play의 `supply`는 연락처 이메일·웹사이트 필드를 지원하지 않는다. 이 스킬에 동봉된 템플릿으로 스크립트를 생성하여 실행한다.

1. `templates/set_contact_details.rb.template`을 `<app>/android/fastlane/set_contact_details.rb`로 복사한다.
2. 다음 치환을 적용한다:
   - `__PACKAGE__` → `bundle_id`
   - `__EMAIL__` → `developer.email`
   - `__WEBSITE__` → `developer.homepage`
3. 스크립트를 실행한다:

```bash
cd <app>/android && ruby fastlane/set_contact_details.rb
```

스크립트 실행 전 `google-apis-androidpublisher_v3`와 `googleauth` gem이 설치되어 있어야 한다:

```bash
gem install google-apis-androidpublisher_v3 googleauth
```

키 파일은 `<app>/android/fastlane/play-store-key.json`에 있어야 한다.

> **개인정보 처리방침 URL**, Data Safety / 콘텐츠 등급 / 타겟 연령층 설문은 아래 Phase 2 수동 단계에서 Play Console에서 직접 설정한다.

---

## Phase 1 — 메타데이터 업로드

양 플랫폼에서 fastlane 메타데이터 및 카테고리 레인을 실행한다. 바이너리 업로드 없이 텍스트 메타데이터(현지화된 제목, 설명, 릴리스 노트)와 카테고리를 스토어에 푸시한다.

### iOS 메타데이터 업로드

```bash
cd <app>/ios
fastlane metadata
fastlane categories
```

- `fastlane metadata`: `ios/fastlane/metadata/` 아래 모든 로캘 텍스트 파일(제목, 부제목, 설명, 키워드, 홍보 텍스트, 릴리스 노트)을 deliver로 App Store Connect에 푸시한다.
- `fastlane categories`: 기본 및 보조 App Store 카테고리를 설정한다. `categories` 레인은 `ios/fastlane/Fastfile`에 미리 정의되어 있어야 한다.

### Android 메타데이터 업로드

```bash
cd <app>/android
fastlane metadata
fastlane release_notes
```

- `fastlane metadata`: `android/fastlane/metadata/android/` 아래 모든 로캘 텍스트 파일(제목, 짧은 설명, 전체 설명)을 `upload_to_play_store`(`skip_upload_apk: true`, `skip_upload_aab: true`)로 Google Play에 푸시한다.
- `fastlane release_notes`: 현재 릴리스의 `changelogs/<version-code>.txt` 파일을 푸시한다.

fastlane 레인이 비정상 종료(non-zero exit)하면 Phase 2로 진행하지 않는다. 오류 내용을 설명하고 중단한다. 재시도하려면 오류를 수정한 뒤 이 스킬을 다시 실행한다.

---

## Phase 2 — 수동 단계 안내

양 플랫폼의 업로드가 모두 성공하면, 자동화할 수 없는 최종 제출 동작을 위해 아래 안내를 출력한다.

**사전 심사 거절 체크리스트** (수동 단계와 함께 출력 — 실제로 발생했던 거절 사례):

- **ATT (2.1):** App Review Information → Notes에 실제 기기에서 녹화한 화면 녹화를 첨부한다. 신규 설치 → ATT 프롬프트가 추적보다 먼저 나타남 → 이후 흐름을 보여줘야 한다. (최신 iOS에서 프롬프트가 표시되려면 앱이 `wait-for-resumed` ATT 패턴을 사용해야 한다.)
- **알파 채널 없음:** iOS 아이콘 및 모든 스크린샷에 알파(투명도)가 없어야 한다.
- **빌드 번호 증가:** ASC는 중복 빌드 번호를 거부한다.
- **내보내기 규정 준수:** `ITSAppUsesNonExemptEncryption=false`를 설정하여 업로드마다 나타나는 프롬프트를 방지한다.
- **개인정보:** App Privacy에서 추적을 정확히 신고하고, `PrivacyInfo.xcprivacy`가 존재해야 한다.
- **Android:** 개인정보 처리방침 URL(`developer.privacy`) 설정; 콘텐츠 등급, Data Safety, 타겟 연령층 설문 완료. (연락처 이메일/웹사이트는 Phase 0에서 API 스크립트로 설정 완료.)

### 출력할 수동 단계 안내

---

**파이프라인 일시 중지 — 수동 제출 필요**

fastlane이 모든 텍스트 메타데이터와 카테고리를 업로드했습니다. Apple과 Google API는 심사 빌드가 준비된 후 사람의 확인 없이 완전히 자동화된 제출을 지원하지 않으므로, 최종 제출 단계를 수동으로 완료해야 합니다.

**iOS — 심사 제출 (Submit for Review)**

1. [App Store Connect](https://appstoreconnect.apple.com)를 열고 앱으로 이동한다.
2. 빌드 단계에서 업로드된 버전을 선택한다.
3. 빌드, 모든 스크린샷, 메타데이터가 올바르고 완전한지 확인한다.
4. **"Submit for Review"(심사 제출)**를 클릭한다.
5. Apple이 제시하는 사전 제출 설문(내보내기 규정 준수, 콘텐츠 권리, 광고 식별자/IDFA)에 답한다.
6. 제출을 확인한다. 앱 상태가 "Waiting for Review"로 변경된다.

**Android — 프로덕션 프로모션 (Promote to Production)**

1. [Google Play Console](https://play.google.com/console)을 열고 앱으로 이동한다.
2. **테스트 → 내부 테스트**로 이동하여 빌드 단계에서 업로드된 내부 트랙 릴리스를 찾는다.
3. 아직 완료하지 않은 경우 다음 설문을 완료한다 (Google Play API로 설정 불가):
   - **콘텐츠 등급** — IARC 설문을 완료한다.
   - **Data Safety** — 앱이 수집하는 데이터와 사용 방식을 신고한다.
   - **타겟 연령층** — 앱이 아동 대상이 아님을 확인한다 (해당 시).
4. 모든 설문이 완료되면 **"릴리스 프로모션 → 프로덕션"**을 클릭한다.
5. 출시 비율을 설정한다 (신규 앱은 100% 권장).
6. **"릴리스 검토"**를 클릭한 뒤 **"프로덕션 출시 시작"**을 클릭한다.

양 플랫폼에서 위 단계를 모두 완료한 뒤, 다음 작업(예: 회고, 사후 분석)을 진행하면 된다.

---

## 주의사항

- **`play-store-key.json` 경로:** 스크립트는 `__dir__`(스크립트 파일과 같은 디렉토리, 즉 `android/fastlane/`)를 기준으로 키 파일을 찾는다. 키 파일이 다른 위치에 있으면 스크립트의 `KEY` 경로를 수정한다.
- **fastlane 레인 미존재:** `categories` 레인이 `ios/fastlane/Fastfile`에 없으면 추가해야 한다. `release_notes` 레인도 마찬가지다.
- **로캘 디렉토리:** iOS 메타데이터의 로캘 디렉토리명은 App Store Connect 규격(`ko`, `en-US` 등)을 따라야 한다. Android는 `android/fastlane/metadata/android/<locale>/` 구조를 사용한다.
- **버전 코드 일치:** Android `release_notes`는 `changelogs/<version-code>.txt`가 현재 업로드된 빌드의 버전 코드와 일치해야 푸시된다.
