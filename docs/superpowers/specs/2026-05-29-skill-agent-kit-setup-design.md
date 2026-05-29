# ai-dev-workflow-kit 스킬·에이전트 수집 설계

작성일: 2026-05-29

## 목적

여러 프로젝트(Unity, Flutter, Next.js)에 파편화되어 있는 개인용 AI 스킬·에이전트를 한곳에 모아 관리하는 kit를 만든다. 새 프로젝트를 시작할 때 사용하는 기술 스택에 맞춰 해당 스킬·에이전트를 가져다 쓸 수 있게 하는 것이 최종 목표다.

이번 작업은 그 첫 단계로, **Flutter 기반 `band-of-mercenaries` 프로젝트의 스킬·에이전트를 이 kit로 수집·정리하고 README를 작성**하는 데까지만 다룬다.

## 범위

### 이번 범위에 포함

- `band-of-mercenaries`의 Claude용 스킬(`.claude/skills`)·에이전트(`.claude/agents`)를 카테고리별로 분류해 복사
- kit 디렉토리 구조 확립 (스택-우선 분류)
- README.md 작성 (목적, 구조, 인덱스, 네이밍 규칙, 사용법)

### 이번 범위에서 제외

- Codex용 `.toml` 변환 (지금은 Claude `.md`만)
- 새 프로젝트로의 자동 배포 스크립트/스킬 (향후 단계)
- 게임 전용 스킬의 일반화/템플릿화 (참고용으로 그대로 보관)
- Unity, Next.js 스킬 수집 (추후 같은 구조로 추가)

## 분류 원칙

`band-of-mercenaries`의 스킬·에이전트를 세 카테고리로 나눈다.

| 카테고리 | 정의 | 위치 |
|---|---|---|
| 범용(common) | 스택과 무관하게 동작하는 워크플로우 | `common/` |
| Flutter 전용 | Flutter/Dart에 종속된 스킬·에이전트 | `flutter/` |
| 프로젝트 특화 예시 | 특정 게임/도메인에 강하게 종속 (재사용보다 레퍼런스) | `examples/band-of-mercenaries/` |

**동명 스킬 처리:** `implement-agent`처럼 스택마다 내용이 다른 동명 스킬은 **이름을 그대로 유지**하고 스택 폴더로 네임스페이스를 분리한다. kit 내부에서는 폴더가 다르므로 충돌하지 않고, 배포 시에는 한 프로젝트에 한 스택 버전만 들어가므로 충돌하지 않는다. 이름 통일은 프로젝트 간 일관된 사용 경험을 위한 의도된 선택이다.

## 최종 디렉토리 구조

```
ai-dev-workflow-kit/
├── README.md
├── docs/
│   └── superpowers/specs/        # 설계 문서
├── common/                       # 스택 무관 범용 워크플로우
│   ├── skills/
│   │   ├── spec-writer/          # 기획 문서 → 개발 명세서
│   │   ├── verify-spec/          # 명세서가 기획 의도를 반영했는지 검증
│   │   ├── spec-pipeline/        # spec-writer → verify-spec 오케스트레이션
│   │   ├── implement-spec/       # 명세 기반 구현 (에이전트 파이프라인 없음)
│   │   ├── docs-writer/          # 문서 작성·검토·편집
│   │   ├── merge-changelog/      # changelog fragment 병합
│   │   ├── finalize-feature/     # 기능 마무리 + 문서 갱신 + 커밋
│   │   └── finalize-minor-task/  # 명세 없는 소규모 작업 마무리·아카이브
│   └── agents/
│       ├── analyzer/             # 명세 분석 + 프로젝트 구조 파악 리포트
│       ├── architect/            # 분석 리포트 기반 구현 계획서 작성
│       ├── coder/                # 계획서의 개별 태스크 구현
│       ├── planner/              # analyzer + architect 통합 단일 패스
│       └── verifier/             # 구현이 명세를 충족하는지 검증
├── flutter/                      # Flutter 전용
│   ├── skills/
│   │   └── implement-agent/      # planner→coder→verifier→flutter-reviewer→dart-build-resolver 파이프라인 조율
│   └── agents/
│       ├── flutter-reviewer/     # Flutter/Dart 코드 품질 검증 (읽기 전용)
│       └── dart-build-resolver/  # Dart 빌드·정적분석·의존성 에러 해결
└── examples/                     # 프로젝트 특화 참고 예시
    └── band-of-mercenaries/      # 용병단 전략 게임 (Flutter + Supabase)
        └── skills/
            ├── content-designer/  # 게임 콘텐츠 기획·갭 분석
            ├── balance-designer/  # 게임 밸런스·수식·경제 시뮬레이션
            ├── data-generator/    # 콘텐츠 데이터 벌크 생성 → CSV → Supabase (types/ 포함)
            └── milestone-runner/  # 마일스톤 4페이즈 체크포인트 진행
```

추후 `unity/`, `nextjs/` 가 같은 `{skills,agents}/` 구조로 추가된다.

## 데이터 흐름 (복사 매핑)

원본은 `band-of-mercenaries/.claude/`, 대상은 `ai-dev-workflow-kit/`.

| 원본 | 대상 |
|---|---|
| `.claude/skills/{spec-writer, verify-spec, spec-pipeline, implement-spec, docs-writer, merge-changelog, finalize-feature, finalize-minor-task}` | `common/skills/` |
| `.claude/agents/{analyzer, architect, coder, planner, verifier}.md` | `common/agents/<name>/` (또는 평면 `.md` — 아래 결정 참고) |
| `.claude/skills/implement-agent` | `flutter/skills/implement-agent` |
| `.claude/agents/{flutter-reviewer, dart-build-resolver}.md` | `flutter/agents/<name>/` |
| `.claude/skills/{content-designer, balance-designer, data-generator, milestone-runner}` | `examples/band-of-mercenaries/skills/` |

**에이전트 파일 형식 결정:** 원본 에이전트는 단일 `.md` 파일(`analyzer.md` 등)이다. kit에서도 동일하게 평면 `.md` 파일로 보관한다 (`common/agents/analyzer.md`). 디렉토리로 감싸지 않는다 — 스킬은 `SKILL.md`를 담는 디렉토리 단위지만 에이전트는 단일 파일이 원본 규약이므로 그대로 따른다. (구조 다이어그램의 `analyzer/` 표기는 가독성을 위한 것이며 실제로는 `analyzer.md`.)

## README.md 구성

- kit의 목적과 배경 (멀티 스택 개인 워크플로우 모음)
- 디렉토리 구조와 카테고리(common / flutter / examples) 설명
- 전체 스킬·에이전트 인덱스: 이름 · 한 줄 설명 · 스택 · 권장 모델
- 동명 스킬 네이밍 규칙 (스택 폴더 네임스페이스)
- common 에이전트 주의: 역할은 범용이나 내부에 Flutter 예시가 일부 포함되어 있어 타 스택에서 쓸 때 일반화가 필요함
- 사용법: 현재는 필요한 스킬·에이전트 폴더를 대상 프로젝트의 `.claude/`로 수동 복사. 배포 자동화는 향후 계획
- 향후 계획: Codex `.toml` 지원, Unity/Next.js 수집, 스택 기반 배포 도구

## 검증 방법

- 복사 후 각 대상 디렉토리의 파일 수·이름이 원본과 일치하는지 확인 (특히 `data-generator/types/`의 하위 파일들)
- 원본은 변경하지 않음 (읽기 전용 복사)
- README의 인덱스가 실제 복사된 항목과 1:1로 맞는지 대조
