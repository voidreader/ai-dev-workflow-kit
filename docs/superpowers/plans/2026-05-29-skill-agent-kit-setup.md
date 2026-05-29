# 스킬·에이전트 수집 kit 구성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** band-of-mercenaries의 Claude 스킬·에이전트를 ai-dev-workflow-kit으로 카테고리별 복사하고 README를 작성한다.

**Architecture:** 원본(`band-of-mercenaries/.claude/`)을 읽기 전용으로 복사한다. 스택-우선 분류(`common/`, `flutter/`, `examples/`)로 배치하고, 각 단계마다 파일 수·이름을 원본과 대조해 검증한다. 코드 작성이 아니라 파일 수집이므로 검증은 셸 대조로 수행한다.

**Tech Stack:** 셸(cp, ls, diff, find), git, Markdown

> 경로 약어: `SRC=/Users/radiogaga/git/band-of-mercenaries/.claude`, `DST=/Users/radiogaga/git/ai-dev-workflow-kit`. 모든 명령은 실제 절대경로로 실행한다.

---

### Task 1: common 스킬 복사 (8개)

**Files:**
- Create: `common/skills/{spec-writer, verify-spec, spec-pipeline, implement-spec, docs-writer, merge-changelog, finalize-feature, finalize-minor-task}/SKILL.md`
- Source: `band-of-mercenaries/.claude/skills/<동일이름>/`

- [ ] **Step 1: 대상 디렉토리 생성 및 복사**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
mkdir -p "$DST/common/skills"
for s in spec-writer verify-spec spec-pipeline implement-spec docs-writer merge-changelog finalize-feature finalize-minor-task; do
  cp -R "$SRC/skills/$s" "$DST/common/skills/$s"
done
```

- [ ] **Step 2: 복사 검증 — 8개 디렉토리 + 각 SKILL.md 존재**

```bash
DST=/Users/radiogaga/git/ai-dev-workflow-kit
ls "$DST/common/skills" | wc -l   # 기대: 8
find "$DST/common/skills" -name SKILL.md | wc -l   # 기대: 8
```
Expected: 각각 8

- [ ] **Step 3: 커밋**

```bash
cd /Users/radiogaga/git/ai-dev-workflow-kit
git add common/skills
git commit -m "공통 워크플로우 스킬 8종 추가

spec-writer, verify-spec, spec-pipeline, implement-spec, docs-writer,
merge-changelog, finalize-feature, finalize-minor-task"
```

---

### Task 2: common 에이전트 복사 (5개, 평면 .md)

**Files:**
- Create: `common/agents/{analyzer, architect, coder, planner, verifier}.md`
- Source: `band-of-mercenaries/.claude/agents/<동일이름>.md`

- [ ] **Step 1: 복사**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
mkdir -p "$DST/common/agents"
for a in analyzer architect coder planner verifier; do
  cp "$SRC/agents/$a.md" "$DST/common/agents/$a.md"
done
```

