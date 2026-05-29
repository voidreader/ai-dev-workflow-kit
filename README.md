# ai-dev-workflow-kit

여러 프로젝트(Unity, Flutter, Next.js)에 흩어져 있던 개인용 AI 스킬·에이전트를
한곳에 모아 관리하는 저장소다. 새 프로젝트를 시작할 때 사용하는 기술 스택에 맞춰
필요한 스킬·에이전트를 가져다 쓰는 것이 목표다.

현재는 Flutter 기반 `band-of-mercenaries` 프로젝트의 Claude용 스킬·에이전트를
수집한 첫 단계 상태다.

## 디렉토리 구조

```
common/      스택 무관 범용 워크플로우 (skills/, agents/)
flutter/     Flutter 전용 (skills/, agents/)
examples/    특정 프로젝트에 종속된 참고용 스킬 (재사용보다 레퍼런스)
docs/        설계·계획 문서
```

추후 `unity/`, `nextjs/` 가 같은 구조로 추가된다.

## 카테고리

- **common** — 기획→명세→구현→마무리 전 과정을 다루는 스택 무관 워크플로우.
- **flutter** — Flutter/Dart에 종속된 스킬·에이전트.
- **examples** — 특정 게임/도메인(여기서는 용병단 전략 게임 + Supabase)에 강하게
  종속되어 그대로는 재사용하기 어려운 스킬. 새 스킬을 만들 때 참고용으로 둔다.

## 스킬 인덱스

### common/skills

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| spec-writer | 기획 문서 → 개발 명세서 생성 | Sonnet |
| verify-spec | 명세서가 기획 의도를 반영했는지 5개 항목 검증 | Opus |
| spec-pipeline | spec-writer → verify-spec 오케스트레이션 | Sonnet |
| implement-spec | 명세 기반 구현 (에이전트 파이프라인 없음) | Sonnet |
| docs-writer | 문서 작성·검토·편집 | Sonnet |
| merge-changelog | changelog fragment 병합 → CHANGELOG.md | Sonnet |
| finalize-feature | 기능 마무리 + 문서 갱신 + 커밋 | Sonnet |
| finalize-minor-task | 명세 없는 소규모 작업 마무리·아카이브 | Sonnet |

### flutter/skills

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| implement-agent | planner→coder→verifier→flutter-reviewer→dart-build-resolver 파이프라인 조율 | Opus |

### examples/band-of-mercenaries/skills

| 스킬 | 설명 | 권장 모델 |
|---|---|---|
| content-designer | 게임 콘텐츠 기획·갭 분석 | Opus |
| balance-designer | 게임 밸런스·수식·경제 시뮬레이션 (Supabase) | Opus |
| data-generator | 콘텐츠 데이터 벌크 생성 → CSV → Supabase | Opus |
| milestone-runner | 마일스톤 4페이즈 체크포인트 진행 | Opus |

## 에이전트 인덱스

### common/agents

| 에이전트 | 설명 | 모델 |
|---|---|---|
| analyzer | 명세 분석 + 프로젝트 구조 파악 리포트 | Sonnet |
| architect | 분석 리포트 기반 구현 계획서 작성 | Opus |
| coder | 계획서의 개별 태스크 구현 | Sonnet |
| planner | analyzer + architect 통합 단일 패스 | Opus |
| verifier | 구현이 명세를 충족하는지 검증 | Opus |

> **주의:** common 에이전트는 역할 자체는 스택 무관이지만 내부 예시에
> Flutter/Dart 표현이 일부 섞여 있다. 다른 스택에서 쓸 때는 해당 부분을
> 일반화해서 사용한다.

### flutter/agents

| 에이전트 | 설명 | 모델 |
|---|---|---|
| flutter-reviewer | Flutter/Dart 코드 품질 검증 (읽기 전용) | Opus |
| dart-build-resolver | Dart 빌드·정적분석·의존성 에러 해결 | Sonnet |

## 동명 스킬 네이밍 규칙

`implement-agent`처럼 같은 역할이지만 스택마다 내용이 다른 스킬은 **이름을
그대로 유지**하고 스택 폴더로 구분한다 (`flutter/skills/implement-agent`,
추후 `unity/skills/implement-agent`). kit 안에서는 폴더가 달라 충돌하지 않고,
배포 시에는 한 프로젝트에 한 스택 버전만 들어가므로 충돌하지 않는다. 이름을
통일해 프로젝트 간 사용 경험을 일관되게 유지하기 위한 의도된 선택이다.

## 사용법

현재는 필요한 스킬·에이전트 폴더를 대상 프로젝트의 `.claude/skills/`,
`.claude/agents/`로 직접 복사해서 쓴다.

```bash
# 예: 새 Flutter 프로젝트에 공통 + Flutter 스킬 세팅
cp -R common/skills/*   <project>/.claude/skills/
cp -R common/agents/*   <project>/.claude/agents/
cp -R flutter/skills/*  <project>/.claude/skills/
cp -R flutter/agents/*  <project>/.claude/agents/
```

## 향후 계획

- Codex용 `.toml` 에이전트 지원
- Unity, Next.js 스킬·에이전트 수집
- 기술 스택을 고르면 자동으로 대상 프로젝트에 세팅해주는 배포 도구
