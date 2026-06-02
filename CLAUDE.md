# CLAUDE.md

## 이 저장소는 무엇인가

앱이나 게임을 만드는 저장소가 **아니다**. 여러 프로젝트(Unity, Flutter, Next.js)에
흩어져 있던 개인용 AI 스킬·에이전트를 한곳에 모아 관리하는 **kit**다. 새 프로젝트를
시작할 때 사용하는 기술 스택에 맞춰 필요한 스킬·에이전트를 꺼내 쓰는 것이 목적이다.

여기에서 작업할 때는 "스킬·에이전트를 수집·정리·문서화"하는 관점으로 접근한다.
일반적인 기능 개발/디버깅 작업이 아니다.

## 디렉토리 구조

```
common/      스택 무관 범용 워크플로우 (skills/, agents/)
flutter/     Flutter 전용 (skills/, agents/)
unity/       Unity 전용 (skills/, agents/)
nextjs/      Next.js 전용 (skills/, hooks/)
backend/     Node.js/NestJS 전용 (skills/, agents/)
examples/    특정 프로젝트에 종속된 참고용 스킬 (재사용보다 레퍼런스)
scripts/     대상 프로젝트로 스킬·에이전트를 설치하는 배포 스크립트
docs/        설계·계획 문서 (docs/superpowers/specs, docs/superpowers/plans)
```

## 카테고리 분류 기준

새 스킬·에이전트를 추가할 때 아래 기준으로 위치를 정한다.

- **common** — 스택과 무관하게 동작하는 워크플로우(기획→명세→구현→마무리).
- **flutter / unity / backend** (또는 nextjs) — 특정 스택/언어에 종속된 것.
- **examples** — 특정 게임/도메인에 강하게 종속되어 그대로 재사용하기 어려운 것.
  새 스킬을 만들 때 참고용으로만 둔다.

## 파일 형식 규칙

- **스킬**: 디렉토리 + `SKILL.md` (예: `common/skills/spec-pipeline/SKILL.md`).
  하위 리소스가 있으면 같은 디렉토리에 둔다 (예: `data-generator/types/`).
- **에이전트**: 평면 파일 (예: `common/agents/analyzer.md`). 디렉토리로 감싸지 않는다.
  플랫폼은 확장자로 구분한다 — **`.md`는 Claude용, `.toml`은 Codex용**. 같은 역할의
  두 버전을 같은 폴더에 나란히 두고(예: `analyzer.md` + `analyzer.toml`) 함께 유지한다.
- **스킬은 플랫폼 공유**다. Claude·Codex 모두 같은 `SKILL.md`(마크다운)를 쓰므로
  별도 Codex 사본을 만들지 않는다.
- **훅**: 스택 폴더 아래 `hooks/<훅-이름>/` 디렉토리에 둔다 (예:
  `nextjs/hooks/design-doc-sync-reminder/`). 훅은 모델이 아니라 하네스가 실행하므로,
  공유 스크립트와 함께 플랫폼별 설치 스니펫(`install.claude.json`,
  `install.codex.json`)과 동작·설치법을 적은 `README.md`를 같은 폴더에 둔다.

## 동명 스킬 네이밍 규칙

`implement-agent`처럼 같은 역할이지만 스택마다 내용이 다른 스킬은 **이름을 그대로
유지**하고 스택 폴더로 구분한다 (`flutter/skills/implement-agent`, 추후
`unity/skills/implement-agent`). kit 안에서는 폴더가 달라 충돌하지 않고, 배포 시에는
한 프로젝트에 한 스택 버전만 들어가므로 충돌하지 않는다. 스택별로 이름을 다르게
바꾸지 않는다 — 프로젝트 간 일관된 사용 경험을 위한 의도된 선택이다.

## 기여 규칙

- 스킬·에이전트를 추가/삭제하면 **README.md의 인덱스 표를 함께 갱신**한다.
- 다른 프로젝트에서 스킬을 가져올 때는 원본을 **읽기 전용으로 복사**하고 원본을
  변경하지 않는다. 복사 후 `diff`로 내용 일치를 확인한다.
- 커밋 메시지는 한국어로, 사람이 직접 쓴 것처럼 자연스럽게 작성한다. AI 서명이나
  자동 생성 트레일러를 넣지 않는다.

## 향후 계획

- Next.js 스킬·에이전트·훅 추가 수집 (현재 design-inventory 스킬 + 동기화 훅 보유)
- 배포 스크립트를 스택 선택형(`install.sh <stack>`)으로 일반화
  (현재 `scripts/install-backend.sh`로 backend 전용만 제공)
