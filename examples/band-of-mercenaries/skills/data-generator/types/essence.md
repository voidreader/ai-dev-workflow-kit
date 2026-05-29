# essence — 정수 (영구 스탯 강화 소모품)

> 용병 1명의 특정 스탯을 영구 증가시키는 희귀 소모형 아이템. M2a 마일스톤에서 `items` 테이블의 `category=consumable` + `slot=essence_*` 필드 조합으로 구현된다.
>
> 동시에 M6에서 용병 티어 승급 재료로 재사용되는 **다목적 희귀 재화**다. 따라서 M2a에서 설계한 20종 데이터가 M6에서도 그대로 사용된다.

## 대상 테이블

**`items`** (Supabase, **신규 테이블**)

**전제 조건:**
- M2a 페이즈 4 spec-writer에서 `items` 테이블 생성이 선행되어야 한다. 미생성 상태에서 data-generator를 실행하면 테이블 없음 에러가 발생한다
- operation-bom의 `table-config.ts`에 `items` 정의 추가 (category/slot/tier 셀렉트 필드)
- `data_versions` 테이블에 `items` 행 추가 (첫 생성 시 version=1)

## 스키마 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | text | ✅ | 고유 ID. 형식: `essence_{stat}_t{tier}` (예: `essence_str_t3`) — 유니크 PK, tier suffix 포함 |
| `name` | text | ✅ | 정수 이름. 한국어. 수식어 체계 준수 (아래 톤 규칙 참조) |
| `description` | text | ✅ | 관리자용 짧은 기능 요약. **DB NOT NULL**. 권장 포맷: `"{STAT} +{n} 영구 강화"` (예: `"STR +4 영구 강화"`) |
| `flavor_text` | text | ✅ | 서사·분위기 텍스트. 1~2문장 |
| `category` | text | ✅ | **고정값**: `consumable` |
| `slot` | text | ✅ | 형식: `essence_{stat}` (tier suffix **없음**, 예: `essence_str`). DB `items_slot_check` constraint가 tier suffix 불허하므로 **tier는 별도 `tier` 컬럼과 조합하여 식별**. id는 `essence_{stat}_t{tier}`로 유지 (slot과 다름) |
| `tier` | integer | ✅ | 1~5 |
| `effect_json` | jsonb | ✅ | 아래 스키마 참조 |

## effect_json 스키마

**고정 형식:**
```json
{
  "permanent_stat_gain": {
    "<stat_key>": <value>
  }
}
```

- `<stat_key>`: `str` / `intelligence` / `vit` / `agi` 중 **정확히 1종만**
- `<value>`: 티어별 공식값 (아래 수치 테이블 참조)
- 다른 키 금지. 복합 효과 금지 (단일 주스탯 정책)

## 수치 테이블 (balance-designer 확정)

출처: `Docs/balance-design/20260418_essence_inflation.md`

| 티어 | `permanent_stat_gain.<stat>` 값 |
|:---:|:---:|
| T1 | **1** |
| T2 | **2** |
| T3 | **4** |
| T4 | **7** |
| T5 | **11** |

**4축(str/intelligence/vit/agi) 모두 동일 공식 적용.** 축에 따른 수치 차이 없음.

## 톤/세계관 규칙

### 명칭 수식어 체계 (initial_item_set 기획서 확정)

**시간·연대 계열 접두사, 4축 동일 적용:**

| 티어 | 수식어 | STR (힘) | INT (지혜) | VIT (수호) | AGI (민첩) |
|:---:|:---:|---|---|---|---|
| T1 | (없음) | 힘의 정수 | 지혜의 정수 | 수호의 정수 | 민첩의 정수 |
| T2 | 오래된 | 오래된 힘의 정수 | 오래된 지혜의 정수 | 오래된 수호의 정수 | 오래된 민첩의 정수 |
| T3 | 고대의 | 고대의 힘의 정수 | 고대의 지혜의 정수 | 고대의 수호의 정수 | 고대의 민첩의 정수 |
| T4 | 태고의 | 태고의 힘의 정수 | 태고의 지혜의 정수 | 태고의 수호의 정수 | 태고의 민첩의 정수 |
| T5 | 태초의 | 태초의 힘의 정수 | 태초의 지혜의 정수 | 태초의 수호의 정수 | 태초의 민첩의 정수 |

