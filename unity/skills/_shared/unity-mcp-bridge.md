# Unity MCP Bridge — 공통 자동화 헬퍼

여러 스킬(`implement-spec`, `implement-agent`, `finalize-feature`, `finalize-minor-task`, `spec-writer`, agents의 `verifier`/`coder`)이 Unity 에디터 작업을 처리할 때 공유하는 **연결 검사 + 자동/수동 분기** 절차서다. 본 문서를 직접 사용자에게 보여주지 않고, 각 스킬에서 "Unity MCP Bridge 절차에 따라 검사" 형태로 참조한다.

이 문서는 _스킬이 아니라 라이브러리_ 다. `name`/`description` 프론트매터 없이 순수 참조 문서로 동작한다.

---

## 1. 연결 검사 (Detection)

다음 순서로 UnityMCP 연결 상태를 판정한다.

### 1-1. 도구 노출 확인

현재 세션에 다음 도구 중 하나라도 노출되어 있는지 본다.
- `mcp__unityMCP__*`
- `mcp__UnityMCP__*` (대문자 변형도 함께 허용 — 동일 서버)

도구가 전혀 없으면 즉시 **"미연결"**로 판정하고 2-B로 분기한다.

### 1-2. 가벼운 핑

도구가 노출되어 있어도 Unity 인스턴스가 떠 있지 않으면 호출이 실패한다. 다음 중 하나를 1회 호출해 응답을 확인한다.

- `mcp__unityMCP__manage_editor` — `action: "get_state"`
- 또는 `mcp__unityMCP__read_console` — `types: ["Error"]`, `count: 1`

**판정 규칙**:
- 정상 응답 → "연결됨" → 2-A 분기
- 에러/타임아웃 → 1회 재시도
- 재시도도 실패 → "미연결" → 2-B 분기

### 1-3. 다중 인스턴스 처리

`mcpforunity://instances` 리소스가 2개 이상 반환하면, 사용자에게 한 번 물어 `set_active_instance`로 고정하거나 각 호출에 `unity_instance` 파라미터를 명시한다. 단일 인스턴스면 추가 작업 불필요.

### 1-4. 컴파일 중인 경우

`get_state` 응답의 `isCompiling`이 true면 자동 작업을 시도하지 말고 false가 될 때까지 폴링(최대 60초). 폴링 시간이 초과되면 사용자에게 보고하고 미연결 흐름으로 폴백한다.

---

## 2. 분기

### 2-A. 연결됨 — 자동 호출

작업 종류별로 아래 카탈로그의 도구를 직접 호출한다. 각 호출 실패 시 1회 재시도, 그래도 실패하면 해당 항목만 미연결 안내로 폴백하고 나머지는 계속 진행한다.

#### 작업 카탈로그

| 작업 | MCP 도구 | 용도 |
|------|----------|------|
| 컴파일 트리거 | `refresh_unity` | AssetDatabase.Refresh + 재컴파일 |
| 컴파일 완료 대기 | `manage_editor` (`get_state`) | `isCompiling=false` 폴링 |
| 컴파일 에러 확인 | `read_console` (`types: ["Error"]`) | 에러 0건 검증 |
| 경고 확인 (선택) | `read_console` (`types: ["Warning"]`) | 신규 경고 검토 |
| 메뉴 실행 | `execute_menu_item` | 커스텀 에디터 메뉴(`Tools/...`, `Assets/...`) 실행 |
| 에셋 검증 | `manage_asset` 또는 Read | 생성된 프리팹/파일 존재 확인 |
| 씬 작업 | `manage_scene` | 씬 로드/저장/조회 |
| 프리팹 작업 | `manage_prefabs` | 프리팹 생성/수정 |
| 컴포넌트 조작 | `manage_components` | 컴포넌트 추가/속성 설정 |
| 게임오브젝트 | `manage_gameobject` | 씬 내 오브젝트 조작 |
| 테스트 실행 | `run_tests` | EditMode/PlayMode 테스트 |
| 코드 검증 | `validate_script` | 컴파일 전 정적 검증 |
| 임의 코드 실행 | `execute_code` | 에디터에서 C# 스니펫 실행 |

#### 자동 실행 화이트리스트 / 블랙리스트

부작용 큰 작업은 **사용자 확인 없이 자동 실행하지 않는다.**