- [ ] **Step 2: 검증 — 5개 .md, 원본과 내용 동일**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
ls "$DST/common/agents"/*.md | wc -l   # 기대: 5
for a in analyzer architect coder planner verifier; do
  diff -q "$SRC/agents/$a.md" "$DST/common/agents/$a.md"   # 차이 없어야 함(출력 없음)
done
```
Expected: 5 / diff 출력 없음

- [ ] **Step 3: 커밋**

```bash
cd /Users/radiogaga/git/ai-dev-workflow-kit
git add common/agents
git commit -m "공통 서브에이전트 5종 추가

analyzer, architect, coder, planner, verifier (스펙 구현 파이프라인용)"
```

---

### Task 3: flutter 스킬·에이전트 복사

**Files:**
- Create: `flutter/skills/implement-agent/SKILL.md`
- Create: `flutter/agents/{flutter-reviewer, dart-build-resolver}.md`
- Source: 동일 이름

- [ ] **Step 1: 복사**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
mkdir -p "$DST/flutter/skills" "$DST/flutter/agents"
cp -R "$SRC/skills/implement-agent" "$DST/flutter/skills/implement-agent"
for a in flutter-reviewer dart-build-resolver; do
  cp "$SRC/agents/$a.md" "$DST/flutter/agents/$a.md"
done
```

- [ ] **Step 2: 검증**

```bash
DST=/Users/radiogaga/git/ai-dev-workflow-kit
test -f "$DST/flutter/skills/implement-agent/SKILL.md" && echo "implement-agent OK"
ls "$DST/flutter/agents"/*.md | wc -l   # 기대: 2
```
Expected: "implement-agent OK" / 2

- [ ] **Step 3: 커밋**

```bash
cd /Users/radiogaga/git/ai-dev-workflow-kit
git add flutter
git commit -m "Flutter 전용 스킬·에이전트 추가

implement-agent 파이프라인 스킬과 flutter-reviewer, dart-build-resolver 에이전트"
```

---

### Task 4: 게임 전용 스킬을 examples로 복사 (4개)

**Files:**
- Create: `examples/band-of-mercenaries/skills/{content-designer, balance-designer, data-generator, milestone-runner}/`
- Note: `data-generator`는 `types/` 하위 10개 파일 포함

- [ ] **Step 1: 복사 (-R로 types/ 포함)**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
mkdir -p "$DST/examples/band-of-mercenaries/skills"
for s in content-designer balance-designer data-generator milestone-runner; do
  cp -R "$SRC/skills/$s" "$DST/examples/band-of-mercenaries/skills/$s"
done
```

- [ ] **Step 2: 검증 — 4개 스킬 + data-generator/types 10개 파일**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
ls "$DST/examples/band-of-mercenaries/skills" | wc -l   # 기대: 4
ls "$DST/examples/band-of-mercenaries/skills/data-generator/types"/*.md | wc -l   # 기대: 10
diff -rq "$SRC/skills/data-generator" "$DST/examples/band-of-mercenaries/skills/data-generator"   # 차이 없어야 함
```
Expected: 4 / 10 / diff 출력 없음

- [ ] **Step 3: 커밋**

```bash
cd /Users/radiogaga/git/ai-dev-workflow-kit
git add examples
git commit -m "band-of-mercenaries 게임 전용 스킬을 예시로 보관

content-designer, balance-designer, data-generator, milestone-runner
특정 게임/Supabase에 종속되어 재사용보다 참고용"
```

---

### Task 5: 전체 복사 무결성 최종 검증

원본 대비 누락·오염이 없는지 한 번에 대조한다. 코드가 아니므로 테스트 대신 대조 스크립트로 검증한다.

- [ ] **Step 1: 스킬 13개 전부 어딘가에 복사되었는지 대조**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
# 원본 스킬 13개 각각이 kit 어딘가에 SKILL.md로 존재하는지
for s in $(ls "$SRC/skills"); do
  found=$(find "$DST" -path "*/$s/SKILL.md" | head -1)
  [ -n "$found" ] && echo "OK  $s -> $found" || echo "MISSING $s"
done
```
Expected: 13줄 모두 "OK", "MISSING" 없음

- [ ] **Step 2: 에이전트 7개 전부 복사되었는지 대조**

```bash
SRC=/Users/radiogaga/git/band-of-mercenaries/.claude
DST=/Users/radiogaga/git/ai-dev-workflow-kit
for a in $(ls "$SRC/agents"); do
  found=$(find "$DST" -name "$a" | head -1)
  [ -n "$found" ] && echo "OK  $a -> $found" || echo "MISSING $a"
done
```
Expected: 7줄 모두 "OK"

- [ ] **Step 3: 원본 미변경 확인**

```bash
cd /Users/radiogaga/git/band-of-mercenaries
git status --short .claude   # 출력 없어야 함 (원본 건드리지 않음)
```
Expected: 출력 없음

(검증만 하므로 커밋 없음)

---

### Task 6: README.md 작성

**Files:**
- Create: `README.md` (저장소 루트)

- [ ] **Step 1: README 작성**

아래 내용을 `/Users/radiogaga/git/ai-dev-workflow-kit/README.md`로 작성한다. 인덱스 표는 실제 복사된 스킬/에이전트와 1:1로 맞춘다.

```markdown
# ai-dev-workflow-kit

여러 프로젝트(Unity, Flutter, Next.js)에 흩어져 있던 개인용 AI 스킬·에이전트를
한곳에 모아 관리하는 저장소다. 새 프로젝트를 시작할 때 사용하는 기술 스택에 맞춰
필요한 스킬·에이전트를 가져다 쓰는 것이 목표다.

