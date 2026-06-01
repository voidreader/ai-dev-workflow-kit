# design-doc-sync-reminder 훅

화면/구성요소 파일을 수정하면 **디자인 SSOT 문서(`Docs/design/`)의 동기화 필요 여부를
점검하라**는 리마인더를 자동으로 띄우는 `PostToolUse` 훅이다. 코드와 디자인 문서가
어긋나 Figma 이관·전수검증에서 화면이 누락되는 사고를 막는다.

[`design-inventory`](../../skills/design-inventory/SKILL.md) 스킬과 짝으로 쓴다 — 훅은
"문서를 갱신하라"고 깨우고, 스킬은 "어느 문서의 어디를 어떻게 고치는지"를 알려준다.

## 동작

`Edit`/`Write`(Codex는 `apply_patch` 포함)로 아래 경로를 수정하면 추가 컨텍스트
메시지를 주입한다. `*.test.ts(x)`는 제외한다.

- `src/app/**/page.tsx`, `route.ts(x)`, `layout.tsx`, `loading.tsx`, `error.tsx`,
  `opengraph-image.tsx`
- `src/features/**/*.tsx`

Next.js App Router(`src/app`, `src/features`) 구조에 맞춰진 경로 매칭이다. 다른 구조를
쓰면 매칭 패턴을 프로젝트에 맞게 고친다.

## 설치

대상 프로젝트에서 플랫폼에 맞는 설정을 합친다.

### Claude Code

`install.claude.json`의 `hooks` 블록을 프로젝트 `.claude/settings.json`에 병합한다.
외부 스크립트 없이 동작하는 자체 완결형 one-liner다.

### Codex

1. `design-doc-sync-reminder.sh`를 대상 프로젝트의 `.codex/hooks/`로 복사한다.
2. `install.codex.json`의 `hooks` 블록을 `.codex/hooks.json`에 병합한다.

스크립트는 `jq`로 `tool_input`/`tool_response`의 파일 경로와 `apply_patch` 패치 헤더를
파싱하므로 `jq`가 필요하다.

## 파일

| 파일 | 용도 |
|---|---|
| `design-doc-sync-reminder.sh` | Codex용 공유 스크립트 (`jq` 기반 경로 파싱) |
| `install.codex.json` | Codex `.codex/hooks.json`에 병합할 블록 |
| `install.claude.json` | Claude `.claude/settings.json`에 병합할 블록 (인라인) |