- ✅ 자동 실행 OK: `refresh_unity`, `read_console`, `manage_editor(get_state)`, 부작용 없는 안전 메뉴, `validate_script`
- ⚠️ 사용자 확인 필요: `run_tests` (시간 비용), 빌드 메뉴, 씬 저장, `execute_code`(임의 C# 실행), 패키지 설치/제거
- ❌ 자동 실행 금지: 빌드/배포, 외부 시스템 연동, 사용자 데이터 삭제 메뉴

각 스킬은 카탈로그에서 자신이 사용할 항목만 골라 쓴다.

### 2-B. 미연결 — 기존 수동 안내

다음 두 가지를 반드시 지킨다.

1. 출력 첫 줄에 ⚠️ 명시:
   > ⚠️ **UnityMCP가 설치/연결되어 있지 않아 에디터 자동 작업을 건너뛰었습니다.**
2. 기존 스킬의 수동 안내 흐름을 그대로 수행 (사용자에게 메뉴 실행, 컴파일 확인 등 직접 부탁)

(선택) 마지막에 한 번 안내:
> UnityMCP를 설치하면 다음 작업이 자동화됩니다: 컴파일 트리거 / 컴파일 에러 확인 / 메뉴 실행 / 에셋 검증.

---

## 3. 표준 출력 포맷

각 스킬은 작업 완료 시 두 형식 중 하나로 결과를 출력한다.

### 3-A. 연결됨

```
## UnityMCP로 자동 수행
- ✅ refresh_unity
- ✅ 컴파일 에러 0건 (read_console)
- ✅ <메뉴/도구 실행 결과>
- ✅ <검증 결과>

## 사용자 확인 필요 (사람만 가능)
1. <플레이 모드 동작 확인>
2. <인스펙터 시각 검수>
3. <기타 사람만 가능한 항목>
```

### 3-B. 미연결

```
⚠️ UnityMCP가 설치/연결되어 있지 않아 에디터 자동 작업을 건너뛰었습니다.

## Unity 에디터에서 직접 수행해주세요
1. <컴파일 에러 확인>
2. <메뉴 실행>
3. <플레이 모드 검증>
```

---

## 4. 호출 패턴 스니펫

스킬이 자주 쓰는 조합. 각 스킬에서 그대로 차용 가능.

### 4-1. 컴파일 게이트 (커밋/검증 직전)

```
1) refresh_unity
2) manage_editor(get_state) 폴링 — isCompiling=false 까지
3) read_console(types: ["Error"]) — 에러 0건 확인
4) 0건 아니면 사용자에게 보고하고 작업 중단/재작업
```

### 4-2. 에디터 메뉴 실행 후 결과 검증

```
1) refresh_unity
2) read_console(types: ["Error"]) — 0건 확인
3) execute_menu_item("<커스텀 메뉴 경로>")
4) Read 또는 manage_asset로 생성/변경 결과 확인
```

### 4-3. 신규 스크립트 후 검증

```
1) refresh_unity
2) get_state 폴링
3) read_console(types: ["Error", "Warning"]) — 결과를 verifier에 전달
```

---

## 5. 실패 처리 규칙

각 스킬에서 동일하게 적용한다.

- **단일 호출 실패**: 1회 재시도. 실패해도 다른 단계는 계속 진행
- **연속 2회 실패**: 해당 단계만 미연결 흐름으로 폴백 ("이 단계는 사용자 직접 수행 필요" 안내)
- **연결 자체가 끊긴 경우**: 즉시 전체 2-B 분기로 전환
- **컴파일 에러 발견**: 자동 처리 중단, 사용자에게 에러 내역 보고. 절대 에러 무시하고 다음 단계 진행 금지

---

## 6. 참조 방식 (각 스킬에서)

각 스킬 SKILL.md의 해당 단계에 다음 한 줄을 넣고, 본 문서의 절차 번호를 인용한다.

> Unity MCP Bridge(`.claude/skills/_shared/unity-mcp-bridge.md`)의 **§1 연결 검사** → **§2 분기**를 따른다. 출력은 **§3 표준 포맷** 중 하나를 사용한다.

스킬별로 사용하는 카탈로그 항목만 따로 명시하면 된다. 예:
- finalize-feature / finalize-minor-task → §4-1 (컴파일 게이트)
- implement-* → §4-1 + §4-3 (검증 + 신규 스크립트)
