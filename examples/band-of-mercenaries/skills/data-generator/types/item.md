# item — 일반 아이템 (개인 장비 + 용병단 장비)

> 용병 개인에게 장착되는 **개인 장비**(weapon/armor/helmet/boots/accessory)와 용병단 전체가 공유하는 **용병단 장비**(banner/artifact)를 생성하는 타입. M2a 마일스톤에서 `items` 테이블의 `category=personal_equipment` 또는 `category=guild_equipment`로 구현된다.
>
> 소모품(정수)은 별도 타입 `essence`를 사용한다. 본 타입은 **장비만** 다룬다.

## 대상 테이블

**`items`** (Supabase, **신규 테이블**)

**전제 조건:**
- M2a 페이즈 4 spec-writer에서 `items` 테이블 생성이 선행되어야 한다
- operation-bom의 `table-config.ts`에 `items` 정의 추가 (category/slot/tier 셀렉트 필드, `effect_json` JSONB 편집기)
- `data_versions` 테이블에 `items` 행 추가 (첫 생성 시 version=1)

## 스키마 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | text | ✅ | 고유 ID. 형식은 카테고리별 아래 참조 |
| `name` | text | ✅ | 아이템 이름. 한국어. 작명 톤 규칙 준수 |
| `description` | text | ✅ | 관리자용 간단 설명. **DB NOT NULL**. 권장 포맷: `"{slot} / {주스탯 +N}"` (예: `"weapon / STR +6"`, `"banner / 명성+5% 골드+2%"`). 효과 요약 톤으로 한 줄만 |
| `flavor_text` | text | ✅ | 서사·분위기 텍스트. 1~2문장 |
| `category` | text | ✅ | `personal_equipment` 또는 `guild_equipment` 중 하나 |
| `slot` | text | ✅ | 카테고리별 허용 값 (아래 참조) |
| `tier` | integer | ✅ | 개인 장비 2~5, 용병단 장비 3~5 |
| `effect_json` | jsonb | ✅ | 카테고리별 스키마 분기 (아래 참조) |

### id 형식

| 카테고리 | id 형식 | 예시 |
|---|---|---|
| `personal_equipment` | `equip_{slot}_{slug}` | `equip_weapon_steel_sword`, `equip_accessory_soul_seal` |
| `guild_equipment` | `guild_{slot}_{slug}` | `guild_banner_standard`, `guild_artifact_golden_scale` |

### slot 허용 값

| 카테고리 | 허용 slot |
|---|---|
| `personal_equipment` | `weapon`, `armor`, `helmet`, `boots`, `accessory` |
| `guild_equipment` | `banner`, `artifact` |

## effect_json 스키마 (카테고리별 분기)

### 개인 장비 (`personal_equipment`)

**단일 주스탯 정책.** 주스탯 1종만 포함. 복합 금지.

```json
{ "<stat_key>": <value> }
```

- `<stat_key>`: `str` / `intelligence` / `vit` / `agi` 중 **정확히 1종**
- slot별 허용 `stat_key`:

| slot | 허용 `stat_key` |
|---|---|
| `weapon` | `str` 또는 `intelligence` (택 1) |
| `armor` | `vit` 고정 |
| `helmet` | `vit` 고정 |
| `boots` | `agi` 고정 |
| `accessory` | `str` / `intelligence` / `vit` / `agi` 중 택 1 |

**전설 아이템 (T5 1종)**: 위 단일 주스탯에 `legendary_effect` 필드 추가
```json
{
  "<stat_key>": <legendary_value>,
  "legendary_effect": {
    "category": "<category>",
    "<effect_key>": <effect_value>
  }
}
```

### 용병단 장비 (`guild_equipment`)

**거시 지표 키만 허용. 개인 스탯 키(`str`/`intelligence`/`vit`/`agi`) 금지.**

허용 키:

