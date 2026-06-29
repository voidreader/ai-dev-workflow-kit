---
name: flame-harness-research
description: Phase 1 — 스토어 차트·경쟁작 조사, 2-3개 게임 컨셉 제안, 사용자 선택, 클론 회피 검증, research 스펙 작성 및 파이프라인 상태 갱신.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, WebFetch, WebSearch, AskUserQuestion, Bash]
---

Recommended Model : Claude Sonnet
** 한국어 스타일 유지 **

# flame-harness-research

flutter-flame-harness 파이프라인의 Phase 1 스킬이다. `config.md`에서 사용자의 원시 아이디어를 읽고, 필요시 시장 조사를 수행하며, 2-3개의 구체적인 게임 컨셉을 제안하고, AskUserQuestion으로 사용자에게 선택을 요청한다. 선택된 컨셉의 App Store 가이드라인 4.3 클론 위험을 검사한 뒤, research 스펙을 작성하고 파이프라인 상태를 갱신한다.

모든 파일 스키마(`config.md`, `state.md`, `pipeline-log.md`)는 `docs/harness/protocol.md`에 정의되어 있다 — 해당 문서를 단일 진실 공급원으로 참조하라. 스키마를 여기서 재정의하지 않는다.

---

## 입력

`docs/harness/config.md`를 읽어 다음 항목을 추출한다:

- `app_idea` — 사용자가 제공한 게임 아이디어 한 줄 (비어 있을 수 있음. 비어 있으면 Discovery 단계에서 아이디어를 처음부터 생성한다). `app_idea`가 비어 있으면 Discovery 및 "제안 & 선택" 단계는 시드 컨셉 없이 시장 조사와 창의적 추론만으로 진행하며, 결과를 AskUserQuestion으로 사용자에게 제시한다. 단, **`auto_idea: true`** 이면 "제안 & 선택" 단계에서 사용자 입력 없이 자동 채점 및 선택한다(해당 섹션 참조).
- `skip_research` — 불리언. `true`이면 `app_idea`를 그대로 선택된 컨셉으로 취급하고 **Discovery 및 "제안 & 선택" 단계를 완전히 건너뛴다**. 클론 회피 단계로 바로 이동한 뒤 출력한다. skip_research가 true여도 research 스펙은 반드시 작성한다.
- `auto_idea` — 불리언 (기본값 `false`). `true`이면 "제안 & 선택" 및 "클론 회피" 단계에서 AskUserQuestion을 호출하지 않고 자동으로 판단한다: 생성한 컨셉을 직접 채점·선택하고 클론이면 자동 수정 — 완전 무인 모드로 실행된다. `skip_research: true`일 때는 아이디어가 이미 확정되므로 효과 없음.

