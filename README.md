# ai-dev-workflow-kit

여러 프로젝트(Unity, Flutter, Next.js)에 흩어져 있던 개인용 AI 스킬·에이전트를
한곳에 모아 관리하는 저장소다. 새 프로젝트를 시작할 때 사용하는 기술 스택에 맞춰
필요한 스킬·에이전트를 가져다 쓰는 것이 목표다.

현재는 Flutter 기반 `band-of-mercenaries`·`pace-counter`와 Unity 기반
`UnityCatClicker` 프로젝트의 스킬·에이전트를 수집한 단계로, Claude(`.md`)와
Codex(`.toml`) 양쪽 에이전트를 모두 담고 있다. `pace-counter`에서 가져온
Flutter↔Figma 동기화 워크플로우(디자인시스템 export + 픽셀 painter 파이프라인)는
`flutter/`에, `UnityCatClicker`에서 가져온 Unity 워크플로우(UGUI·Figma 변환,
프리팹 자동화, Unity 특화 명세·구현 파이프라인)는 `unity/`에 포함돼 있다.

## 디렉토리 구조

```
common/      스택 무관 범용 워크플로우 (skills/, agents/)
flutter/     Flutter 전용 (skills/, agents/)
unity/       Unity 전용 (skills/, agents/)
examples/    특정 프로젝트에 종속된 참고용 스킬 (재사용보다 레퍼런스)
docs/        설계·계획 문서
```

추후 `nextjs/` 가 같은 구조로 추가된다.

## 카테고리

- **common** — 기획→명세→구현→마무리 전 과정을 다루는 스택 무관 워크플로우.
- **flutter** — Flutter/Dart에 종속된 스킬·에이전트.
- **unity** — Unity/C#에 종속된 스킬·에이전트.
- **examples** — 특정 게임/도메인(용병단 전략 게임 + Supabase, 고양이 클리커 등)에
  강하게 종속되어 그대로는 재사용하기 어려운 스킬. 새 스킬을 만들 때 참고용으로 둔다.

## 스킬 인덱스

### common/skills

스택 무관 범용 워크플로우만 둔다. `implement-spec`·`spec-writer`·`finalize-feature`·
`finalize-minor-task` 등 스택마다 내용이 달라지는 것은 `flutter/`·`unity/` 스택
폴더에 둔다.

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| spec-pipeline | spec-writer → verify-spec 오케스트레이션 (런타임에 배포된 스택 버전 사용) | Sonnet |
| verify-spec | 명세서가 기획 의도를 반영했는지 5개 항목 검증 | Opus |
| docs-writer | 문서 작성·검토·편집 | Sonnet |
| merge-changelog | changelog fragment 병합 → CHANGELOG.md | Sonnet |
| google-sheets-safe-edit | Google Sheets write 도구 호출 전 백업·프리뷰·승인 게이트 | Sonnet |

### flutter/skills

`implement-spec`·`spec-writer`·`finalize-feature`·`finalize-minor-task`는 같은 역할의
Unity 버전이 `unity/`에도 있는 동명 스택별 스킬이다 (동명 스킬 네이밍 규칙 참고).

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| implement-agent | planner→coder→verifier→flutter-reviewer→dart-build-resolver 파이프라인 조율 | Opus |
| implement-spec | Flutter 특화 명세 기반 구현 (flutter analyze·build_runner 게이트) | Opus |
| spec-writer | 기획 문서 → Flutter 개발 명세서 생성 | Opus |
| finalize-feature | 기능 마무리 + 문서 갱신 + 커밋 (Provider/Hive/Supabase 체크리스트) | Sonnet |
| finalize-minor-task | 명세 없는 소규모 작업 마무리·아카이브 | Sonnet |
| flutter-figma-export | Flutter 위젯·토큰·스크린을 게이트 승인 거쳐 Figma로 export (에이전트 5종 조율) | Opus |
| pixel-painter-figma-sync | CustomPainter 픽셀아트를 SSOT 한 곳에서 Flutter·Figma가 동기화 | Opus |

