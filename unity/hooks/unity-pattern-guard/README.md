# unity-pattern-guard 훅

Unity 런타임 스크립트에서 **자주 반복되는 금지 패턴을 편집 시점에 기계적으로 막는**
`PreToolUse` 훅이다. 문서(CLAUDE.md·AGENTS.md)에 "쓰지 마라"고 적어두는 것만으로는
에이전트가 지키지 않는 규칙들을, 편집 자체를 거부해서 강제한다.

[`unity-script-rule`](../../skills/unity-script-rule/SKILL.md) 스킬과 짝으로 쓴다 —
스킬은 "왜 그런지"를 알려주고, 훅은 "그래도 쓰면 막는다".

## 동작

`Write`/`Edit`/`MultiEdit`(Codex는 `apply_patch`)로 **검사 범위 안의 `.cs`** 를 수정할 때,
새로 들어가는 내용만 검사한다. 지워지는 줄은 검사하지 않는다.

- **차단 룰 위반** → exit 2. 편집이 거부되고 에이전트가 다시 쓴다.
- **경고 룰 위반** → exit 0 + stderr 메시지. 통과하되 기록이 남는다.

| 룰 id | 심각도 | 잡는 것 |
|---|---|---|
| `resources-load` | 차단 | `Resources.Load` / `Resources.LoadAsync` 직접 호출 |
| `gameobject-find` | 차단 | `GameObject.Find` · `FindObjectOfType` · `FindAnyObjectByType` 계열 |
| `transform-find` | 차단 | `transform.Find` |
| `camera-main` | 차단 | `Camera.main` |
| `coroutine` | 차단 | `StartCoroutine` · `IEnumerator` 반환 메서드 |
| `fake-null` | 경고 | `??` · `?.` · `is null` (Unity Fake Null) |
| `instantiate-destroy` | 경고 | `Instantiate` · `Destroy` 직접 호출 |
| `trigger-stay` | 경고 | `OnTriggerStay` · `OnCollisionStay` 정의 |

**주석·문자열 리터럴·`#if UNITY_EDITOR` 블록은 검사하지 않는다**(`masker.py`가 길이를
보존한 채 공백으로 치환하므로 행·열 번호는 그대로 맞는다). 로그 문자열에 `Camera.main`이
들어 있다고 차단되지 않는다.

**오탐 우회**: 해당 줄 끝에 `// claude-allow: <룰 id>` 주석을 단다(쉼표로 복수 지정).
순수 C# 객체에 `??`/`?.`를 쓰는 경우가 대표적이다 — 훅은 대상이 `UnityEngine.Object`인지
구분하지 못한다.

## 설치

`unity-pattern-guard` 디렉토리를 통째로 대상 프로젝트에 복사한 뒤, 플랫폼에 맞는
설정을 병합한다. 파이썬 3.9 이상이면 동작하며 외부 패키지는 필요 없다.

### Claude Code

1. 이 디렉토리를 `.claude/hooks/unity-pattern-guard/`로 복사한다.
2. `install.claude.json`의 `hooks` 블록을 프로젝트 `.claude/settings.json`에 병합한다.

### Codex

1. 이 디렉토리를 `.codex/hooks/unity-pattern-guard/`로 복사한다.
2. `install.codex.json`의 `hooks` 블록을 `.codex/hooks.json`에 병합한다.

> `python3`이 PATH에 없는 환경(일부 Windows)에서는 커맨드의 `python3`를 `python`으로 바꾼다.

## 설정 — 설치 후 반드시 고친다

**고치는 곳은 `config.py` 한 파일이다.** kit 기본값은 어떤 Unity 프로젝트에서도 일단
동작하는 범용값이라, 그대로 두면 검사 범위가 넓고 제안 문구가 두루뭉술하다.

| 값 | 기본값 | 무엇 |
|---|---|---|
| `SCOPE_MARKER` | `"Assets/"` | 경로에 이 문자열이 있는 `.cs` 만 검사한다. **좁힐수록 서드파티 에셋이 걸리지 않는다** (예: `"Assets/Game/"`) |
| `EXCLUDED_SEGMENTS` | `("/Editor/", "/Editor.")` | 검사 제외 경로. 저수준 API 직접 호출이 정당한 부트스트랩 계층이 있으면 추가한다 |
| `RESOURCE_MANAGER` | `"프로젝트 리소스 매니저"` | `resources-load` 위반 메시지에 실을 대안 이름 (예: `"Global.ResourceMgr"`) |
| `ASYNC_STYLE` | `"UniTask 또는 async/await(Awaitable)"` | `coroutine` 위반의 대안 |
| `POOLING_HINT` | `"오브젝트 풀"` | `instantiate-destroy` 경고의 대안 |
| `SEVERITY_OVERRIDES` | `{}` | 룰 id → `"block"`/`"warn"`. **`rules.py` 를 고치지 않고** 차단/경고를 조정한다. 없는 id 나 잘못된 값은 즉시 예외 |

`SCOPE_MARKER`를 프로젝트 게임 코드 루트로 좁히는 것이 가장 중요하다 — 기본값 `Assets/`는
임포트한 에셋 스토어 코드까지 검사 대상에 넣는다.

**심각도만 바꾸려면** `rules.py` 가 아니라 `config.py` 의 `SEVERITY_OVERRIDES` 를 쓴다 —
룰 목록을 포크하지 않아야 kit 업데이트를 그대로 받을 수 있다.

**룰 자체를 늘리거나 줄이려면** `rules.py`의 `BLOCK_RULES`/`WARN_RULES`를 고치고,
`tests/test_rules.py`의 개수 단언(`test_block_rule_count`·`test_warn_rule_count`)을
함께 고친다.

## 검증

```bash
python3 -m pytest tests -q
```

테스트는 `config.py` 값에서 경로를 만들어 쓴다 — **설정을 프로젝트에 맞게 바꿔도 그대로
통과해야 한다.** 경로를 하드코딩하지 않는 이유이고, 설정 변경 후 첫 검증 수단이기도 하다.

## 파일

| 파일 | 역할 |
|---|---|
| `check_patterns.py` | 엔트리포인트 — 이벤트 파싱, 검사 범위 판정, 종료 코드 결정 |
| `config.py` | **프로젝트 설정** — 설치 후 고치는 유일한 파일 |
| `rules.py` | 룰 데이터(정규식·메시지)와 매처, `claude-allow` 우회 처리 |
| `masker.py` | 주석·문자열·Editor 블록을 길이 보존하며 공백 치환 |
| `tests/` | pytest 스위트 + `.cs` 픽스처 12종 |