| 키 | 범위 | 부호 |
|---|:---:|:---:|
| `gold_reward_multiplier` | 0.02 ~ 0.12 | 양수 |
| `recruit_high_tier_chance` | 0.01 ~ 0.05 | 양수 |
| `injury_rate_modifier` | -0.03 ~ -0.15 | 음수 |
| `reputation_gain_modifier` | 0.05 ~ 0.15 | 양수 |

**복합 키 허용** (banner 전용). 단일 아이템 내 동일 키 중복 금지.

## 수치 테이블 (balance-designer 확정)

출처:
- 개인 장비: `Docs/balance-design/20260418_equipment_stats.md`
- 용병단 장비: `Docs/balance-design/20260418_guild_equipment_macro.md`

### 개인 장비 — tier × slot 수치 매트릭스

| slot | 주 스탯 | T2 | T3 | T4 | T5 일반 | T5 전설 (×1.2) |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| weapon | `str` 또는 `intelligence` | **3** | **6** | **10** | **15** | **18** |
| armor | `vit` | **3** | **6** | **10** | **15** | **18** |
| helmet | `vit` | **2** | **5** | **8** | **12** | **14** |
| boots | `agi` | **2** | **5** | **8** | **12** | **14** |
| accessory | `str`/`intelligence`/`vit`/`agi` 택 1 | **2** | **4** | **6** | **9** | **11** |

### 개인 장비 — 전설 유니크 효과 풀 (전설 1종만 적용)

선택된 카테고리의 effect 필드 1종만 `legendary_effect.<effect_key>`에 포함:

| `legendary_effect.category` | 사용 가능 effect_key | 값 범위 |
|:---:|---|:---:|
| `success_rate_bonus` | `raid_success_rate` / `hunt_success_rate` / `escort_success_rate` / `explore_success_rate` | +3 ~ +5 (%p, 정수) |
| `result_upgrade` | `success_to_great_chance` | 0.03 ~ 0.05 |
| `damage_resistance` | `injury_rate_modifier` / `death_rate_modifier` | -0.05 ~ -0.15 |
| `reward_bonus` | `gold_reward_multiplier` | 0.05 ~ 0.12 |
| `special` | `death_prevention_count` + `cooldown_hours` | count 1, cooldown_hours 24 |

**M2a 범위**: 전설 1종만 생성되므로 카테고리 1개 선택. 아래 컨셉별 권장:
- 멸혼결 (accessory) → `damage_resistance` 또는 `special`
- 광란검 (weapon) → `result_upgrade`
- 이그드라실 수피갑 (armor) → `damage_resistance`

### 용병단 장비 — 4종 고정 스펙

| # | id | slot | tier | effect_json |
|:-:|---|---|:---:|---|
| 1 | `guild_banner_standard` | banner | 3 | `{"reputation_gain_modifier": 0.05, "gold_reward_multiplier": 0.02}` |
| 2 | `guild_artifact_golden_scale` | artifact | 3 | `{"gold_reward_multiplier": 0.03}` |
| 3 | `guild_artifact_honor_horn` | artifact | 4 | `{"recruit_high_tier_chance": 0.02}` |
| 4 | `guild_artifact_guardian_emblem` | artifact | 5 | `{"injury_rate_modifier": -0.07}` |

**용병단 장비 규칙:**
- `travel_event_bonus` 키는 M2a 미도입 (컨셉 기획서 taxonomy만 유지)
- 전설 규격(`legendary_effect` 필드) 용병단 장비에 적용 **금지** (M2a 범위 외)

## 톤/세계관 규칙

### 작명 톤 — 티어별 감성 계단 (initial_item_set 확정)

| 티어 | 작명 톤 | 예시 방향 |
|:---:|---|---|
| T2 | 평범한 한국어 | "철 투구", "강철 장검" |
| T3 | 한국어 + 형용사 / 외래어 | "단련된 강철 장검", "질풍의 가죽 부츠" |
| T4 | 판타지 외래어 / 한국어 강화형 | "룬 각인 흉갑", "맹염 단검" |
| T5 일반 | 강렬한 고유명사 | "수호자의 방패 장식" 등 |
| T5 전설 | 한자·고대어·신화 자유 혼합 | "멸혼결(滅魂結)", "광란검(狂瀾劍)", "이그드라실의 수피갑" |

