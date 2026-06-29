---
name: flame-harness-status
description: flame-harness 파이프라인의 현재 상태(phase, round, 점수)를 읽기 전용으로 출력한다.
argument-hint: ""
allowed-tools: [Read, Bash, Glob]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# flame-harness-status

flutter-flame-harness 파이프라인의 읽기 전용 상태 리포터. `state.md`, `build-log.md`,
`pipeline-log.md`를 읽어 현재 파이프라인 상태를 요약 출력한다.

모든 파일 스키마(`state.md`, `build-log.md`, `pipeline-log.md`)는
`docs/harness/protocol.md`에 정의되어 있다 — 단일 소스 오브 트루스(SSOT)로 참조한다.
스키마를 여기서 재서술하지 않는다.

**이 스킬은 엄격히 읽기 전용이다. state.md 또는 다른 harness 파일을 절대 수정해서는 안 된다.**

---

## 입력

현재 프로젝트 루트(즉 `docs/harness/`를 포함하는 디렉토리)를 기준으로
`docs/harness/state.md`를 찾는다. `state.md`가 존재하지 않으면 다음을 출력한다:

```
flame-harness-status: 활성 파이프라인을 찾을 수 없습니다 (docs/harness/state.md 없음).
새 파이프라인을 시작하려면 /flame-harness <아이디어>를 실행하세요.
```

그런 다음 오류 없이 종료한다.

---

## 절차

### 1. state.md 읽기

`docs/harness/state.md`를 Read로 읽고, `docs/harness/protocol.md` §2의 스키마에 따라
다음 필드를 추출한다:

- `status` — `running` | `paused` | `completed`
- `current_phase` — 현재 실행 중인 phase 이름
- `current_round` — 정수형 라운드 카운터
- `next_role` — 다음에 실행될 스킬 역할
- `pause_reason` — `""` | `rate_limit` | `manual_action` | `error`
- `updated_at` — 마지막 쓰기 시각(ISO-8601 타임스탬프)
- `resume_attempts` — 정수형 재시도 횟수

### 2. build-log.md 읽기 (있는 경우)

`docs/harness/protocol.md` §6의 스키마에 따라 `docs/harness/build-log.md`를 Read로 읽는다.
가장 최근 행에서 최신 QA 점수(`PASS` | `FAIL` | `PARTIAL`)와 해당 라운드 번호를 추출한다.
파일이 없거나 데이터 행이 없으면 `latest_score`를 `—`로 설정한다.

### 3. pipeline-log.md 읽기 (있는 경우)

`docs/harness/protocol.md` §6의 스키마에 따라 `docs/harness/pipeline-log.md`를 Read로 읽는다.
최근 이벤트 요약을 위해 마지막 3개 행을 추출한다. 파일이 없거나 비어 있으면 건너뛴다.

### 4. 상태 리포트 출력

다음 형식으로 리포트를 출력한다(가독성을 위해 간격은 조정 가능):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 flame-harness 파이프라인 상태
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  상태          : <status>
  현재 phase   : <current_phase>
  라운드        : <current_round>
  다음 역할     : <next_role>
  최신 QA       : <latest_score>
  마지막 갱신   : <updated_at>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

`status`가 `paused`이면 다음을 추가한다:

```
  ⚠  일시 중지 — 이유: <pause_reason>
  재시도 횟수: <resume_attempts>
  계속하려면 /flame-harness --resume (또는 /flame-harness-resume)을 실행하세요.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

`status`가 `completed`이면 다음을 추가한다:

```
  파이프라인이 성공적으로 완료되었습니다.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

최근 pipeline-log 행이 있으면 다음을 추가한다:

```
최근 이벤트:
  <time>  <event>  <phase>  <details>
  <time>  <event>  <phase>  <details>
  <time>  <event>  <phase>  <details>
```

---

## 제약

- **읽기 전용**: 이 스킬은 `Write`, `Edit`, 또는 파일을 수정하는 Bash 명령을 절대 호출해서는 안 된다.
  오직 `state.md`, `build-log.md`, `pipeline-log.md`만 읽는다.
- 오류 경로를 포함한 어떤 상황에서도 `state.md`를 수정하지 않는다.
- 파일을 읽을 수 없는 경우 조용히 건너뛰고 리포트에 "(사용 불가)"로 표기한다.
