---
name: flame-harness-resume
description: pause_reason에 따라 일시 정지된 flame-harness 파이프라인을 재개한다 (rate_limit 대기 / manual_action 사용자 확인 / error 보고).
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion, Skill]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# flame-harness-resume

flutter-flame-harness 파이프라인의 재개 핸들러. `state.md`를 읽고 `pause_reason`에 따라 분기한 뒤, 재개가 준비되면 다음 phase 스킬을 디스패치한다.

모든 파일 스키마(`state.md`, `pipeline-log.md`)와 상태 전이 규칙(특히 `status`가 `running`으로 복원될 때 `pause_reason`을 `""`로 클리어해야 한다는 요건)은 `docs/harness/protocol.md` §2(state.md 스키마)·§7(상태 전이 규칙)을 단일 진실 공급원(SSOT)으로 삼는다. 스키마를 여기서 재정의하지 않는다.

---

## 입력

`docs/harness/protocol.md` §2의 스키마에 따라 `docs/harness/state.md`를 읽는다. `state.md`가 존재하지 않으면 다음과 같이 중단한다:

```
flame-harness-resume: 재개할 항목이 없습니다 — docs/harness/state.md를 찾을 수 없습니다.
새 파이프라인을 시작하려면 /flame-harness <idea>를 실행하세요.
```

다음 필드를 추출한다:

- `status` — `paused`를 기대한다. `running` 또는 `completed`이면 안내 메시지를 출력하고 종료한다(재개 불필요).
- `pause_reason` — `rate_limit` | `manual_action` | `error`
- `next_role` — 재개 후 디스패치할 역할
- `resume_attempts` — 정수; 성공적인 재개 시 증가시킨다
- `current_phase`, `updated_at` — 로깅용

`status`가 `running`이면:

```
flame-harness-resume: 파이프라인이 이미 실행 중입니다 (status: running, next_role: <next_role>).
재개가 필요하지 않습니다.
```

`status`가 `completed`이면:

```
flame-harness-resume: 파이프라인이 이미 완료되었습니다. 재개할 항목이 없습니다.
```

---

## pause_reason에 따른 분기

### rate_limit

`pause_reason: rate_limit`은 파이프라인이 API 속도 제한에 도달하여 자동으로 일시 정지되었음을 의미한다.

**절차:**

1. 다음을 출력한다:
   ```
   속도 제한(rate_limit)으로 파이프라인이 일시 정지되었습니다.
   속도 제한 대기 시간이 경과했는지 확인 중...
   ```
2. `state.md`에서 `updated_at`을 읽는다. Bash(`date` 명령어)를 사용하여 해당 타임스탬프 이후 경과 시간을 계산한다. 경과 시간이 60초 미만이면 다음 경고를 출력한다:
   ```
   경고: 일시 정지 이후 <N>초만 경과했습니다. 속도 제한 대기 시간이 아직
   지나지 않았을 수 있습니다. 계속 진행합니다 — 또 다른 속도 제한에 도달하면
   파이프라인이 다시 일시 정지됩니다.
   ```
3. 아래 **재개 실행**으로 진행한다.

### manual_action

`pause_reason: manual_action`은 파이프라인을 계속하기 전에 사용자의 수동 작업이 필요함을 의미한다 (예: **QA 후 검토 게이트에서 빌드된 앱 실행/승인**, App Store/Play Console 제출 단계 완료, 키스토어 업로드, 기기 설정 등). 구체적인 작업 내용은 `pipeline-log.md`의 `pause` 이벤트 행에 기록되어 있다.

> **이식본 참고:** 이 harness에서는 AdMob·레트로 처리 등이 `ship-admob`, `ship-retro` 등 독립 스킬로 분리되었다. manual_action으로 재개된 후 다음 단계가 해당 작업에 해당하면, 파이프라인의 반복 루프를 계속하거나 `ship-admob` / `ship-retro` / `ship-submit` 등 해당 ship-* 스킬을 수동으로 호출하면 된다.

**절차:**

1. `docs/harness/protocol.md` §6에 따라 `docs/harness/pipeline-log.md`를 읽는다. 가장 최근의 `pause` 이벤트 행을 찾아 필요한 수동 작업을 설명하는 details 문자열을 추출한다. 로그를 사용할 수 없으면 일반적인 프롬프트를 사용한다.

2. **AskUserQuestion**을 사용하여 사용자가 필요한 단계를 완료했는지 확인한다:
   ```
   수동 작업으로 인해 파이프라인이 일시 정지되었습니다.
   마지막으로 기록된 이유: <pipeline-log의 details, 또는 "docs/harness/pipeline-log.md를 참조하세요">

   필요한 단계를 완료하셨나요? (yes / no / 아직 남은 작업 설명)
   ```

3. 사용자가 `no`라고 답하거나 남은 작업을 설명하면:
   - 사용자가 말한 내용을 요약하여 출력한다.
   - 중단: 재개하지 않는다. 다음과 같이 종료한다:
     ```
     flame-harness-resume: 수동 작업이 아직 완료되지 않았습니다. 준비가 되면
     /flame-harness-resume을 다시 실행하세요.
     ```

