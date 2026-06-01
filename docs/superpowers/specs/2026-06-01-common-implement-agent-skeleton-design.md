# 공통 implement-agent 골격 + 스택 어댑터 설계

> 작성일: 2026-06-01
> 대상: `common/skills/implement-agent` (신규), `common/agents/`, `backend/agents/backend-reviewer`

## 1. 배경과 목적

지금까지 kit의 구현 워크플로우(`implement-agent`)는 Flutter·Unity 스택별로 따로 존재했고,
검증축이 **정적분석/빌드 게이트 + 스택 전용 리뷰어**(`flutter analyze`·`build_runner`·
`dart-build-resolver`·`flutter-reviewer`, Unity 컴파일 게이트)에 강하게 묶여 있어 스택에
종속됐다.

이제 NestJS/Node.js 같은 **TDD가 중요한 백엔드 프로젝트**까지 같은 파이프라인
(`plan-writer > spec-pipeline > implement-spec/agent > finalize-feature`)으로 다루고 싶다.

핵심 통찰: superpowers가 스택 무관한 이유는 검증축이 **"테스트 통과"** 하나이기 때문이다.
TDD 사이클(실패 테스트 → 구현 → 통과 → 커밋)은 언어 무관 추상이라, 스택별로 달라지는 건
실행 명령 한 줄뿐이다. 따라서 **TDD를 1급 검증축으로 채택하면 implement-agent는 자연히
더 스택 무관해진다.** 백엔드 TDD 요구와 공통화 요구는 같은 동전의 양면이다.

백엔드용을 통째로 또 만들지 않고, **공통 골격(오케스트레이션) + 스택별 어댑터**로 정비한다.
이미 `common/skills/spec-pipeline`이 *"런타임에 배포된 스택 버전을 Read해서 호출"*하는
패턴을 쓰고 있고, `common/agents/`는 *"진짜 스택 무관 에이전트가 생기면 둔다"*고 의도적으로
비워둔 상태라 — 이 설계는 kit에 새 개념을 들이지 않고 기존 선례를 잇는다.

## 2. 결정 사항 (브레인스토밍 합의)

1. **공통화 전략**: 골격+스택 어댑터. 흐름은 common에 한 벌, 스택별로 달라지는 부분
   (빌드/테스트 명령, 코드생성 단계, 리뷰어 에이전트)은 얇은 어댑터로 분리.
2. **검증 게이트**: 어댑터가 검증모드를 선언. 골격은 "task당 검증 게이트 슬롯 + 2단계
   리뷰" 구조만 정의. backend=TDD, flutter=빌드게이트, unity=컴파일.
3. **1차 범위**: `implement-agent` 골격 하나만. spec-writer·finalize는 후속. 패턴을 한
   곳에서 검증하는 가장 작은 단위.
4. **기존 flutter/unity는 1차에서 건드리지 않는다.** 골격 검증 후 어댑터로 흡수·제거.
5. **TDD 모드에서 RED 테스트는 coder가 직접 작성** (별도 test-writer 에이전트 없음).
6. **"산출물 생성"(`{specBase}_plan.md`) 단계는 골격에서 제거.** 문서/커밋은
   `finalize-feature`가 담당한다. 골격 implement-agent는 구현+검증에만 집중.

## 3. 아키텍처

### 3.1 디렉토리 구조

```
common/skills/implement-agent/
  SKILL.md                 ← 흐름(오케스트레이션)만. 스택 지식 0
  adapters/
    _interface.md          ← 어댑터가 채워야 할 슬롯 규약(계약서)
    flutter.md             ← 검증모드=build-gate, reviewer=flutter-reviewer
    unity.md               ← 검증모드=build-gate(컴파일)
    backend.md             ← 검증모드=tdd, reviewer=backend-reviewer
common/agents/
  planner.md(.toml) / coder.md(.toml) / verifier.md(.toml)  ← 스택무관 골격
backend/agents/
  backend-reviewer.md(.toml)            ← 2단계 리뷰의 품질 검증자(신규)
```

### 3.2 어댑터 로딩 모델

kit의 배포 모델(필요한 스택만 대상 프로젝트로 복사)과 일치시킨다.

- **배포 시점에 해당 스택 어댑터 1개만** `adapters/`에 복사한다.
  예: NestJS 프로젝트엔 `SKILL.md` + `adapters/backend.md`만 복사.
- 골격은 시작할 때(PHASE 0) **`adapters/` 안의 단일 `*.md`를 Read**해서 그 스택의
  검증모드·게이트 명령·리뷰어·coder 규칙을 로드한다.
- `spec-pipeline`이 쓰는 "런타임에 배포된 스택 버전을 Read" 패턴과 동일한 발상.

### 3.3 기존 flutter/unity 처리

1차에서는 `common/skills/implement-agent`(골격) + 세 어댑터를 **새로 만들고**, 기존
`flutter/skills/implement-agent`·`unity/skills/implement-agent`는 **그대로 둔다(공존).**
골격이 검증되면 후속 작업에서 기존 두 스킬을 어댑터로 흡수하고 제거한다.

## 4. 골격 흐름 (SKILL.md)

superpowers의 subagent-driven을 기본 모드로 삼고, task를 격리해 하나씩 처리한다.