### unity/skills

`implement-spec`·`spec-writer`·`finalize-feature`·`finalize-minor-task`·`merge-changelog`는
같은 역할의 Flutter 버전이 `flutter/`(merge-changelog는 `common/`)에도 있는 동명
스킬이다. Unity 특화(컴파일 검증·Addressable·SaveData·매니저 계층 등) 내용을 담은
별도 버전을 여기 둔다. 동명 스킬 네이밍 규칙(아래) 참고.

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| implement-agent | planner→coder→verifier 파이프라인 조율 (TASK 적으면 main 경량 검증) | Opus |
| implement-spec | Unity 특화 명세 기반 구현 (컴파일 검증 게이트) | Opus |
| spec-writer | 기획 문서 → Unity 개발 명세서 생성 | Opus |
| finalize-feature | 기능 마무리 + 문서 갱신 + 커밋 (SaveData/매니저 체크리스트) | Sonnet |
| finalize-minor-task | 명세 없는 소규모 작업 마무리·아카이브 | Sonnet |
| merge-changelog | changelog fragment 병합 → CHANGELOG.md | Sonnet |
| unity-developer | 모바일/WebGL 타깃 Unity URP 개발 전문 지식 (참조) | — |
| unity-refactor | 모듈 경계·SOLID·디커플링 등 아키텍처 리팩토링 어드바이저 | — |
| unity-script-rule | 라이프사이클·GetComponent 캐싱·물리 타이밍·Fake Null 실수 방지 | — |
| error-handling | Unity C# 에러 처리·방어적 코딩·로깅 규칙 (참조) | — |
| unity-ugui-ui | UGUI(UI_View/UI_Popup) 기반 UI 신규 생성·수정 | — |
| figma-to-ugui | Figma 레이어 → UGUI(UI_View/UI_Popup + Enum 바인딩) 변환 | — |
| automate-unity-task | unity_tasks.md → Unity Editor 프리팹 자동 생성 스크립트 작성 | Opus |

### examples/band-of-mercenaries/skills

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| content-designer | 게임 콘텐츠 기획·갭 분석 | Opus |
| balance-designer | 게임 밸런스·수식·경제 시뮬레이션 (Supabase) | Opus |
| data-generator | 콘텐츠 데이터 벌크 생성 → CSV → Supabase | Opus |
| milestone-runner | 마일스톤 4페이즈 체크포인트 진행 | Opus |

### examples/unity-cat-clicker/skills

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| content-designer | 고양이 클리커/방치형 게임 콘텐츠 기획·갭 분석 | Opus |
| balance-designer | 고양이 클리커/방치형 게임 밸런스·수식·경제 시뮬레이션 | Opus |

## 에이전트 인덱스

각 에이전트는 Claude용 `.md`와 Codex용 `.toml` 두 버전이 같은 폴더에 함께 있다
(예: `analyzer.md` + `analyzer.toml`). 아래 표는 역할 기준이며 두 형식에 공통이다.

### common/agents

현재 비어 있다. `analyzer`/`architect`/`coder`/`planner`/`verifier`는 내부 예시가
스택 종속이라 `flutter/agents`·`unity/agents`로 옮겼다. 향후 진짜 스택 무관 에이전트가
생기면 여기 둔다.

### flutter/agents

`analyzer`~`verifier`는 같은 역할의 Unity 버전이 `unity/`에도 있는 동명 스택별
에이전트다 (내부 예시가 Flutter/Dart — Riverpod·pubspec·freezed).