**T5 전설 운용:**
- 한자 고집 해제. 강렬함·개성·고유명사성만 확보
- 한자 병기(멸혼결(滅魂結)) `name` 필드 허용
- 원칙적으로 `name`은 한국어 단독, 전설 한정 한자 병기 예외

### flavor_text 톤 규칙

- 1~2문장, 약 60자 이내
- 아이템의 **출처·분위기**를 간략히. 효과 설명 금지 (`effect_json`이 담당)
- 개인 장비: "장비의 현실적 출처 + 간단한 감성"
- 용병단 장비: "거시 효과의 서사적 설명" (예: "황금 저울: 숙련된 회계관의 유물. 모든 거래에서 한 푼도 놓치지 않는다.")

### 저작권 금칙

- `Docs/idea_note.md`의 웹소설 레퍼런스(게임 속 바바리안으로 살아남기 / 메모라이즈 / 용마검전 / 특성 쌓는 김전사)의 **고유명사·인물·세계관** 차용 금지
- "용마검" 등 원작 고유명사 사용 금지. 장르적 감성만 추출

## 생성 수량 가이드라인

M2a 검증용 표준 세트: **10종**

| 카테고리 | 수량 | 슬롯 배분 |
|---|:---:|---|
| `personal_equipment` | **6** | weapon 1 / armor 1 / helmet 1 / boots 1 / accessory 2 |
| `guild_equipment` | **4** | banner 1 / artifact 3 |

**개인 장비 티어 분포 권장**: T2×1 / T3×2 / T4×2 / T5×1 (T5 1종 = 전설 1종)

**용병단 장비 티어 분포 고정**: T3×2 / T4×1 / T5×1

## 상호 참조

생성 전 다음을 Supabase MCP로 확인한다:

1. **`items` 테이블 존재 여부** — 없으면 중단하고 spec-writer 페이즈 4 선행 필요 안내
2. **`items` 테이블 중복 검증** — 동일 `id` 조합의 기존 항목 확인
3. **`data_versions` 테이블** — `items` 행 존재 여부

## CSV 출력 포맷

**헤더:**
```csv
id,name,description,flavor_text,category,slot,tier,effect_json
```

**예시 행 (개인 장비 + 용병단 장비 발췌):**
```csv
equip_weapon_steel_sword,강철 장검,weapon / STR +6,단련된 강철로 만든 표준형 장검. 베테랑 용병이 선호하는 균형감.,personal_equipment,weapon,3,"{""str"":6}"
equip_armor_chain_mail,사슬 흉갑,armor / VIT +6,촘촘히 엮은 사슬 고리가 치명타를 분산시킨다. 무게는 가볍지 않다.,personal_equipment,armor,3,"{""vit"":6}"
equip_helmet_iron_helm,철 투구,helmet / VIT +2,정형화된 철 투구. 화려하지 않지만 튼튼하다.,personal_equipment,helmet,2,"{""vit"":2}"
equip_boots_gale_leather,질풍의 가죽 부츠,boots / AGI +5,북방 순록 가죽으로 만든 부츠. 긴 행군에도 피로가 덜하다.,personal_equipment,boots,3,"{""agi"":5}"
equip_accessory_silver_ring,단련의 은반지,accessory / STR +6,은세공사의 정교한 세공. 손가락에 끼면 근육이 기억을 떠올린다.,personal_equipment,accessory,4,"{""str"":6}"
equip_accessory_soul_seal,"멸혼결(滅魂結)",accessory / VIT +11 + 전설 효과,옛 시대 어떤 전사가 자신의 혼을 끊어 만들었다 전해지는 부적. 목에 걸면 어떤 공포도 평정심이 된다.,personal_equipment,accessory,5,"{""vit"":11,""legendary_effect"":{""category"":""damage_resistance"",""injury_rate_modifier"":-0.10,""death_rate_modifier"":-0.05}}"
guild_banner_standard,용병단의 깃발,banner / 명성+5% 골드+2%,빛바랜 붉은 천. 수많은 전장을 함께 넘어온 용병단의 이름이 새겨져 있다.,guild_equipment,banner,3,"{""reputation_gain_modifier"":0.05,""gold_reward_multiplier"":0.02}"
guild_artifact_golden_scale,황금 저울,artifact / 골드+3%,숙련된 회계관의 유물. 용병단의 모든 거래에서 한 푼도 놓치지 않는다.,guild_equipment,artifact,3,"{""gold_reward_multiplier"":0.03}"
guild_artifact_honor_horn,명예의 뿔피리,artifact / 고티어 모집+2%p,이 피리 소리가 들리면 먼 곳의 용병들까지 고개를 돌린다.,guild_equipment,artifact,4,"{""recruit_high_tier_chance"":0.02}"
guild_artifact_guardian_emblem,수호자의 방패 장식,artifact / 부상률-7%,야영지 중앙에 걸어두는 장식용 방패. 옛 수호자의 문장이 새겨져 있다.,guild_equipment,artifact,5,"{""injury_rate_modifier"":-0.07}"
```