`config.md`가 존재하지 않으면 다음 메시지로 중단한다:
`flame-harness-research: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

---

## Discovery

> `skip_research: true`이면 이 섹션을 건너뛴다.

목표: 제안이 실제 시장 데이터를 바탕으로 하도록 현재 모바일 게임 시장을 파악한다.

### 1. 상위 차트 게임

WebSearch 및/또는 WebFetch를 사용해 Google Play 및 App Store의 현재 최고 매출·무료 모바일 게임 차트를 가져온다. 사용할 검색 쿼리:

- `"Google Play" top grossing mobile games 2026 site:sensor tower OR site:appfigures OR site:apptopia`
- `"App Store" top free games 2026 site:sensor tower OR site:apptopia`
- `"Flutter Flame" game examples 2026`

각 차트에서 최소 10개 타이틀과 장르/메카닉(예: 아이들 클리커, 하이퍼캐주얼 러너, 매치-3, 타워 디펜스, 머지)을 추출한다.

### 2. 경쟁작 매핑

`app_idea`가 있으면 가장 관련 깊은 장르, 없으면 차트 빈도 상위 2개 장르에서 대표 타이틀 3-5개의 스토어 페이지를 WebFetch로 가져온다. 각 타이틀에 대해 다음을 기록한다:

- 타이틀, 장르, 핵심 메카닉
- 차별화 기능 (무엇이 이 게임을 돋보이게 하는가)
- 대략적인 평점과 다운로드 규모 (페이지에 표시된 경우)

### 3. 트렌드 신호

WebSearch로 "hypercasual game trends 2026"과 "mobile game genre growth 2026"을 검색한다. 제안에 반영할 구체적인 트렌드 신호 2-3개를 추출한다(예: "머지 메카닉 YoY 40% 성장", "오프라인 플레이 게임 상승").

---

## 제안 & 선택

Discovery 결과(및 `app_idea`가 있으면 이를 종합)를 바탕으로 정확히 **2-3개의 구체적인 게임 컨셉 제안**을 작성한다. 각 제안에는 다음 항목이 포함되어야 한다:

| 항목 | 설명 |
|---|---|
| 타이틀 | 작업 제목 |
| 태그라인 | 핵심 루프를 설명하는 한 문장 (15단어 이하) |
| 핵심 메카닉 | 플레이어가 10-30초마다 수행하는 행동 |
| 차별점 | 기존 상위 차트와 구별되는 한 가지 요소 |
| Flame 적합성 | Flutter/Flame이 잘 맞는 이유 (2문장 이하) |
| 수익화 훅 | AdMob 광고가 자연스럽게 맞는 방식 (전면광고/보상형/배너) |

제안을 읽기 쉬운 번호 목록으로 제시한다.

이후 `auto_idea` 값에 따라 분기한다:

### `auto_idea: false` (기본) — 사용자에게 선택 요청

**AskUserQuestion**을 사용해 다음을 묻는다:

```
어떤 컨셉을 만들고 싶으신가요?
번호(1, 2, 또는 3)를 입력하거나, 원하는 변형을 설명해주세요.
그대로 진행하고 싶으시면 번호만 입력해주세요.
```

사용자 응답을 기다린다. 번호를 입력하면 해당 제안을 선택된 컨셉으로 설정한다. 변형을 설명하면 가장 가까운 기본 제안과 합쳐, 아래 AskUserQuestion으로 확인한다:

```
알겠습니다. 다음과 같이 진행합니다: <합쳐진 컨셉 요약>.
맞나요? (예 / 더 설명해주세요)
```

사용자가 확인할 때까지 반복한다.

### `auto_idea: true` — 자동 채점 및 선택 (사용자 입력 없음)

AskUserQuestion을 **호출하지 않는다**. 2-3개 제안을 아래 가중 기준으로 채점하고 간단한 채점 표를 제시한다:

| 기준 | 가중치 |
|---|---|
| 시장 적합성 | 30% |
| 차별성 / 클론 안전성 | 25% |
| Flame 적합성 | 20% |
| 수익화 적합성 | 15% |
| MVP 범위 실현 가능성 | 10% |

각 기준을 0-10점으로 채점하고 가중치를 곱한 뒤 합산해 제안별 가중 총점을 구한다. 표(제안별 행, 기준별 열, Total 열)를 렌더링한 뒤 **총점이 가장 높은 제안**을 선택된 컨셉으로 확정한다. 선택 결과와 한 줄 근거를 출력한다. 예: `자동 선택: <타이틀> (총점 8.4/10) — 가장 강한 시장 적합성에 클론 안전 변형 추가.` 그런 다음 클론 회피 단계로 진행한다. 사용자에게 묻지 않는다.

---

## 클론 회피

App Store 가이드라인 **4.3**은 기존 앱의 직접적인 복사(클론)를 금지한다. 스펙 작성 전, 선택된 컨셉이 직접 클론에 해당하지 않는지 검증한다.

### 검사 절차

1. 선택된 컨셉에서 핵심 메카닉을 추출한다.
2. WebSearch로 가장 유사한 기존 모바일 게임 3개를 찾는다:
   `"<핵심 메카닉>" mobile game App Store 2025 OR 2026`
3. 각 유사 게임에 대해 타이틀, 메카닉, 차별화 기능을 기록한다.
4. 클론 판단 기준 적용: 동일한 메카닉 **AND** 동일한 테마/배경 **AND** 독창적 기능이 없으면 **클론**. 다음 중 하나라도 있으면 **안전**:
   - 새로운 메카닉 변형 (예: 러너에서 중력 반전)
   - 상위 3개 게임에 없는 독특한 배경/아트 디렉션
   - 상위 3개 게임에 없는 게임플레이 모드 (예: 협동, 비동기 멀티플레이)

5. 컨셉이 클론이면 진행을 중단하고 `auto_idea` 값에 따라 분기한다:

   **`auto_idea: false` (기본)** — AskUserQuestion으로 다음을 묻는다:
   ```
   선택한 컨셉이 App Store의 <유사 앱>과 너무 유사해 App Store 가이드라인 4.3(클론 규정)을 위반할 수 있습니다.
   어떻게 차별화하고 싶은지 설명하거나 다른 컨셉을 선택해주세요.
   ```
   수정된 컨셉에 대해 클론 검사를 다시 실행한다.

   **`auto_idea: true`** — AskUserQuestion을 **호출하지 않는다**. 위 "안전" 목록에서 차별화 요소 하나를 자동으로 적용해 컨셉을 수정한 뒤 클론 검사를 다시 실행한다. 최대 2회 재시도한다. 2회 후에도 클론이면 "제안 & 선택"에서 차순위 제안으로 폴백하여 클론 검사를 실행한다. 결과(어떤 차별화 요소를 적용했는지, 또는 폴백 사용 여부)를 기록한다.

6. 클론 검사 결과를 research 스펙에 기록한다(아래 출력 참조).

---

## 출력

### 1. Research 스펙 작성

`docs/harness/specs/<YYYY-MM-DD>-research.md` 파일을 생성한다(오늘 UTC 날짜 사용). 다음 구조를 사용한다:

```markdown
# Research Spec — <app_name>

