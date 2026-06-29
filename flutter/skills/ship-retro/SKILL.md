---
name: ship-retro
description: Flutter 앱 릴리스 완료 후 증거 기반으로 릴리스 회고 문서를 생성한다. Keep / Problem / Try + 릴리스 체크리스트 점검 결과를 Docs/retro.md에 기록한다.
argument-hint: "[project_root] [--changelog <path>] [--build-log <path>] [--out <path>]"
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# ship-retro

Flutter 앱의 릴리스 사이클이 끝난 후 실행하는 **릴리스 회고(release retrospective) 문서 생성기**다.

`git log`, CHANGELOG, 빌드 산출물, 스토어 제출 결과 등 실제로 존재하는 아티팩트를 근거로 삼아 증거 기반 회고를 작성한다. harness 파이프라인 없이도, **임의의 Flutter 프로젝트**에서 단독으로 실행할 수 있다.

---

## 인자 / 사용법

```
/ship-retro [project_root] [--changelog <path>] [--build-log <path>] [--out <path>]
```

| 인자 | 필수 | 설명 |
|---|---|---|
| `project_root` | 선택 | Flutter 프로젝트 루트 경로. 생략 시 현재 작업 디렉토리 사용. |
| `--changelog <path>` | 선택 | CHANGELOG 또는 릴리스 노트 파일 경로. 생략 시 `<project_root>/CHANGELOG.md` 를 탐색. |
| `--build-log <path>` | 선택 | 빌드 로그 파일 경로. 생략 시 `<project_root>/Docs/build-log.md` 를 탐색. |
| `--out <path>` | 선택 | 출력 파일 경로. 생략 시 `<project_root>/Docs/retro.md`. |

인자가 없으면 현재 작업 디렉토리를 `project_root`로 사용하고 표준 경로에서 아티팩트를 탐색한다.

---

## 1단계: 프로젝트 루트 및 인자 확인

1. `project_root` 를 결정한다 (인자 우선, 없으면 현재 작업 디렉토리).
2. `<project_root>/pubspec.yaml` 이 존재하는지 확인한다. 없으면 "Flutter 프로젝트를 찾을 수 없습니다. project_root 인자를 확인해주세요." 메시지를 출력하고 중단한다.
3. `pubspec.yaml` 에서 `name:` 과 `version:` 을 읽어 `app_name` 과 `app_version` 을 추출한다.
4. 출력 경로(`--out`)가 지정되지 않았으면 `<project_root>/Docs/retro.md` 를 기본값으로 설정한다. `Docs/` 디렉토리가 없으면 생성한다.

---

## 2단계: 아티팩트 수집

아래 아티팩트를 순서대로 탐색·로드한다. **파일이 없으면 해당 섹션을 건너뛰고 "아티팩트 없음"으로 기록한다** — 오류로 중단하지 않는다.

### 2-A. Git 로그

```bash
git -C <project_root> log --oneline -50
```

- 커밋 수, 주요 커밋 메시지 패턴, 릴리스 브랜치·태그 여부를 파악한다.
- 릴리스 태그(`v*`)가 있으면 마지막 릴리스 태그 이후의 커밋만 범위로 사용한다.

### 2-B. CHANGELOG / 릴리스 노트

`--changelog` 인자 경로 → `<project_root>/CHANGELOG.md` → `<project_root>/CHANGELOG` 순서로 탐색한다.

이번 릴리스 버전 섹션을 읽어 추가된 기능, 버그 픽스, 주요 변경 사항을 파악한다.

### 2-C. 빌드 로그

`--build-log` 인자 경로 → `<project_root>/Docs/build-log.md` 순서로 탐색한다.

빌드 성공/실패 이력, 재시도 횟수, CI 결과 등을 확인한다.

### 2-D. ship-* 단계 산출물 (있을 경우만)

다음 파일이 존재하면 읽는다. 없으면 건너뛴다.

| 파일 | 내용 |
|---|---|
| `<project_root>/Docs/ship-build-result.md` | `ship-build` 스킬 결과 — 아카이브 경로, 빌드 시간, flutter analyze/test 결과 |
| `<project_root>/Docs/ship-screenshot-result.md` | `ship-screenshot` 스킬 결과 — 스크린샷 목록, 플랫폼, 해상도 |
| `<project_root>/Docs/ship-admob-result.md` | `ship-admob` 스킬 결과 — AdMob 광고 단위 설정 여부 |
| `<project_root>/Docs/ship-submit-result.md` | `ship-submit` 스킬 결과 — App Store Connect / Google Play 제출 상태 |

### 2-E. 스크린샷 디렉토리

`<project_root>/screenshots/` 또는 `<project_root>/fastlane/screenshots/` 가 존재하면 디렉토리 구조를 확인해 플랫폼별 스크린샷 유무를 파악한다.

```bash
find <project_root>/screenshots <project_root>/fastlane/screenshots -name "*.png" -o -name "*.jpg" 2>/dev/null | head -30
```

### 2-F. 테스트 결과

```bash
cd <project_root> && flutter test --reporter json 2>/dev/null | tail -5
```

실패 시 "테스트 실행 불가"로 기록하고 계속 진행한다.

---

## 3단계: 릴리스 체크리스트 점검

2단계에서 수집한 증거를 바탕으로 아래 항목을 **PASS / FAIL / SKIP** 으로 평가한다.