**주의:**
- JSONB 필드(`effect_json`)는 JSON 문자열로 직렬화하고 쌍따옴표를 `""`로 이스케이프
- 한국어 텍스트는 쌍따옴표로 감싸지 않되, 쉼표·한자 괄호 포함 시 감싼다
- `description`은 **DB NOT NULL**이므로 빈 값 금지. 권장 포맷 "{slot} / {주스탯 +N}"
- `legendary_effect`는 전설 1종(T5 1종)에만 존재. 다른 행에 포함하지 않음

## 자체 검증 체크리스트

생성 직후 다음을 확인한다:

### 공통
- [ ] 모든 `id`가 카테고리별 형식(`equip_*` / `guild_*`)을 따르는가
- [ ] 모든 `id`가 유일한가 (내부 중복 없음)
- [ ] 모든 `name`이 기존 `items`와 중복되지 않는가
- [ ] 모든 `description`이 채워져 있는가 (DB NOT NULL, "{slot} / {주스탯 +N}" 포맷 권장)
- [ ] `flavor_text`가 모든 행에 존재하고 1~2문장인가
- [ ] 저작권 금칙 준수 (웹소설 고유명사 미사용)

### 개인 장비 (`personal_equipment`)
- [ ] 슬롯 배분: weapon 1 / armor 1 / helmet 1 / boots 1 / accessory 2
- [ ] 티어 분포: T2×1 / T3×2 / T4×2 / T5×1 (T5 1종 = 전설)
- [ ] 각 slot의 허용 `stat_key`만 사용 (armor/helmet은 vit 고정, boots는 agi 고정, weapon은 str|intelligence, accessory는 4축 택 1)
- [ ] `effect_json`의 주스탯 값이 tier × slot 매트릭스와 일치
- [ ] 단일 주스탯 정책 — 복합 키 금지 (전설의 `legendary_effect` 제외)
- [ ] 전설 1종만 `legendary_effect` 필드 포함, 해당 값이 유니크 효과 풀 범위 내
- [ ] 전설의 주스탯 값은 T5 수치 × 1.2 적용된 값 (weapon/armor 18, helmet/boots 14, accessory 11)

### 용병단 장비 (`guild_equipment`)
- [ ] 슬롯 배분: banner 1 / artifact 3 (총 4종)
- [ ] 티어 분포: T3×2 / T4×1 / T5×1
- [ ] 개인 스탯 키(`str`/`intelligence`/`vit`/`agi`) 미포함
- [ ] 허용 키(`gold_reward_multiplier`/`recruit_high_tier_chance`/`injury_rate_modifier`/`reputation_gain_modifier`)만 사용
- [ ] 수치가 4종 고정 스펙과 일치
- [ ] 깃발(banner)만 복합 키. 나머지는 단일 키
- [ ] `legendary_effect` 필드 미사용
- [ ] `travel_event_bonus` 키 미사용

## 기획서에서 추출해야 할 항목