**설계 의도:**
- "더 오랜 시간을 지나온 정수일수록 귀하다" — `idea_note.md`의 "게임 속 바바리안으로 살아남기" 감성 직결
- 수식어 고정. 자율 변형·대체 금지 (명칭 체계 일관성 유지)

### flavor_text 톤 규칙

- 정수의 **출처·분위기** 중심. 효과 설명은 하지 않음 (`effect_json`이 담당)
- 1~2문장, 최대 약 60자
- 티어가 오를수록 **신비·고대성 강조**, 저티어는 평이한 일상성
- "각인" 서사 활용 가능 (기획서의 정수 소비 연출과 연동)

**예시 톤:**

| 티어 | 예시 (힘의 정수) |
|:---:|---|
| T1 | "전장에서 쓰러진 전사의 의지가 결정으로 맺혔다. 가장 흔한 형태의 정수." |
| T2 | "수십 년 전 전쟁의 기억을 담은 탁한 결정. 손에 쥐면 희미한 함성이 들린다." |
| T3 | "수백 년의 시간이 정제된 결정체. 이것을 각인한 전사의 근육엔 잊혀진 기술이 깃든다." |
| T4 | "태고 이전의 전투를 목격한 정수. 그 빛은 차갑지만 품은 힘은 뜨겁다." |
| T5 | "세계가 형체를 갖기 전부터 존재한 빛의 조각. 이것을 각인받은 자는 그 자체로 전설이 된다." |

### 저작권 금칙

- `Docs/idea_note.md` 웹소설 레퍼런스의 **고유명사·인물·세계관** 차용 금지
- 감성 톤만 추출. "용마검전"·"메모라이즈" 등의 고유 명칭 사용 금지

## 생성 수량 가이드라인

**고정: 20종** (스탯 4축 × 티어 5단계 전체 매트릭스)

- 이 매트릭스는 **모든 조합이 필수**. 누락 시 재생성
- 축별 5종씩 균등 분포 (빠짐 없음)

| stat | T1 | T2 | T3 | T4 | T5 | 합 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| str | 1 | 1 | 1 | 1 | 1 | 5 |
| intelligence | 1 | 1 | 1 | 1 | 1 | 5 |
| vit | 1 | 1 | 1 | 1 | 1 | 5 |
| agi | 1 | 1 | 1 | 1 | 1 | 5 |
| **합** | 4 | 4 | 4 | 4 | 4 | **20** |

## 상호 참조

생성 전 다음을 Supabase MCP로 확인한다:

1. **`items` 테이블 존재 여부** — 없으면 중단하고 spec-writer 페이즈 4 선행 필요 안내
2. **`items` 테이블 중복 검증** — 동일 `id` 또는 `(slot, tier)` 조합의 기존 항목이 있는지 확인 (중복 방지)
3. **`data_versions` 테이블** — `items` 행 존재 여부 확인. 미존재 시 사용자에게 알리고 생성 후 투입 안내

## CSV 출력 포맷

**헤더:**
```csv
id,name,description,flavor_text,category,slot,tier,effect_json
```

**예시 행 (T1~T3 발췌):**
```csv
essence_str_t1,힘의 정수,STR +1 영구 강화,전장에서 쓰러진 전사의 의지가 결정으로 맺혔다. 가장 흔한 형태의 정수.,consumable,essence_str,1,"{""permanent_stat_gain"":{""str"":1}}"
essence_int_t1,지혜의 정수,INT +1 영구 강화,흘려보낸 지식이 결정으로 남았다. 가장 흔한 형태의 정수.,consumable,essence_int,1,"{""permanent_stat_gain"":{""intelligence"":1}}"
essence_vit_t2,오래된 수호의 정수,VIT +2 영구 강화,수십 년 전 전장을 견뎌낸 가죽의 의지가 결정에 담겼다.,consumable,essence_vit,2,"{""permanent_stat_gain"":{""vit"":2}}"
essence_agi_t3,고대의 민첩의 정수,AGI +4 영구 강화,수백 년의 질주가 정제된 결정체. 쥐면 바람이 손끝에 맴돈다.,consumable,essence_agi,3,"{""permanent_stat_gain"":{""agi"":4}}"
```

