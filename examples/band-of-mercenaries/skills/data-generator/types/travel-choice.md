# travel-choice — 이동 선택지 이벤트

> M3 마일스톤에서 신규 생성되는 이동 선택지 이벤트 12종·30 선택지·72 결과 (총 114행)를 생성하는 타입.
> 3개 신규 테이블(`travel_choice_events`/`_options`/`_results`)을 커버한다.
>
> 입력 기획서: `Docs/content-design/[content]20260424_travel_choices.md` (페이즈 1-5)
> 입력 밸런스: `Docs/balance-design/[balance]20260424_travel_choice_ev.md` (페이즈 2-3)
> 선행 조건: `traits` 테이블에 본 타입의 `preferred_traits`/`visibility_expr`에서 참조하는 트레잇 실존 검증 필수

## 선행 DDL

페이즈 3-5 벌크 생성 전 Supabase MCP `apply_migration`으로 3테이블 + data_versions 엔트리 생성:

```sql
CREATE TABLE travel_choice_events (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('encounter','dilemma','discovery','hazard')),
  situation TEXT NOT NULL,
  min_tier INT NOT NULL DEFAULT 1,
  max_tier INT NOT NULL DEFAULT 5,
  weight INT NOT NULL DEFAULT 1,
  preferred_traits TEXT,                      -- "empathy,brave" 쉼표구분, nullable
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_tce_tier ON travel_choice_events(min_tier, max_tier);
CREATE INDEX idx_tce_category ON travel_choice_events(category);

CREATE TABLE travel_choice_options (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES travel_choice_events(id) ON DELETE CASCADE,
  choice_index INT NOT NULL,
  label TEXT NOT NULL,
  visibility_expr TEXT,                       -- nullable → 항상 노출
  description TEXT,
  risk_level TEXT NOT NULL CHECK (risk_level IN ('safe','risky','hidden')),
  UNIQUE(event_id, choice_index)
);
CREATE INDEX idx_tco_event ON travel_choice_options(event_id);

CREATE TABLE travel_choice_results (
  id TEXT PRIMARY KEY,
  option_id TEXT NOT NULL REFERENCES travel_choice_options(id) ON DELETE CASCADE,
  result_index INT NOT NULL,
  probability REAL NOT NULL CHECK (probability > 0 AND probability <= 1),
  conditional_expr TEXT,
  narrative TEXT NOT NULL,
  effect_type TEXT NOT NULL CHECK (effect_type IN
    ('gold','injury','heal_tired','reputation','trait_innate','trait_acquired','item','nothing')),
  effect_magnitude REAL,
  effect_target TEXT,
  UNIQUE(option_id, result_index)
);
CREATE INDEX idx_tcr_option ON travel_choice_results(option_id);

INSERT INTO data_versions (table_name, version) VALUES
  ('travel_choice_events', 1),
  ('travel_choice_options', 1),
  ('travel_choice_results', 1);
```

---

## 대상 테이블

1. `travel_choice_events` — 12행
2. `travel_choice_options` — 30행 (기본 2선택지 × 6 + 3선택지 × 6)
3. `travel_choice_results` — 72행 (선택지당 2~3개, 합 72)

---

## 대상 1: `travel_choice_events` 12행

### 12종 시나리오 고정 목록 (기획서 §8 + balance 2-3)

**카테고리 4종 × 3개 = 12종**. 각 시나리오 고정 id·이름·카테고리·preferred_traits.