| 에이전트 | 설명 | 모델 |
|---|---|---|
| analyzer | 명세 분석 + Flutter 프로젝트 구조 파악 리포트 | Sonnet |
| architect | 분석 리포트 기반 구현 계획서 작성 | Opus |
| coder | 계획서의 개별 태스크 구현 | Sonnet |
| planner | analyzer + architect 통합 단일 패스 | Opus |
| verifier | 구현이 명세를 충족하는지 검증 | Opus |
| flutter-reviewer | Flutter/Dart 코드 품질 검증 (읽기 전용) | Opus |
| dart-build-resolver | Dart 빌드·정적분석·의존성 에러 해결 | Sonnet |
| flutter-figma-designer | 위젯→컴포넌트/variant 분류·네이밍·스크린 청사진 판단 | Opus |
| flutter-widget-analyzer | lib/ 위젯 사용 빈도 집계 (widget-usage.json) | Sonnet |
| flutter-token-extractor | 색/타이포/간격/radius 리터럴 추출·클러스터 + 리팩터 PR 계획 | Sonnet |
| flutter-figma-writer | 승인된 카탈로그·청사진을 Figma로 idempotent push | Sonnet |
| flutter-figma-screen-renderer | 화면 1개를 편집 레이어+캡처 레이어로 Figma 렌더 | Opus |

### unity/agents

`flutter/agents`의 `analyzer`~`verifier`와 역할은 같지만 내부 예시가 Unity/C#(Unity
버전·렌더 파이프라인, SaveData, 매니저 계층 등)으로 작성된 버전이다. `coder`는
`error-handling`·`unity-script-rule` 스킬을 preload한다. Codex `.toml`은 `planner`를
제외한 4종이 있다.

| 에이전트 | 설명 | 모델 |
|---|---|---|
| analyzer | 명세 분석 + Unity 프로젝트 구조 파악 리포트 | Sonnet |
| architect | 분석 리포트 기반 구현 계획서 작성 | Opus |
| coder | 계획서의 개별 태스크 구현 (Unity 규칙 스킬 preload) | Sonnet |
| planner | analyzer + architect 통합 단일 패스 (`.md`만 존재) | Opus |
| verifier | 구현이 명세를 충족하는지 검증 | Opus |

## 동명 스킬 네이밍 규칙

`implement-agent`처럼 같은 역할이지만 스택마다 내용이 다른 스킬은 **이름을
그대로 유지**하고 스택 폴더로 구분한다 (`flutter/skills/implement-agent`,
`unity/skills/implement-agent`). kit 안에서는 폴더가 달라 충돌하지 않고,
배포 시에는 한 프로젝트에 한 스택 버전만 들어가므로 충돌하지 않는다. 이름을
통일해 프로젝트 간 사용 경험을 일관되게 유지하기 위한 의도된 선택이다.

## 사용법

현재는 필요한 스킬·에이전트를 대상 프로젝트로 직접 복사해서 쓴다. 스킬(`SKILL.md`)은
플랫폼 공유이고, 에이전트는 Claude면 `.md`, Codex면 `.toml`을 복사한다. 아래 예시는
Flutter 기준이며, Unity 프로젝트면 `flutter/`를 `unity/`로 바꾸면 된다.

```bash
# 예: 새 Flutter 프로젝트에 Claude(.md) 기준으로 세팅
cp -R common/skills/*        <project>/.claude/skills/
cp -R flutter/skills/*       <project>/.claude/skills/
cp    flutter/agents/*.md    <project>/.claude/agents/
```

```bash
# 예: 같은 프로젝트에 Codex(.toml)도 세팅
#   스킬은 .agents/skills 에서 공유, 에이전트는 .codex/agents 에 toml
cp -R common/skills/*        <project>/.agents/skills/
cp -R flutter/skills/*       <project>/.agents/skills/
cp    flutter/agents/*.toml  <project>/.codex/agents/
```
(에이전트는 현재 스택 폴더에만 있다. `common/agents/`는 비어 있다.)

## 향후 계획

- Next.js 스킬·에이전트 수집
- 기술 스택을 고르면 자동으로 대상 프로젝트(`.claude/`·`.codex/`)에 세팅해주는 배포 도구