4. 사용자가 `yes`라고 답하면:
   - 아래 **재개 실행**으로 진행한다.

### error

`pause_reason: error`는 파이프라인이 phase 스킬에서 복구 불가능한 오류를 만났음을 의미한다.

**절차:**

1. `docs/harness/protocol.md` §6에 따라 `docs/harness/pipeline-log.md`를 읽는다. 가장 최근의 `error` 이벤트 행을 찾아 오류 세부 정보를 추출한다.

2. 명확한 오류 보고서를 출력한다:
   ```
   오류로 인해 파이프라인이 일시 정지되었습니다.
   Phase     : <current_phase>
   Next role : <next_role>
   Error     : <pipeline-log의 details, 또는 "docs/harness/pipeline-log.md를 참조하세요">

   재개하기 전에 오류를 조사하고 수정해야 합니다.
   일반적인 수정 방법:
     - Flutter/Dart 컴파일 오류인 경우 코드를 수정하고 `flutter analyze`를 실행하세요.
     - 파일 누락인 경우 해당 파일을 생성하거나 복원하세요.
     - 자격 증명 오류인 경우 docs/harness/config.md와 credentials_dir를 확인하세요.
   ```

3. **AskUserQuestion**을 사용한다:
   ```
   오류를 해결하고 재시도할 준비가 되셨나요? (yes / no)
   ```

4. 사용자가 `no`라고 답하면:
   - 중단: 재개하지 않는다. 다음과 같이 종료한다:
     ```
     flame-harness-resume: 오류가 아직 해결되지 않았습니다. 수정이 완료되면
     /flame-harness-resume을 다시 실행하세요.
     ```

5. 사용자가 `yes`라고 답하면:
   - 아래 **재개 실행**으로 진행한다.

### 알 수 없는 pause_reason

`pause_reason`이 비어 있거나 인식되지 않는 값이면 다음을 출력한다:

```
flame-harness-resume: state.md의 pause_reason "<value>"이(가) 예상치 못한 값입니다.
기대하는 값: rate_limit, manual_action, error.
재개하기 전에 docs/harness/state.md를 직접 확인하고 수정하세요.
```

그런 다음 어떤 파일도 수정하지 않고 중단한다.

---

## 재개 실행

위 분기에서 계속 진행하는 것이 안전하다고 확인된 후에만 도달한다.

`docs/harness/protocol.md` §7 규칙 4: `status`를 `running`으로 되돌릴 때 `resume_attempts`를 증가시켜야 한다. §7 규칙 8: `pause_reason`은 이 스킬이 `""`로 클리어해야 한다.

### 1. state.md 업데이트

**Edit**을 사용하여 `docs/harness/state.md`의 다음 필드를 변경한다(다른 키는 그대로 유지):

```yaml
status: running
pause_reason: ""
resume_attempts: <이전_값 + 1>
updated_at: "<ISO-8601 UTC 현재시각>"
```

`status: running`과 `pause_reason: ""`는 동일한 Edit 호출로 작성해야 한다(`docs/harness/protocol.md` §7 규칙 1의 원자성 요건).

### 2. pipeline-log.md에 행 추가

`docs/harness/protocol.md` §6의 스키마에 따라 `docs/harness/pipeline-log.md`에 한 행을 추가한다:

```
| <ISO-8601 UTC 현재시각> | resume | <current_phase> | resume_attempts=<새 값>; <pause_reason>으로 일시 정지되어 있었음 |
```

### 3. next_role 디스패치

(업데이트된) `state.md`에서 `next_role`을 읽고 디스패치한다:

```
Skill("flame-harness-<next_role>")
```

유효한 `next_role` 값은 `docs/harness/protocol.md` §7의 전이 테이블에 나열되어 있다.

> **이식본 참고:** 이 harness에서는 `admob`, `retro` 등이 독립 ship-* 스킬(`ship-admob`, `ship-retro` 등)로 분리되었다. `next_role`이 해당 작업을 가리키는 경우, 파이프라인 반복 루프를 계속하거나 사용자에게 적절한 `ship-*` 스킬을 수동으로 호출하도록 안내한다.

`next_role`이 비어 있거나 알 수 없는 값이면 다음과 같이 중단한다:

```
flame-harness-resume: 디스패치할 수 없습니다 — next_role이 "<value>"입니다.
재시도 전에 docs/harness/state.md를 확인하고 유효한 next_role을 설정하세요.
```

---

## 오류 처리

- 실행 중 `state.md`를 읽을 수 없게 되면(예: 동시 쓰기) 즉시 중단하고 부분적인 상태 변경을 쓰지 않는다.
- `state.md`가 `status: running`, `pause_reason: ""`으로 성공적으로 업데이트되기 전에는 절대 `Skill(...)`을 디스패치하지 않는다. 디스패치는 반드시 마지막 단계다.
