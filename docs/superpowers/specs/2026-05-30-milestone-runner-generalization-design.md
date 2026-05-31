# milestone-runner 범용화 설계

작성일: 2026-05-30

## 배경

`examples/band-of-mercenaries/skills/milestone-runner`는 강력한 워크플로우지만
band-of-mercenaries 게임에 강하게 종속되어 있어 examples(레퍼런스) 자리에 있다.
핵심 가치인 "체크포인트 + 상태파일 재개 + 승인 게이트 기반 스킬 체인 오케스트레이션"은
도메인 무관이므로, 종속 요소를 설정으로 빼내 `common/`에 범용 엔진으로 도입한다.

## 결정 사항

- **단계 구성**: 설정 주입형. 프로젝트가 단계 목록을 정의하면 엔진이 그 위에서
  체크포인트·재개·승인을 돌린다.
- **설정 위치**: 스킬 디렉토리에 동봉한 `pipeline.config.md` 템플릿. 프로젝트가
  복사 후 자기 단계로 채운다.
- **이름**: `milestone-runner` 유지 (마일스톤은 일반 SW 용어이기도 함).

## 배치

```
common/skills/milestone-runner/
  SKILL.md              범용 엔진
  pipeline.config.md    설정 템플릿 (프로젝트가 복사 후 채움)

examples/band-of-mercenaries/skills/milestone-runner/
  SKILL.md              그대로 보존 — 4페이즈 콘텐츠 파이프라인 구체 사례
```

examples 버전은 common 버전 config 작성 시 참고할 "채워진 예시" 역할을 한다.
동명이지만 examples와 common에 공존하며, 배포 시 한 프로젝트엔 하나만 들어가므로
충돌하지 않는다.

## pipeline.config.md 스키마

프로젝트가 채우는 항목:

1. **단계 목록** — 각 단계마다:
   - 단계 이름
   - 호출 스킬 (명령어 형식, 예: `/spec-writer @{입력경로}`)
   - 산출물 디렉토리
   - 선행 입력 참조 규칙 (어느 이전 단계 산출물을 입력으로 받는지)
2. **작업 단위(unit) 소스** — 단위 목록을 읽을 문서 경로와 식별 방법.
   소스가 없으면 호출 시 사용자와 대화로 단위를 정의한다.
3. **상태 파일 루트 경로** — 기본 `Docs/milestone-runs/`
4. **단계 스킵 정책** (선택) — 특정 단위에서 어떤 단계를 스킵할지 힌트

config 템플릿에는 각 항목의 작성 예시(주석)를 포함하고, band-of-mercenaries의
4페이즈 구성을 "채운 예시"로 함께 보여 작성법을 안내한다.

## SKILL.md 일반화 매핑

| 기존 (band-of-mercenaries 종속) | 범용 |
|---|---|
| 4페이즈 고정 (content→balance→data→spec) | config의 단계 목록을 Read하여 사용 |
| child 스킬 4종 하드코딩 | config의 단계별 호출 스킬 |
| `master_roadmap.md`의 M1~M9 마일스톤 | config가 가리키는 unit 소스, 또는 대화 정의 |
| `Docs/content-design/` 등 고정 경로 | config의 산출물 디렉토리 |
| 마일스톤별 스킵 힌트 표 (게임 시스템) | 제거 — 2단계 계획에서 대화로 결정 |
| 게임 톤·data-generator 타입스펙 언급 | 제거 |

## 유지하는 범용 가치 (변형 없이)

- `state.md` 마크다운 상태파일 (사람이 읽고 기계가 체크리스트로 파싱)
- 페이즈별 사용자 승인 체크포인트 (자동 진행 금지)
- **child 스킬 직접 호출 금지 + `--resume` 복귀** 패턴
- 다중 산출물 계획, 산출물 간 의존 관계 명시
- 단계 스킵
- 0~7단계 실행 절차 골격 (모드 판별 → 컨텍스트 로딩 → 계획 제안 → 상태파일 생성
  → 단계 시작 → 재개 → 종료 체크포인트 → 완료 보고)

## 호출 형식

```
/milestone-runner {unit} [--resume] [--phase N]
```

`{unit}`은 config의 unit 소스에서 추출하거나, 소스가 없으면 대화로 정의한다.
`--phase`는 단계 번호로 점프(1~N), `--resume`은 상태파일 기반 재개.

## 1단계(컨텍스트 로딩) 일반화

기존: master_roadmap / game_overview / content_status를 Read.
범용: `pipeline.config.md`를 Read하여 단계 정의·unit 소스를 파악하고, config가
가리키는 unit 소스 문서가 있으면 해당 unit 섹션을 Read한다. 게임 전용 문서 참조는
제거하고, "프로젝트가 config에 지정한 참고 문서"만 읽는다.

## 구현 방식

- examples 버전 SKILL.md를 베이스로 common으로 복사한 뒤, 위 매핑대로 일반화한다.
- config 스키마를 `pipeline.config.md`로 분리 작성한다.
- 원본 examples 버전은 보존한다 (수정하지 않음).
- README·CLAUDE.md 인덱스에 common 버전을 등재하고, examples 버전과의 관계
  (엔진 vs 채운 예시)를 한 줄로 설명한다.

## 비목표 (YAGNI)

- 병렬·분기(DAG) 파이프라인 미지원 — 선형 N단계만.
- child 스킬 자동 호출 미도입 — 기존 "사용자가 직접 실행 후 resume" 철학 유지.
- config를 yaml/json으로 만들지 않는다 — 마크다운 유지(kit 일관성, 사람 가독성).