현재는 Flutter 기반 `band-of-mercenaries` 프로젝트의 Claude용 스킬·에이전트를
수집한 첫 단계 상태다.

## 디렉토리 구조

\`\`\`
common/      스택 무관 범용 워크플로우 (skills/, agents/)
flutter/     Flutter 전용 (skills/, agents/)
examples/    특정 프로젝트에 종속된 참고용 스킬 (재사용보다 레퍼런스)
docs/        설계·계획 문서
\`\`\`

추후 \`unity/\`, \`nextjs/\` 가 같은 구조로 추가된다.

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

\`implement-agent\`처럼 같은 역할이지만 스택마다 내용이 다른 스킬은 **이름을
그대로 유지**하고 스택 폴더로 구분한다 (\`flutter/skills/implement-agent\`,
추후 \`unity/skills/implement-agent\`). kit 안에서는 폴더가 달라 충돌하지 않고,
배포 시에는 한 프로젝트에 한 스택 버전만 들어가므로 충돌하지 않는다. 이름을
통일해 프로젝트 간 사용 경험을 일관되게 유지하기 위한 의도된 선택이다.

## 사용법

현재는 필요한 스킬·에이전트 폴더를 대상 프로젝트의 \`.claude/skills/\`,
\`.claude/agents/\`로 직접 복사해서 쓴다.

\`\`\`bash
# 예: 새 Flutter 프로젝트에 공통 + Flutter 스킬 세팅
cp -R common/skills/*   <project>/.claude/skills/
cp -R common/agents/*   <project>/.claude/agents/
cp -R flutter/skills/*  <project>/.claude/skills/
cp -R flutter/agents/*  <project>/.claude/agents/
\`\`\`

## 향후 계획

- Codex용 \`.toml\` 에이전트 지원
- Unity, Next.js 스킬·에이전트 수집
- 기술 스택을 고르면 자동으로 대상 프로젝트에 세팅해주는 배포 도구
\`\`\`
```

- [ ] **Step 2: README 인덱스가 실제 파일과 일치하는지 검증**

```bash
DST=/Users/radiogaga/git/ai-dev-workflow-kit
# README에 적은 수: common skills 8, common agents 5, flutter skills 1, flutter agents 2, examples skills 4
echo "common/skills: $(ls $DST/common/skills | wc -l) (기대 8)"
echo "common/agents: $(ls $DST/common/agents/*.md | wc -l) (기대 5)"
echo "flutter/skills: $(ls $DST/flutter/skills | wc -l) (기대 1)"
echo "flutter/agents: $(ls $DST/flutter/agents/*.md | wc -l) (기대 2)"
echo "examples skills: $(ls $DST/examples/band-of-mercenaries/skills | wc -l) (기대 4)"
```
Expected: 8 / 5 / 1 / 2 / 4

- [ ] **Step 3: 커밋**

```bash
cd /Users/radiogaga/git/ai-dev-workflow-kit
git add README.md
git commit -m "README 작성

kit 목적, 디렉토리 구조, 스킬·에이전트 인덱스, 동명 스킬 네이밍 규칙,
사용법, 향후 계획 정리"
```

---

## Self-Review

**Spec coverage:**
- 스택-우선 구조 확립 → Task 1~4
- common 스킬 8 / 에이전트 5 → Task 1, 2
- flutter 스킬 1 / 에이전트 2 → Task 3
- examples 게임 스킬 4 (types 포함) → Task 4
- 에이전트 평면 .md 형식 → Task 2, 3 (cp로 .md 직접 복사)
- 원본 미변경 → Task 5 Step 3
- README (목적/구조/인덱스/네이밍/사용법/향후) → Task 6
- 복사 검증 매핑 → Task 5
- 모든 spec 요구사항이 태스크에 매핑됨. 누락 없음.

**Placeholder scan:** TBD/TODO 없음. 모든 명령·README 내용 실제 기재됨.

**Type consistency:** 경로·이름이 전 태스크에서 일관됨 (band-of-mercenaries, examples/band-of-mercenaries/skills, data-generator/types 10개 등 spec과 일치).