| id | name | category | preferred_traits | min_tier | max_tier | 선택지 수 (balance 2-3 §8-2 축소안) |
|---|---|---|---|---|---|---|
| `tce_enc_01` | 광인의 수수께끼 | encounter | scholar,curious | 1 | 5 | **3 (hidden 포함)** |
| `tce_enc_02` | 경쟁 용병단의 도움 요청 | encounter | leader | 1 | 5 | **2** |
| `tce_enc_03` | 왕실 전령의 급행 | encounter | NULL | 2 | 5 | **3 (hidden: joined_faction)** |
| `tce_dil_01` | 부상당한 여행자 | dilemma | empathy | 1 | 5 | **3 (hidden 포함)** |
| `tce_dil_02` | 쫓기는 도망자 | dilemma | brave | 1 | 5 | **2** |
| `tce_dil_03` | 무덤 도굴 가족 | dilemma | cunning | 2 | 5 | **3 (hidden 포함)** |
| `tce_dis_01` | 봉인된 동굴 입구 | discovery | scholar | 2 | 5 | **3 (hidden 포함)** |
| `tce_dis_02` | 버려진 마차 | discovery | tracker | 1 | 5 | **2** |
| `tce_dis_03` | 고대 제단의 돌 | discovery | faithful | 3 | 5 | **3 (hidden 포함)** |
| `tce_haz_01` | 부서진 다리 | hazard | hardy | 1 | 5 | **2** |
| `tce_haz_02` | 안개 낀 늪 | hazard | survival | 1 | 5 | **3 (hidden 포함)** |
| `tce_haz_03` | 절벽 위 좁은 길 | hazard | agile | 3 | 5 | **2** |

**balance 2-3 §8-2 축소**: 기획 원안 "12종 모두 hidden 포함" → **6종만 hidden 포함** (희소성 강화). 카테고리당 hidden 1.5개 비율로 분산.

### preferred_traits 실존 검증 (사전 필수)

**생성 전 반드시 실행**:
```sql
SELECT id FROM traits
WHERE id IN ('scholar', 'curious', 'leader', 'empathy', 'brave', 'cunning',
             'tracker', 'faithful', 'hardy', 'survival', 'agile');
```

누락 키워드는 근사 대체:
- `leader` → `charismatic` 또는 `natural_born_leader` (실존하는 키로)
- `scholar` → `learned` 또는 유사 Talent 카테고리
- `curious` → `inquisitive` 또는 유사
- `tracker` → `keen_observer` 또는 유사
- `faithful` → `devout` 또는 유사
- `hardy` → `robust` 또는 유사 Physical
- `survival` → `survivalist` 또는 유사
- `agile` → `nimble` 또는 유사

**매핑 결과는 생성 로그에 기록** → 사용자 확인 → 수정 승인 후 진행.

### `situation` 생성 규칙

- 2~3문장, **150~250자**
- 구성: 배경 → 용병 시점 → 일행 반응
- `{region.name}` 사용 가능 (일부 hazard 시나리오에 권장)
- `{merc.name}` 필수 — 한 문장 이상에 등장
- `{merc.job}` 선택 (scholar 용병이면 "{merc.job}의 눈이 흔적을 읽는다" 등)
- 문어체 ("~었다", "~했다")
- 톤 매트릭스 (기획서 §11-2):
  - encounter: 사람·말투·권력
  - dilemma: 양심·무게·여운
  - discovery: 신비·서늘함·기록
  - hazard: 자연·지형·인내

### `weight` 필드

**일괄 1**. 기획서 §(B) MVP.

---

## 대상 2: `travel_choice_options` 30행

### 선택지 구조

| 이벤트 | 선택지 구조 | option 수 |
|---|---|---|
| 3선택지 이벤트 × 6개 | safe + risky + hidden | 18 |
| 2선택지 이벤트 × 6개 | safe + risky | 12 |
| **합계** | | **30** |

### id 명명

`{event_id}_o{index}` (예: `tce_dil_01_o0`, `_o1`, `_o2`)

### choice_index

- 0: safe
- 1: risky
- 2: hidden (있을 때만)

### `risk_level` 배정 규칙

- choice_index 0 → `safe`
- choice_index 1 → `risky`
- choice_index 2 → `hidden`

### `visibility_expr` 배정 (hidden 전용)

6개 hidden option에만 값. 기획서 §8 매핑:

| event_id | visibility_expr |
|---|---|
| tce_enc_01 | `has_trait:scholar` |
| tce_enc_03 | `joined_faction:{실제 공식세력 id, 페이즈 3-5 확정}` |
| tce_dil_01 | `has_trait:empathy` |
| tce_dil_03 | `has_trait:cunning` |
| tce_dis_01 | `has_trait:scholar` |
| tce_dis_03 | `has_trait:faithful` |
| tce_haz_02 | `has_trait:survival` |

