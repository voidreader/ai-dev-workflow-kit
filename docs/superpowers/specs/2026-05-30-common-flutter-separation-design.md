# common ↔ flutter 분리 정리 설계

작성일: 2026-05-30

## 배경

kit의 `common/` 스킬·에이전트 다수가 이름은 common이지만 실제 내용은
Flutter(`band_of_mercenaries`, `pace-counter`) 프로젝트에서 그대로 가져온
Flutter/Dart 특화 상태다. Unity 워크플로우를 `unity/`로 수집하면서
동명 스킬(`implement-spec`, `spec-writer`, `finalize-*`, agents 5종)의
Unity 버전이 `unity/`에 생겼고, 그 결과 같은 역할의 Flutter 버전이 `common/`에
잘못 놓여 있음이 드러났다.

`common/`은 "스택 무관 범용"이어야 한다(CLAUDE.md). Flutter 특화본을 `flutter/`로
옮기고 common을 진짜 범용만 남도록 정리한다.

## 분류 근거

`common/` 전체를 Flutter/게임 키워드(flutter, dart, riverpod, hive, supabase,
freezed, pubspec, build_runner, band_of_mercenaries, 퀘스트, 용병 등)로 스캔한 결과:

| 항목 | 종류 | 판정 |
|---|---|---|
| implement-spec | skill | Flutter 종속 (flutter analyze, build_runner, dart-build-resolver) |
| spec-writer | skill | Flutter 종속 (Provider/Notifier/Widget, Hive, Supabase) |
| finalize-feature | skill | Flutter 종속 (Provider/Hive/Supabase 체크리스트) |
| finalize-minor-task | skill | Flutter 종속 (band_of_mercenaries/lib, build_runner) |
| analyzer~verifier | agent ×5 | Flutter 종속 (Riverpod, pubspec, freezed) — `.md`/`.toml` 모두 |
| merge-changelog | skill | 본질 범용, **예시만** band_of_mercenaries(퀘스트) 게임 종속 |
| docs-writer | skill | 스택 중립 (범용) |
| spec-pipeline | skill | 스택 중립 (런타임에 배포된 spec-writer/verify-spec을 Read) |
| verify-spec | skill | 스택 중립 (범용) |
| google-sheets-safe-edit | skill | 스택 중립 (범용 유틸) |

## 결정

### flutter/로 이동 (common에서 제거)
- skills: `implement-spec`, `spec-writer`, `finalize-feature`, `finalize-minor-task`
- agents: `analyzer`, `architect`, `coder`, `planner`, `verifier` (`.md` + `.toml`)

`flutter/`에는 동일 이름이 없어 충돌하지 않는다. `unity/`에는 이미 Unity 버전이
있으므로, 이동 후 두 스택 버전이 동명 스킬 네이밍 규칙대로 각 폴더에 공존한다.

### common에 유지
- skills: `docs-writer`, `spec-pipeline`, `verify-spec`, `google-sheets-safe-edit`
- skills: `merge-changelog` — **예시를 스택 무관 예시로 중립화**한다
  (퀘스트/용병/파견 예시 → 일반 기능/버그 수정 예시, 파일명 예시도 중립으로)
- agents: 빈 폴더 + `.gitkeep` (향후 범용 에이전트 자리 확보)

### 의존성 확인
- `spec-pipeline`은 `.claude/skills/spec-writer/SKILL.md`,
  `.claude/skills/verify-spec/SKILL.md`를 런타임에 Read한다. spec-writer가
  common에서 빠져도, 배포 시 대상 프로젝트의 스택 버전이
  `.claude/skills/spec-writer/`에 설치되므로 spec-pipeline은 정상 작동한다.
  따라서 spec-writer를 common에 남길 필요는 없다.

## 방법

- kit 내부 이동이므로 `git mv`로 히스토리를 보존한다 (tracked 파일 기준).
- 원본 프로젝트(UnityCatClicker, band_of_mercenaries 등)는 건드리지 않는다.
- 이동 후 `git status`와 디렉토리 구조로 결과를 검증한다.

## 문서 갱신

- **README.md**:
  - `common/skills` 표에서 이동한 4종 제거, `merge-changelog` 설명 유지
  - `flutter/skills` 표에 이동한 4종 추가
  - `flutter/agents` 표에 analyzer~verifier 5종 추가
  - `common/agents` 섹션을 "현재 비어 있음(향후 범용 에이전트 예정)"으로 정리,
    기존 "Flutter 표현 섞임" 주의문 제거
- **CLAUDE.md**: 구조/규칙 설명이 실제와 어긋나면 보정 (필요 시)

## 비목표 (YAGNI)

- common에 일반화된 범용 버전을 새로 작성하지 않는다. 실제 사용은 스택 폴더에서
  복사하는 방식이므로, 쓰이지 않을 일반화본을 미리 만들지 않는다.
- merge-changelog 외 다른 스킬의 본문 로직은 변경하지 않는다 (순수 이동).