## 선택된 컨셉

**타이틀:** <작업 제목>
**태그라인:** <한 문장>
**핵심 메카닉:** <플레이어의 행동>
**차별점:** <독창적 훅>
**Flame 적합성:** <Flutter/Flame이 맞는 이유>
**수익화 훅:** <AdMob 연동 방식>
**선택 방식:** <user-selected | auto-selected (auto_idea) — 자동 선택이면 가중 총점 포함>

## 시장 근거

<차트/트렌드 데이터가 이 선택을 뒷받침하는 이유를 2-4문장으로 요약.
상위 경쟁작과 발견된 트렌드 신호를 참조한다.>

## 경쟁작 요약

| 타이틀 | 메카닉 | 차별점 |
|---|---|---|
| <타이틀> | <메카닉> | <차별점> |

## 클론 회피 검사 (App Store 4.3)

**결과:** SAFE / CLONE (해결됨)
**검사한 유사 앱:** <타이틀 1>, <타이틀 2>, <타이틀 3>
**차별화 기능:** <4.3 거절을 방지하는 기능 목록>

## Skip-Research 비고

<!-- skip_research가 true였으면: "Discovery 건너뜀 — app_idea를 그대로 채택." 으로 작성 -->
<!-- 그 외에는 이 섹션을 삭제 -->
```

### 2. `config.md` 갱신

`app_idea`를 최종 확정된 컨셉 태그라인으로 설정한다(원래 원시 아이디어를 덮어씀). 이를 통해 하류 스킬(plan, design, contract)이 정제된 컨셉을 읽도록 한다.

`Edit`으로 targeted update를 수행한다 — 파일 전체를 재작성하지 않는다.

### 3. `state.md` 갱신

`docs/harness/state.md`를 `docs/harness/protocol.md` §2의 스키마에 따라 갱신한다:

```yaml
status: running
current_phase: research
next_role: plan
updated_at: "<ISO-8601 UTC now>"
```

나머지 키는 그대로 둔다. `Edit`으로 targeted update를 수행한다.

### 4. `pipeline-log.md`에 행 추가

`docs/harness/protocol.md` §6의 스키마에 따라 `docs/harness/pipeline-log.md`에 한 행을 추가한다:

```
| <ISO-8601 UTC now> | complete | research | <N>개 경쟁작 분석; 컨셉: <작업 제목> |
```

`skip_research`가 true였으면:

```
| <ISO-8601 UTC now> | complete | research | skip_research=true; 컨셉 그대로 채택 |
```

---

## 오류 처리

- Discovery 중 WebSearch 또는 WebFetch가 실패하면 경고를 기록하고 가져온 데이터로 계속 진행한다. 중단하지 않는다 — 부분적인 시장 데이터가 없는 것보다 낫다.
- 사용자가 3회의 AskUserQuestion 라운드 후에도 모든 제안을 거절하고 실행 가능한 대안을 제시하지 않으면, `state.md`의 `status`를 `paused`, `pause_reason`을 `manual_action`으로 설정하고, 사용자가 컨셉을 결정하지 못했다는 내용을 `pipeline-log.md`에 기록한다.
- `docs/harness/specs/` 디렉토리가 존재하지 않으면 스펙 파일을 작성하기 전에 생성한다.