`--brief` 기획서를 읽을 때 다음을 확인한다:

1. **대상 카테고리** — 개인 장비만, 용병단 장비만, 또는 둘 다
2. **개인 장비 전설 후보 선택** — 멸혼결(accessory) / 광란검(weapon) / 이그드라실 수피갑(armor) 중 선택 (기본 권장: 멸혼결 A안)
3. **전설 `legendary_effect.category` 선택** — 5 카테고리 중 1종 (컨셉별 권장 매핑 참조)
4. **수치 확정 상태** — balance-designer 산출물이 기본 매트릭스인지, 조정 값이 있는지
5. **저작권 주의 문구** — 웹소설 레퍼런스 고유명사 금칙 재확인

**표준 `--brief` 경로 (M2a):**
- `Docs/content-design/[content]20260418_item_taxonomy.md` (분류 체계, 슬롯·카테고리 정책)
- `Docs/content-design/[content]20260418_initial_item_set.md` (10종 컨셉·명칭·서사)
- `Docs/balance-design/20260418_equipment_stats.md` (개인 장비 수치 매트릭스 + 전설 유니크 효과 풀)
- `Docs/balance-design/20260418_guild_equipment_macro.md` (용병단 장비 4종 고정 스펙)

4개 문서 모두 참조하여 슬롯·수치·효과 축·네이밍을 교차 확인한다.

## 특수 요구

### 전설 1종 — 컨셉 선택 분기

전설 후보 3안 중 1종 선택 시, 평이 5종 배치가 달라질 수 있음:

| 전설 후보 | 전설 slot | 평이 5종 조정 |
|:---:|:---:|---|
| A (멸혼결) | accessory | 변경 없음 (accessory 2 중 하나가 전설) |
| B (광란검) | weapon | 평이 5종에서 weapon 제외 (강철 장검 삭제), 다른 슬롯 재배분 |
| C (이그드라실 수피갑) | armor | 평이 5종에서 armor 제외 (사슬 흉갑 삭제), 다른 슬롯 재배분 |

**기본 권장**: A (멸혼결). 가장 단순하며 평이 5종을 그대로 유지.

### 전설 `legendary_effect.category` 선택 가이드

```
멸혼결 (accessory, "혼을 끊는 부적") 
  → damage_resistance (injury/death -) 또는 special (death_prevention 1회)

광란검 (weapon, "폭풍의 분노")
  → result_upgrade (성공→대성공 5%)

이그드라실 수피갑 (armor, "세계수 껍질, 자가 봉합")
  → damage_resistance (injury -0.15)
```

### 개인 스탯 키 금지 — 용병단 장비 검증

CSV 생성 후 `guild_equipment` 행의 `effect_json`에 `str`/`intelligence`/`vit`/`agi` 키가 없는지 반드시 재검증. 포함 시 taxonomy E1-b 정책 위반으로 해당 행 재생성.

### accessory 2종의 주스탯 분산

두 accessory의 `stat_key`를 **다르게** 두면 전술 폭이 확대됨 (예: acc1 `str`, acc2 `agi`). 기본 권장: 다른 `stat_key` 선택.

## 생성 후 안내 (사용자 확인용)

CSV 생성 후 다음을 요약 보고한다:

```
## 장비 10종 생성 완료

- 개인 장비 6종:
  - weapon 1 / armor 1 / helmet 1 / boots 1 / accessory 2
  - 티어 분포: T2 ×1 / T3 ×2 / T4 ×2 / T5 ×1 (전설)
  - 전설: {선택된 후보 이름} ({슬롯}, category={legendary_effect.category})
- 용병단 장비 4종:
  - banner 1 / artifact 3
  - 4종 고정 스펙 적용 완료
  - 개인 스탯 키 미포함 검증: 통과

- 저작권 검증: 웹소설 고유명사 미사용 확인
- 단일 주스탯 정책 준수: 통과 (전설 legendary_effect 제외)

검토 후 Supabase에 쓰시겠습니까? (y / 선택 행 / n)
```