> **주의**: 위 7개는 balance 2-3에서 6종으로 축소 결정. 실제 6개 선정 시 각 카테고리 1~2종 균등 배분.

safe/risky option은 `visibility_expr IS NULL`.

**TemplateEngine 제약**: `visibility_expr`은 **team scope 평가**(페이즈 4-1 spec 반영 예정). 현재 문법 범위 내 연산자만 사용 (`has_trait`, `has_any_trait`, `joined_faction`).

### `label` 생성 규칙

- 6~12자 한국어
- 동사형 ("돕는다", "지나친다", "강행한다", "문자를 해독한다")
- 이벤트 상황과 정합 + risk_level과 톤 정합:
  - safe: 담담 ("지나친다", "돌아간다", "가이드를 고용한다")
  - risky: 단호 ("강행한다", "봉인을 깨뜨린다", "척살한다")
  - hidden: 단서 힌트 ("약초로 상처를 덮어준다", "문자를 해독한다")

### `description` 생성 규칙

- 0~1문장, **40~80자**
- 선택의 마음가짐·단서 한 줄
- nullable (필수 아님, 12종 중 6~8종에만 권장)
- 예: "갈 길이 멀다. 마음을 비우고 지나친다." / "품 안에 지닌 약초 뭉치가 떠올랐다."

---

## 대상 3: `travel_choice_results` 72행

### 분기 구조

선택지당 2~3개 결과. 총 72행 = 30 options × 평균 2.4.

### id 명명

`{option_id}_r{index}` (예: `tce_dil_01_o1_r0`)

### probability 규칙

- option 내 `probability` 합 = **1.0** (data-generator 반드시 검증)
- 2분기: 0.5/0.5 ~ 0.8/0.2 자유
- 3분기: 0.4/0.4/0.2 또는 0.5/0.3/0.2 등
- CHECK 제약: `probability > 0 AND probability <= 1`
- 0 확률 결과 생성 금지

### `conditional_expr` 활용

- 12종 이벤트 중 **4~6종**에 포함 (기획 §4-2)
- `has_trait:<id>` 또는 유사 TemplateEngine 연산자
- **평가 범위**: mercenary scope (대표 용병 1명 기준, 페이즈 4-1 spec 확정 예정)
- 포함된 result의 probability도 합 1.0 기여 (런타임에서 evaluate 후 정규화)
- 예:
  - `tce_dis_01_o1_r2`: `conditional_expr = "has_trait:hardy"`, probability 0.20 (hardy 보유 시만 후보)

### `effect_type` + `effect_magnitude` + `effect_target` (balance 2-3 §4-4 분포)

| effect_type | 행 수 목표 | magnitude 범위 | effect_target |
|---|---|---|---|
| `nothing` | 12 | NULL | NULL |
| `gold` | 22 | safe ±10~30 / risky ±40~80 / hidden +50~150 | NULL |
| `reputation` | 18 | safe +5~10 / risky +15~25 / hidden +20~35 | NULL |
| `injury` | 6 | 1 (고정) | NULL |
| `heal_tired` | 5 | -1 or +1 | NULL |
| `item` | 5 | 1~2 | `items.id` FK, **`items.tier ≤ 3`만** |
| `trait_acquired` | 3 | 1 | NULL (버프 대상은 대표 용병 자동) |
| `trait_innate` | 1 | 1 | `traits.id` FK (innate 타입: Physical/Background/Talent) |

**합**: 72행

### item 풀 (effect_target 실존 확인 필수)

생성 전 쿼리:
```sql
SELECT id, name, tier FROM items WHERE tier <= 3 ORDER BY tier, id;
```