**주의:**
- JSONB 필드(`effect_json`)는 JSON 문자열로 직렬화하고 쌍따옴표를 `""`로 이스케이프
- 한국어 텍스트는 쌍따옴표로 감싸지 않되, 쉼표가 포함되면 감싼다
- `description`은 **DB NOT NULL**이므로 빈 값 금지. `"STR +{n} 영구 강화"` 포맷 권장
- `id`는 `essence_{stat}_t{tier}` (tier suffix 포함), `slot`은 `essence_{stat}` (tier suffix 없음). 두 값이 다름에 주의

## 자체 검증 체크리스트

생성 직후 다음을 확인한다:

- [ ] 모든 `id`가 `essence_{stat}_t{tier}` 형식인가 (stat ∈ {str, intelligence, vit, agi}, tier ∈ {1..5})
- [ ] 모든 `id`가 유일한가 (내부 중복 없음)
- [ ] 4축 × 5티어 = 20종 전체가 빠짐없이 생성되었는가
- [ ] 모든 `category` = `consumable`
- [ ] 모든 `slot` = `essence_{stat}` (tier suffix 없음, DB constraint 준수)
- [ ] `effect_json.permanent_stat_gain`의 키가 slot의 stat 부분과 일치 (예: `slot=essence_str` → `str`만)
- [ ] `effect_json.permanent_stat_gain`의 값이 수치 테이블(1/2/4/7/11)과 일치
- [ ] 모든 `name`이 수식어 체계(기본/오래된/고대의/태고의/태초의)를 정확히 따름
- [ ] 모든 `description`이 채워져 있는가 (DB NOT NULL, "STR +{n} 영구 강화" 포맷 권장)
- [ ] `flavor_text`가 모든 행에 존재 (1~2문장, 약 60자 이내)
- [ ] 저작권 금칙 준수 (웹소설 고유명사 미사용)

## 기획서에서 추출해야 할 항목

`--brief` 기획서를 읽을 때 다음을 확인한다:

1. **수치 확정 상태** — 기본 초안(+1/+2/+4/+7/+11) 유지인지, balance-designer가 조정했는지
2. **추가 수식어 지정** — 기본 체계(기본/오래된/고대의/태고의/태초의) 외 별도 명칭 지시가 있는지
3. **저작권 주의 문구** — 웹소설 레퍼런스 고유명사 금칙 재확인

**표준 `--brief` 경로 (M2a):**
- `Docs/content-design/[content]20260418_essence_system.md` (정수 시스템 기획)
- `Docs/content-design/[content]20260418_initial_item_set.md` (정수 20종 명칭 체계 확정)
- `Docs/balance-design/20260418_essence_inflation.md` (수치 최종 확정)

세 문서 모두 참조하여 규칙·수식어·수치를 교차 확인한다.

## 특수 요구

### M6 선반영 원칙

- **동일 아이템 풀 재사용**: M2a에서 생성된 20종이 M6 승급 재료로 재사용된다. 이 때문에 아이템 ID는 M6에서도 참조 가능하도록 고정 (`essence_str_t1` 등)
- 데이터 재생성 금지. 한 번 생성 후 재생성 시 동일 ID 중복 에러 발생하므로 주의

### 상한·사망·방출 정책은 런타임 코드 영역

- 정수 1개 사용 시 용병 티어별 상한 판정, 초과 시 손실, 사망/방출 시 소멸 등은 **spec-writer 페이즈 4의 EssenceService 구현 영역**
- data-generator는 데이터만 생성. 런타임 규칙은 데이터에 포함하지 않음

### description 필드 운영

- M2a 범위에서 `description`은 사용하지 않거나 매우 간결한 한 줄만 사용 권장. 주요 서사는 `flavor_text`가 담당
- operation-bom UI에서 관리자 참조용 짧은 설명으로만 활용 가능 (예: "STR +4 영구 강화")

## 생성 후 안내 (사용자 확인용)

CSV 생성 후 다음을 요약 보고한다:

```
## 정수 20종 생성 완료

- 분포: str 5 / intelligence 5 / vit 5 / agi 5
- 티어 분포: T1 4개 / T2 4개 / T3 4개 / T4 4개 / T5 4개
- 수치 총합: +1×4 + +2×4 + +4×4 + +7×4 + +11×4 = 100 포인트 (참고)
- 수식어 체계 준수: 기본/오래된/고대의/태고의/태초의
- 저작권 검증: 웹소설 고유명사 미사용 확인

검토 후 Supabase에 쓰시겠습니까? (y / 선택 행 / n)
```