```
PHASE 0: 어댑터 로드 (adapters/*.md 1개 Read → 검증모드·명령·리뷰어 확정)
PHASE 1: planner 호출 → task 목록 + task별 추천 모델(haiku/sonnet/opus) → 사용자 승인
PHASE 2: task 미니사이클을 task 수만큼 반복 (continuous execution, 격리)
PHASE 3: 통합 sanity check
→ finalize-feature 안내 (이 스킬은 커밋·산출물 문서 생성 안 함)
```

### 4.1 PHASE 2 task 미니사이클

골격은 미니사이클의 *모양*만 정의하고, ②번 게이트의 *내용*은 어댑터가 채운다.

```
① coder 호출 (해당 task 단독)
② <검증 게이트>        ← 어댑터의 검증모드로 분기
③ verifier (spec 준수)  ← 공통, 1단계 리뷰
④ reviewer (코드 품질)  ← 어댑터 지정, 2단계 리뷰
⑤ 요약만 보관, 응답 전문 폐기 → 다음 task
```

### 4.2 검증모드별 ①+② 전개

**검증모드 = tdd (backend.md)** — superpowers와 동일. RED 테스트는 coder가 작성:

```
①-a  coder: 실패하는 테스트 먼저 작성
②-a  골격: 게이트 명령 실행 → 실패 확인 (RED). 통과해버리면 반려
①-b  coder: 최소 구현
②-b  골격: 게이트 명령 실행 → 통과 확인 (GREEN). 명령은 backend.md가 제공(npm test/vitest)
```

**검증모드 = build-gate (flutter.md / unity.md)**:

```
①   coder: 구현
②   골격: flutter analyze + build_runner (또는 Unity 컴파일) → PASS 확인
```

같은 미니사이클 골격인데, ②에서 어댑터가 "테스트 RED→GREEN"을 끼우느냐 "빌드 PASS"를
끼우느냐만 다르다. TDD 강제는 backend 어댑터의 검증모드 선택으로 자연히 실현되고,
flutter/unity는 기존 빌드게이트를 그대로 유지한다.

### 4.3 재시도 규칙

게이트/리뷰 FAIL 시 같은 coder 재호출, **최대 2회**, 이후 사용자에게 보고 (현행
implement-agent 규칙 계승).

## 5. 어댑터 규약 (`_interface.md`)

모든 어댑터(`flutter/unity/backend.md`)가 채워야 할 슬롯의 계약서. 골격은 이 슬롯만 읽고,
안에 뭐가 들었는지는 모른다.

| 슬롯 | 의미 | backend.md | flutter.md |
|---|---|---|---|
| `검증모드` | `tdd` 또는 `build-gate` | `tdd` | `build-gate` |
| `게이트 명령` | ②에서 실행할 명령 | `npm test` / `vitest run` | `flutter analyze` + `build_runner` |
| `coder 규칙` | coder가 preload할 스택 규칙/스킬 | NestJS 규칙 | (Flutter 규칙) |
| `2단계 reviewer` | ④ 품질 검증 에이전트 | `backend-reviewer` | `flutter-reviewer` |
| `build resolver` | 게이트 실패 시 위임 에이전트(선택) | (없음/tsc 해결) | `dart-build-resolver` |
| `작업 디렉토리` | 명령 실행 기준 경로 | 프로젝트 루트 | `band_of_mercenaries` 등 |

새 스택 추가 = 이 표 한 장(`adapters/<stack>.md`) 작성 + 필요하면 reviewer 에이전트 하나.

## 6. 공통 에이전트 (`common/agents/`)

현재 flutter/unity의 `planner/coder/verifier`는 내부 예시가 스택 종속(Riverpod vs
SaveData)이라 그대로 common에 못 올린다. 따라서:

- **planner / verifier**: 예시를 스택 중립으로 다시 쓰고, 골격이 호출할 때 **어댑터에서
  읽은 스택 규칙·명령을 프롬프트에 주입**한다. ("이 프로젝트의 검증은 TDD다, 테스트 명령은
  X다" 같은 컨텍스트를 골격이 끼워 넣음)
- **coder**: 어댑터의 `coder 규칙` 슬롯이 가리키는 스택 규칙 스킬을 preload.
  (unity coder가 `error-handling`을 preload하던 방식의 일반화)
- **backend-reviewer**(신규): `flutter-reviewer`의 관심사(보안·아키텍처·성능·에러·테스트
  품질·접근성)를 Node/NestJS 맥락으로 옮긴 읽기 전용 품질 검증자. `.md` + `.toml` 둘 다.

## 7. 범위 밖 (후속 작업)

- 기존 `flutter/skills/implement-agent`·`unity/skills/implement-agent`의 골격 흡수·제거
- `spec-writer`의 골격+어댑터화 (backend 어댑터 포함)
- `finalize-feature`의 골격+어댑터화
- 스택을 고르면 골격+해당 어댑터만 대상 프로젝트로 세팅해주는 배포 도구

## 8. 산출물 목록 (1차)

- `common/skills/implement-agent/SKILL.md`
- `common/skills/implement-agent/adapters/_interface.md`
- `common/skills/implement-agent/adapters/{flutter,unity,backend}.md`
- `common/agents/{planner,coder,verifier}.md` + `.toml`
- `backend/agents/backend-reviewer.md` + `.toml`
- README.md 인덱스 표 갱신 (common/skills, common/agents, backend/agents 행 추가)
