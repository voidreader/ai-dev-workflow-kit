---
name: design-inventory
description:
  Next.js App Router 웹앱에서 화면·구성요소·상태·디자인토큰을 단일 출처(SSOT)
  문서로 유지하고 코드↔Figma 핸드오프를 준비할 때 사용합니다. 라우트/페이지나
  feature 컴포넌트, 인터랙션 상태, 색·radius·shadow 토큰을 추가·삭제·이동·변경했을
  때, 또는 Figma로 UI를 이관하거나 디자인을 전수검증할 때 트리거됩니다.
---

Recommended Model : Claude Sonnet


# `design-inventory` 스킬 지침

Next.js(App Router) 웹앱의 디자인 실태를 **5종 문서로 구조화해 단일 출처(SSOT)로
유지**하고, 그 문서를 기준으로 코드↔Figma 핸드오프를 진행하는 워크플로우다.

## 핵심 원칙

화면·구성요소·상태·토큰의 SSOT는 코드가 아니라 `Docs/design/` 문서다. 코드만 보고
Figma 이관·전수검증을 하면 화면 누락이나 "존재하지 않는 화면 작업"으로 이어진다.
**문서는 항상 실제 `src/app`·`src/features`를 확인해 작성하며, 추측으로 채우지
않는다.** 코드 변경과 문서 갱신은 같은 작업/커밋 안에서 함께 한다.

[`design-doc-sync-reminder`](../../hooks/design-doc-sync-reminder/README.md) 훅과
짝으로 쓴다 — 훅이 "화면/구성요소 파일을 고쳤다"고 깨우면, 이 스킬로 어느 문서의
어디를 고칠지 판단한다.

## 5종 SSOT 문서

`Docs/design/` 아래에 둔다.

| 문서 | 담는 내용 |
|---|---|
| `page-inventory.md` | 라우트/페이지 목록, 화면별 구조, loading/error/empty 화면, 반응형 기준 |
| `component-inventory.md` | 화면별 feature 컴포넌트, foundation primitive, form control, Figma 컴포넌트 우선순위 |
| `interaction-states.md` | button/form/selected/loading/empty/error/success/transition 상태와 variant, 인앱 브라우저 고려 상태 |
| `design-tokens.md` | color/typography/spacing/radius/border/shadow/breakpoint/motion 토큰, 토큰 소스, 정리할 토큰 부채 |
| `figma-handoff.md` | Figma 파일 구조, foundation·component set 구성, breakpoint 프레임, 개발 반영 매핑, 핸드오프 체크리스트 |

## 무엇이 바뀌면 어디를 고치는가

코드 변경 종류별로 갱신할 문서를 정한다.

| 코드 변경 | 갱신할 문서 |
|---|---|
| 라우트/페이지 추가·삭제·이동·통합 | `page-inventory.md`의 라우트 표·화면 구조 (+ 프로젝트 `AGENTS.md`/`CLAUDE.md`에 라우트 요약이 있으면 함께) |
| feature 컴포넌트 추가·이름변경·이동·역할변경 | `component-inventory.md` |
| loading/error/empty/disabled/selected 등 상태·variant 변경 | `interaction-states.md` |
| 색·radius·shadow·디자인 helper·테마 토큰 변경 | `design-tokens.md` |
| 위 변경이 Figma 작업 순서나 "개발 반영 매핑"에 영향 | `figma-handoff.md` |

### 동기화 규칙 (필수)

- 존재하지 않는 파일·컴포넌트·라우트를 문서에 남기지 않는다. 실제 `src/app`·
  `src/features` 파일을 확인해 적는다.
- 문서에 적은 파일 경로와 컴포넌트 export가 실제로 존재하는지 확인한다.
- 완료 보고에 "어떤 design 문서를 함께 갱신했는지"를 명시한다. 갱신이 불필요하면
  그 이유를 적는다.

## Figma 핸드오프 워크플로우

`figma-handoff.md`를 기준으로, 구현된 화면을 단순 캡처가 아니라 **디자인 시스템
관점**으로 Figma에 재구성하고, 확정안을 다시 코드(디자인 토큰 helper, feature
컴포넌트, Tailwind className)로 되돌린다.

권장 Figma 파일 구조:

```
00 Cover · 01 Foundations · 02 Components · 03 Pages-Mobile
04 Pages-Desktop · 05 States · 06 Handoff Notes
```

순서:

1. **Foundations 먼저** — color variable collection, text style, spacing/radius/shadow
   variable을 `design-tokens.md` 기준으로 만든다.
2. **공통 component set** — `component-inventory.md`의 "Figma 컴포넌트 우선순위"를
   따라 Button/Card/Form Field/Nav 등을 variant(`tone`·`state`·`size`)와 함께 만든다.
3. **페이지** — `page-inventory.md`의 화면을 Mobile→Desktop 순으로 조립한다.
4. **상태** — `interaction-states.md`의 hover/focus/disabled/loading/error/empty/
   selected를 `05 States`에 모은다.
5. **개발 반영 매핑** — `figma-handoff.md`에 "Figma 변경 영역 → 개발 반영 파일" 표를
   유지해, 확정안을 어느 코드 파일에 반영할지 1:1로 추적한다.

Breakpoint 프레임은 화면마다 최소 Mobile(390×844)·Tablet(768×1024)·
Desktop(1024×768)·Wide(1280×800)를 만든다.

### 핸드오프 체크리스트

- 색상이 Figma variable로 연결되어 있는가?
- 공통 버튼·카드·태그·폼이 component set으로 만들어졌는가?
- hover/focus/disabled/loading/error/empty/selected 상태가 variant로 존재하는가?
- 모바일·desktop 프레임이 모두 있는가?
- 공개/테마 화면 토큰과 앱 내부 brand 토큰이 분리되어 있는가?
- 인앱 브라우저(카카오톡·인스타그램·WhatsApp 등) 제약에 대한 fallback UI가 표시돼 있는가?
- Figma 컴포넌트 이름이 React 컴포넌트와 매핑 가능한가?
- 현재 디자인 체계에서 벗어난 화면이 `Needs Alignment` 등으로 별도 표시돼 있는가?

## 흔한 실수

- 코드만 보고 Figma 작업 → 문서를 거치지 않아 화면/상태 누락. 항상 5종 문서를 기준으로.
- 코드 변경 후 문서 갱신을 다음 작업으로 미룸 → 어긋남 누적. **같은 커밋**에서 갱신.
- 문서에 추측으로 파일 경로·컴포넌트를 적음 → 없는 화면 작업 유발. 실제 파일 확인 필수.
- 토큰을 Figma variable로 연결하지 않고 하드코딩 → 확정안 코드 반영이 단절됨.

## 새 프로젝트 적용

이 스킬은 5종 문서의 **구조와 방법론**을 제공한다. 실제 토큰 값·컴포넌트 목록·라우트는
프로젝트마다 다르므로, 위 헤더 구조를 골격으로 두고 대상 코드베이스(`src/app`·
`src/features`)를 스캔해 채운다. 경로 컨벤션이 App Router와 다르면(`pages/` 등)
인벤토리 분류와 동기화 규칙의 경로만 맞춰 조정한다.