이동 선택지에서 사용할 수 있는 item 풀(M2a tier ≤ 3):
- 하급(tier 1~2, 40G 환산 가치): 예상 ID `herb_bundle`, `minor_tonic`, `scout_compass` (실존 확인 후 사용)
- 중급(tier 3, 150G 환산 가치): 예상 ID `rare_herb`, `ancient_relic` (실존 확인 후 사용)
- **M2a items 테이블에 해당 ID 없으면**: 기존 items 중 가치 환산 가능한 ID로 대체. 사용자 확인 필요

**전설(tier 5) 절대 사용 금지**.

### `narrative` 생성 규칙

- 1~2문장, **40~120자**
- `{merc.name}` 필수 1회
- `[pick A|B|C]` 변주 블록 (전체 72행 중 50% 포함 권장, 각 2~4 후보)
- 결과 톤 (balance 2-3 §11-3):
  - safe 성공/무일: 담담·무탈 ("{merc.name}은 걸음을 멈추지 않았다. 신음 소리는 곧 멀어졌다.")
  - risky 성공: 보상 강조 ("{merc.name}은 응급처치를 마쳤다. 여행자는 [pick 눈물로|두 손을 모아] 감사를 전했다.")
  - risky 실패: 손실·부상 명시 ("돌보는 사이 병이 옮았다. {merc.name}은 기력을 잃은 채 돌아섰다.")
  - hidden 성공: 월등·특별함 ("{merc.name}의 손길 아래 여행자는 편히 눈을 감았다 떴다. 품 속에서 약초 뭉치를 건넸다.")

---

## EV 검증 (balance 2-3 §4-5 쿼리)

data-generator는 생성 직후 다음 Postgres 쿼리를 실행하여 EV 정책 준수 확인:

```sql
WITH result_ev AS (
  SELECT
    option_id,
    SUM(
      probability * (
        CASE effect_type
          WHEN 'gold' THEN effect_magnitude
          WHEN 'reputation' THEN effect_magnitude * 10
          WHEN 'injury' THEN -400
          WHEN 'heal_tired' THEN effect_magnitude * 50
          WHEN 'trait_innate' THEN 400
          WHEN 'trait_acquired' THEN 300
          WHEN 'item' THEN 100
          ELSE 0
        END
      )
    ) AS ev
  FROM travel_choice_results
  GROUP BY option_id
),
option_risk AS (
  SELECT o.event_id, o.risk_level, r.ev, o.id AS option_id
  FROM travel_choice_options o
  JOIN result_ev r ON r.option_id = o.id
)
SELECT
  h.event_id,
  h.ev AS hidden_ev,
  ri.ev AS risky_ev,
  h.ev / NULLIF(ri.ev, 0) AS ratio
FROM option_risk h
LEFT JOIN option_risk ri ON ri.event_id = h.event_id AND ri.risk_level='risky'
WHERE h.risk_level='hidden'
  AND (h.ev < 2 * ri.ev OR h.ev < 120);
```

**기대 결과**: **0행**. 위반 행 발생 시 해당 이벤트 수치 수정 후 재검증.

추가 검증:
```sql
-- probability 합 = 1.0 per option
SELECT option_id, SUM(probability) AS total
FROM travel_choice_results
GROUP BY option_id
HAVING ABS(SUM(probability) - 1.0) > 0.001;
```
→ 기대 결과: 0행

---

## 검증 체크리스트

### travel_choice_events (12행)

- [ ] 총 행 수 = 12
- [ ] category 분포: encounter 3 / dilemma 3 / discovery 3 / hazard 3
- [ ] `preferred_traits` 값의 모든 트레잇 id가 `traits.id` 실존
- [ ] `situation` 150~250자, 문어체, `{merc.name}` 1회 이상
- [ ] 모든 `id` 유일

### travel_choice_options (30행)

- [ ] 총 행 수 = 30
- [ ] event당 option: 2선택지 6이벤트 × 2 + 3선택지 6이벤트 × 3 = 30
- [ ] `risk_level` 분포: safe 12 / risky 12 / hidden 6
- [ ] hidden 6개에만 `visibility_expr` 값, 나머지 NULL
- [ ] `visibility_expr` TemplateEngine 연산자만 사용
- [ ] `choice_index` 0/1/2 규칙 준수 (0=safe, 1=risky, 2=hidden)
- [ ] `label` 6~12자 동사형
- [ ] UNIQUE(event_id, choice_index) 준수