- **PASS**: 수집한 증거로 완료를 확인했다.
- **FAIL**: 증거가 실패 또는 미완료를 나타낸다.
- **SKIP**: 해당 항목의 아티팩트가 없어 평가할 수 없다.

| # | 항목 | 평가 근거 |
|---|---|---|
| 1 | `flutter analyze` 오류 0개 | ship-build-result.md 또는 직접 실행 결과 |
| 2 | `flutter test` 실패 0개 | ship-build-result.md 또는 직접 실행 결과 |
| 3 | iOS 빌드 아카이브 생성 | ship-build-result.md 또는 .ipa 파일 존재 여부 |
| 4 | Android 빌드 번들 생성 | ship-build-result.md 또는 .aab 파일 존재 여부 |
| 5 | iOS 스크린샷 준비 | screenshots/ 디렉토리 또는 ship-screenshot-result.md |
| 6 | Android 스크린샷 준비 | screenshots/ 디렉토리 또는 ship-screenshot-result.md |
| 7 | App Store Connect 제출 | ship-submit-result.md |
| 8 | Google Play 제출 | ship-submit-result.md |
| 9 | AdMob 광고 단위 설정 | ship-admob-result.md (없으면 SKIP) |
| 10 | 버전 번호 일관성 | pubspec.yaml version vs CHANGELOG vs 빌드 결과 |

---

## 4단계: Keep / Problem / Try 작성

수집한 증거와 체크리스트 결과를 바탕으로 회고를 작성한다.

### Keep (잘 된 것)

다음 항목 중 해당하는 것을 구체적인 증거와 함께 나열한다:

- 첫 시도에 PASS 된 체크리스트 항목 (재시도 없이 통과한 것)
- CHANGELOG 기준으로 계획한 기능이 빠짐없이 포함된 경우
- 빌드 로그에서 재시도 없이 성공한 단계
- 스크린샷이 양 플랫폼 모두 준비된 경우
- git 커밋 메시지가 일관된 컨벤션을 따른 경우

근거 없는 항목은 포함하지 않는다.

### Problem (문제점)

다음 항목 중 해당하는 것을 나열한다:

- FAIL 또는 여러 번 재시도가 필요했던 체크리스트 항목
- 빌드 로그에서 반복된 오류 패턴
- SKIP 항목 중 이번 릴리스에 필요했어야 할 것
- CHANGELOG와 실제 포함된 기능 간의 불일치
- 버전 번호 불일치

### Try (다음에 시도할 것)

Problem 섹션의 각 항목에 대해 구체적인 개선 방안을 제안한다. 형식: `[Problem #]에 대응 — <구체적인 조치>`.

---

## 5단계: retro.md 생성

아래 구조로 출력 파일을 작성한다.

```markdown
# 릴리스 회고 — <app_name> v<app_version>

> 작성일: <ISO-8601 날짜>
> 프로젝트 루트: <project_root>
> 참조 아티팩트: <로드한 파일 목록, 없으면 "git log만 사용">

---

## 릴리스 체크리스트

| # | 항목 | 상태 | 근거 |
|---|---|---|---|
| 1 | flutter analyze 오류 0개 | PASS/FAIL/SKIP | <한 줄 근거> |
| 2 | flutter test 실패 0개 | PASS/FAIL/SKIP | <한 줄 근거> |
| 3 | iOS 빌드 아카이브 | PASS/FAIL/SKIP | <한 줄 근거> |
| 4 | Android 빌드 번들 | PASS/FAIL/SKIP | <한 줄 근거> |
| 5 | iOS 스크린샷 | PASS/FAIL/SKIP | <한 줄 근거> |
| 6 | Android 스크린샷 | PASS/FAIL/SKIP | <한 줄 근거> |
| 7 | App Store Connect 제출 | PASS/FAIL/SKIP | <한 줄 근거> |
| 8 | Google Play 제출 | PASS/FAIL/SKIP | <한 줄 근거> |
| 9 | AdMob 광고 단위 | PASS/FAIL/SKIP | <한 줄 근거> |
| 10 | 버전 번호 일관성 | PASS/FAIL/SKIP | <한 줄 근거> |

**PASS: N / FAIL: N / SKIP: N**

---

## Keep / Problem / Try

### Keep

- <증거 인용과 함께 잘 된 항목>

### Problem

- <증거 인용과 함께 문제 항목>

### Try

- <Problem 번호 대응 개선 방안>

---

## 커밋 요약

> git log 기반 — 마지막 릴리스 태그 이후 <N>개 커밋

| 범주 | 건수 |
|---|---|
| feat | N |
| fix | N |
| chore / docs / refactor | N |
| 기타 | N |

---

## 참조 아티팩트

| 파일 | 상태 |
|---|---|
| CHANGELOG.md | 존재 / 없음 |
| Docs/build-log.md | 존재 / 없음 |
| Docs/ship-build-result.md | 존재 / 없음 |
| Docs/ship-screenshot-result.md | 존재 / 없음 |
| Docs/ship-admob-result.md | 존재 / 없음 |
| Docs/ship-submit-result.md | 존재 / 없음 |
```

---

## 완료 메시지

파일 작성 후 다음 요약을 출력한다:

---

**릴리스 회고 완료**

출력 파일: `<retro.md 절대 경로>`

체크리스트: PASS N / FAIL N / SKIP N

회고 결과를 검토하고 Problem 항목의 개선 방안을 다음 릴리스에 반영하세요.