### travel_choice_results (72행)

- [ ] 총 행 수 = 72
- [ ] option당 result 2~3개
- [ ] 모든 option의 `probability` 합 = 1.0 (오차 ±0.001)
- [ ] 0 < probability ≤ 1 전 행
- [ ] `effect_type` 8종만 등장
- [ ] 분포: nothing 12 / gold 22 / rep 18 / injury 6 / heal_tired 5 / item 5 / trait_acquired 3 / trait_innate 1
- [ ] `conditional_expr` 포함 결과: 4~6 이벤트에 분산
- [ ] `effect_target` FK 실존:
  - `item` effect: `items.id` 실존, `items.tier ≤ 3`
  - `trait_innate` effect: `traits.id` 실존, 카테고리 Physical/Background/Talent
- [ ] `narrative` 40~120자, `{merc.name}` 1회 이상, 문어체

### EV 정책 검증

- [ ] §4-5 쿼리 결과 0행 (hidden EV ≥ 2 × risky EV, hidden EV ≥ 120)
- [ ] probability 합 검증 쿼리 0행

---

## CSV 출력 포맷

**events 헤더**:
```csv
id,name,category,situation,min_tier,max_tier,weight,preferred_traits
```

**options 헤더**:
```csv
id,event_id,choice_index,label,visibility_expr,description,risk_level
```

**results 헤더**:
```csv
id,option_id,result_index,probability,conditional_expr,narrative,effect_type,effect_magnitude,effect_target
```

**파일 분리**: 3개 CSV 파일 생성
- `[travel-choice]20260424_m3-events.csv`
- `[travel-choice]20260424_m3-options.csv`
- `[travel-choice]20260424_m3-results.csv`

**예시 행 (results, hidden item)**:
```csv
tce_dil_01_o2_r0,tce_dil_01_o2,0,0.90,,"{merc.name}의 손길 아래 여행자는 편히 눈을 감았다 떴다. 품 속에서 말린 약초 뭉치를 꺼내 건넸다.",item,1,rare_herb
```

**예시 행 (results, safe=nothing)**:
```csv
tce_dil_01_o0_r0,tce_dil_01_o0,0,1.00,,"{merc.name}은 걸음을 멈추지 않았다. 신음 소리는 곧 멀어졌다.",nothing,,
```

---

## 삽입 순서 (FK 제약)

1. `travel_choice_events` 12행 먼저
2. `travel_choice_options` 30행 (event_id FK 필요)
3. `travel_choice_results` 72행 (option_id FK 필요)

각 INSERT는 트랜잭션 단위 묶음. 실패 시 전체 롤백.

---

## 생성 후 안내 포맷

```
## travel-choice 생성 완료

### travel_choice_events: 12행
- category 분포: encounter 3 / dilemma 3 / discovery 3 / hazard 3
- preferred_traits 실존 매핑: [키 목록] (N개 근사 대체 / N개 실제 매칭)

### travel_choice_options: 30행
- risk_level: safe 12 / risky 12 / hidden 6
- hidden visibility_expr: 6개 확인 (balance 2-3 축소안 반영)

### travel_choice_results: 72행
- effect_type 분포: nothing 12 / gold 22 / rep 18 / injury 6 / heal_tired 5 / item 5 / trait_acquired 3 / trait_innate 1
- item effect_target 실존: N종 (items.tier ≤ 3)
- trait_innate effect_target 실존: N종

EV 정책 검증:
- hidden ≥ 2×risky, ≥120G: 통과/실패 (위반 N건)
- probability 합 = 1.0: 통과/실패 (위반 N건)

DDL 선행 확인:
- 3테이블 생성: ✅
- data_versions 엔트리 3개: ✅

Supabase에 쓰시겠습니까? (y / 수정 후 진행 / n)
```
