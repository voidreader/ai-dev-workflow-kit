# elite-monster — 엘리트 몬스터 + 드랍 테이블

> M2b 마일스톤에서 신규 생성되는 엘리트 몬스터 39종(보통 31 + 유니크 8)과 그 드랍 테이블 200~270행을 생성하는 타입.
> 두 개의 신규 테이블(`elite_monsters`, `elite_loot_tables`)을 커버하며, 페이즈 3 아이템 4(몬스터 39행)와 아이템 5(드랍 200~270행) 두 번의 data-generator 호출에 사용된다.

## 대상 테이블 (2종)

1. **`elite_monsters`** — 신규. 39행 (보통 31 + 유니크 8)
2. **`elite_loot_tables`** — 신규. 200~270행

**전제 조건:**
- M2a `items` 테이블 존재 확인 (정수 20종 + 개인 장비 6종 + 용병단 장비 4종)
- 호출 전 Supabase MCP로 `items` 테이블 실재 검증. 없으면 중단
- `elite_loot_tables` 생성은 `elite_monsters` 39행 생성 후 실행 (elite_id FK 참조)

---

## 대상 1: `elite_monsters` — 39행 생성

### 스키마

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | TEXT PK | ✅ | 형식: `elite_{family}_{variant}` (보통) / `elite_{family}_{name}` (유니크) |
| `name` | TEXT | ✅ | 한국어 이름. 아래 고정 목록 준수 |
| `description` | TEXT | ✅ | 보통 2~3문장 / 유니크 3~5문장 (생성 대상) |
| `is_unique` | BOOLEAN | ✅ | 유니크 8종만 `true` |
| `type_family` | TEXT | ✅ | 10개 고정값 + `unique_transcendent` |
| `tier` | INTEGER | ✅ | 2~5. 아래 고정 목록 준수 |
| `power` | INTEGER | ✅ | 아래 확정 수치표 준수 |
| `spawn_rate` | REAL | ✅ | 0.0~1.0. 아래 확정 수치표 준수 |
| `duration_multiplier` | REAL | ✅ | 아래 확정 수치표 준수 |
| `environment_tags` | JSONB | ✅ | 1~3개 배열. 8개 태그 enum 준수 |
| `stat_weight` | JSONB | ✅ | 합계 1.0. `{str, int, vit, agi}` 키. 아래 매핑 준수 |
| `fixed_region_environments` | JSONB | △ | 유니크 전용. 고정 리전 환경 태그 배열 |
| `lore` | TEXT | △ | 유니크 전용. 4~5문장 서사 (생성 대상) |
| `title` | TEXT | △ | 유니크 전용. 예: "북부 숲의 왕" (생성 가이드 참조) |

### `type_family` 허용값

`golem` / `orc` / `goblin` / `troll` / `lizardman` / `undead` / `elemental` / `beast` / `insect` / `demon` / `unique_transcendent`

### `environment_tags` 허용값 (8종)

`ruins` / `forest` / `swamp` / `mountain` / `desert` / `coast` / `underground` / `plains`

---

### 보통 엘리트 31종 — 고정 목록

**이름, 수치는 고정. `description`만 data-generator가 생성한다.**

| id | name | type_family | tier | power | spawn_rate | duration_mult | environment_tags | stat_weight |
|----|------|-------------|------|-------|-----------|---------------|-----------------|-------------|
| `elite_golem_rusty` | 녹슨 골렘 | golem | 2 | 105 | 0.15 | 1.5 | `[ruins,underground,mountain]` | `{str:0.4,vit:0.4,int:0.1,agi:0.1}` |
| `elite_golem_brass` | 황동 골렘 | golem | 3 | 145 | 0.12 | 1.6 | `[ruins,underground]` | `{str:0.4,vit:0.4,int:0.1,agi:0.1}` |
| `elite_golem_bronze` | 청동 골렘 | golem | 4 | 195 | 0.08 | 1.8 | `[ruins,mountain]` | `{str:0.4,vit:0.4,int:0.1,agi:0.1}` |
| `elite_golem_crystal` | 수정 골렘 | golem | 4 | 195 | 0.08 | 1.8 | `[ruins,underground]` | `{int:0.5,str:0.3,vit:0.1,agi:0.1}` |
| `elite_orc_warrior` | 오크 대전사 | orc | 2 | 100 | 0.15 | 1.5 | `[forest,mountain,plains]` | `{str:0.5,int:0.3,vit:0.1,agi:0.1}` |
| `elite_orc_shaman` | 오크 주술사 | orc | 3 | 140 | 0.12 | 1.6 | `[forest,plains]` | `{str:0.5,int:0.3,vit:0.1,agi:0.1}` |
| `elite_orc_chief` | 오크 족장 | orc | 4 | 190 | 0.08 | 1.8 | `[mountain,plains]` | `{str:0.5,int:0.3,vit:0.1,agi:0.1}` |
| `elite_goblin_raider` | 고블린 습격자 | goblin | 2 | 90 | 0.15 | 1.5 | `[forest,underground,mountain]` | `{agi:0.4,int:0.3,str:0.2,vit:0.1}` |
| `elite_goblin_shaman` | 고블린 주술사 | goblin | 3 | 130 | 0.12 | 1.6 | `[forest,underground]` | `{agi:0.4,int:0.3,str:0.2,vit:0.1}` |
| `elite_goblin_hobchief` | 홉고블린 대장 | goblin | 4 | 180 | 0.08 | 1.8 | `[mountain,underground]` | `{agi:0.4,int:0.3,str:0.2,vit:0.1}` |
| `elite_troll_swamp` | 늪지 트롤 | troll | 3 | 145 | 0.12 | 1.6 | `[swamp,forest]` | `{vit:0.4,str:0.4,int:0.1,agi:0.1}` |
| `elite_troll_mountain` | 산악 트롤 | troll | 4 | 195 | 0.08 | 1.8 | `[mountain]` | `{vit:0.4,str:0.4,int:0.1,agi:0.1}` |
| `elite_lizard_swamp` | 늪지 리자드 | lizardman | 2 | 100 | 0.15 | 1.5 | `[swamp]` | `{agi:0.4,str:0.3,vit:0.2,int:0.1}` |
| `elite_lizard_desert` | 모래도마뱀 전사 | lizardman | 3 | 140 | 0.12 | 1.6 | `[desert]` | `{agi:0.4,str:0.3,vit:0.2,int:0.1}` |
| `elite_lizard_coast` | 바다뱀 사령관 | lizardman | 4 | 190 | 0.08 | 1.8 | `[coast]` | `{agi:0.4,str:0.3,vit:0.2,int:0.1}` |
| `elite_undead_skeleton` | 방랑 스켈레톤 | undead | 2 | 90 | 0.15 | 1.5 | `[ruins,plains]` | `{int:0.4,agi:0.3,str:0.2,vit:0.1}` |
| `elite_undead_bonemage` | 뼈 주술사 | undead | 3 | 130 | 0.12 | 1.6 | `[ruins,swamp]` | `{int:0.4,agi:0.3,str:0.2,vit:0.1}` |
| `elite_undead_ghoul` | 굶주린 구울 | undead | 3 | 130 | 0.12 | 1.6 | `[swamp,underground]` | `{int:0.4,agi:0.3,str:0.2,vit:0.1}` |
| `elite_undead_knight` | 망령 기사 | undead | 4 | 180 | 0.08 | 1.8 | `[ruins]` | `{int:0.4,agi:0.3,str:0.2,vit:0.1}` |
| `elite_elemental_fire` | 화염 정령 | elemental | 3 | 125 | 0.12 | 1.6 | `[desert,ruins]` | `{int:0.6,str:0.2,vit:0.1,agi:0.1}` |
| `elite_elemental_water` | 물의 정령 | elemental | 3 | 125 | 0.12 | 1.6 | `[coast,swamp]` | `{int:0.6,agi:0.2,vit:0.1,str:0.1}` |
| `elite_elemental_earth` | 대지의 정령 | elemental | 3 | 125 | 0.12 | 1.6 | `[mountain,underground]` | `{int:0.6,vit:0.2,str:0.1,agi:0.1}` |
| `elite_elemental_wind` | 바람 정령 | elemental | 4 | 175 | 0.08 | 1.8 | `[mountain,plains]` | `{int:0.6,agi:0.2,vit:0.1,str:0.1}` |
| `elite_beast_wolf` | 서리 늑대 | beast | 2 | 95 | 0.15 | 1.5 | `[forest,mountain]` | `{str:0.4,agi:0.4,vit:0.1,int:0.1}` |
| `elite_beast_bear` | 거대 곰 | beast | 3 | 135 | 0.12 | 1.6 | `[forest,plains]` | `{str:0.4,agi:0.4,vit:0.1,int:0.1}` |
| `elite_beast_tiger` | 검치호 | beast | 4 | 185 | 0.08 | 1.8 | `[forest,mountain]` | `{str:0.4,agi:0.4,vit:0.1,int:0.1}` |
| `elite_insect_spider` | 거대 독거미 | insect | 2 | 90 | 0.15 | 1.5 | `[forest,underground]` | `{agi:0.4,int:0.3,vit:0.2,str:0.1}` |
| `elite_insect_beetle` | 뿔벌레 전사 | insect | 3 | 130 | 0.12 | 1.6 | `[swamp,underground]` | `{agi:0.4,int:0.3,vit:0.2,str:0.1}` |
| `elite_insect_scorpion` | 여왕 전갈 | insect | 4 | 180 | 0.08 | 1.8 | `[desert,underground]` | `{agi:0.4,int:0.3,vit:0.2,str:0.1}` |
| `elite_demon_imp` | 작은 임프 | demon | 3 | 125 | 0.12 | 1.6 | `[ruins,swamp]` | `{int:0.5,str:0.3,vit:0.1,agi:0.1}` |
| `elite_demon_barbarian` | 심연의 바바리언 | demon | 4 | 175 | 0.08 | 1.8 | `[ruins,underground]` | `{int:0.5,str:0.3,vit:0.1,agi:0.1}` |

> **주의**: 위 목록은 7종 T2 / 13종 T3 / 11종 T4. 기획서 §3.3 분포 목표(T2×8/T4×10)와 ±1 차이 — 원본 기획서 내 소수 불일치. 이름 목록을 우선하며, 총 31종 준수.

---

### 유니크 엘리트 8종 — 고정 목록

**이름·수치·서사 방향 고정. `description`(3~5문장), `lore`(4~5문장)만 data-generator가 생성한다.**

| id | name | type_family | tier | power | spawn_rate | duration_mult | environment_tags | fixed_region_environments | title |
|----|------|-------------|------|-------|-----------|---------------|-----------------|--------------------------|-------|
| `elite_wolf_ulbur` | 늑대왕 울부르 | beast | 2 | 120 | 0.08 | 1.7 | `[forest,mountain]` | `[forest,mountain]` | 북부 숲의 왕 |
| `elite_golem_steel` | 강철 골렘 | golem | 3 | 170 | 0.07 | 1.8 | `[ruins,underground]` | `[ruins,underground]` | 폐광 최심부의 불사 수호자 |
| `elite_hydra_swamp` | 습지의 히드라 | lizardman | 3 | 165 | 0.07 | 1.8 | `[swamp]` | `[swamp]` | 검은 늪의 세 머리 독룡 |
| `elite_skeleton_general` | 백골의 장군 | undead | 3 | 155 | 0.07 | 1.8 | `[ruins,plains]` | `[ruins,plains]` | 잊혀진 왕국의 죽은 사령관 |
| `elite_guardian_desert` | 사막의 파수꾼 | unique_transcendent | 4 | 205 | 0.06 | 2.0 | `[desert,ruins]` | `[desert,ruins]` | 태양 아래 수천 년의 파수꾼 |
| `elite_witch_morgan` | 검은 마녀 모르간 | demon | 4 | 195 | 0.06 | 2.0 | `[forest,ruins]` | `[forest,ruins]` | 숲의 심부에서 저주를 엮는 마녀 |
| `elite_kraken_abyss` | 심해의 크라켄 | unique_transcendent | 4 | 210 | 0.06 | 2.0 | `[coast]` | `[coast]` | 해안 절벽 아래의 해양 군주 |
| `elite_lich_primordial` | 태고의 리치 | undead | 5 | 245 | 0.05 | 2.0 | `[ruins,underground]` | `[ruins,underground]` | 시간을 거스른 불사 마법사 |

> 유니크 `stat_weight`: 서사와 type_family를 반영하여 data-generator가 결정. 합계 1.0 필수.
> 태고의 리치: `{int:0.5, vit:0.3, str:0.1, agi:0.1}` 권장 (불사 마법사 특성).

---

### 보통 엘리트 description 톤 가이드

- **형식**: "수식어 + 종족명"이 이름에 반영됨. 설명은 출신·특징·공격 방식 암시.
- **길이**: 2~3문장, 약 80~120자 이내.
- **금기**: 브랜드명·실존 인물명. 과도한 잔혹 묘사.
- **예시** (녹슨 골렘): "오래된 지하 광산에서 살아남은 수호 자동인형. 녹슨 몸체 속에 아직 제작자의 명령이 새겨져 있다. 느리지만 압도적인 완력으로 침입자를 밀어붙인다."

### 유니크 엘리트 lore 톤 가이드

- **길이**: 4~5문장, 약 150~250자.
- **내용**: 탄생 배경 → 지역 지배 방식 → 용병단과의 역사적 관계 암시 → 처치 후 보상의 서사적 의미.
- **예시** (강철 골렘): "전설적인 연금술사 하들란이 폐광의 보물을 지키기 위해 제작했다고 전해지는 수호자. 하들란이 사라진 뒤에도 수백 년간 지하 깊은 곳을 지키고 있다. 용병 사이에서는 '불사의 철인'이라 불리며, 정면 돌파는 무리이고 빈틈을 노려야 한다. 토벌 후 잔해에서 수호의 방패 장식이 발견된다고 전해진다."

---

### CSV 출력 포맷 (elite_monsters)

**헤더:**
```csv
id,name,description,is_unique,type_family,tier,power,spawn_rate,duration_multiplier,environment_tags,stat_weight,fixed_region_environments,lore,title
```

**주의:**
- JSONB 필드(`environment_tags`, `stat_weight`, `fixed_region_environments`)는 JSON 문자열로 직렬화 (`""` 이스케이프)
- 보통 엘리트: `fixed_region_environments`, `lore`, `title` 칸을 비워 둠 (NULL)
- 유니크 엘리트: `fixed_region_environments`는 고정 목록 값 사용, `lore`·`title` 생성

---

## 대상 2: `elite_loot_tables` — 200~270행 생성

### 스키마

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | TEXT PK | ✅ | `elite_{family}_{variant}_{drop_type}_{nn}` 형식. nn은 01부터 순차 |
| `elite_id` | TEXT FK | ✅ | `elite_monsters.id` 참조 |
| `drop_type` | TEXT | ✅ | `gold` / `essence` / `personal_equipment` / `guild_artifact` |
| `item_id` | TEXT FK nullable | △ | `drop_type=gold`이면 NULL, 그 외 필수. `items.id` FK |
| `gold_min` | INTEGER nullable | △ | `drop_type=gold`일 때만 |
| `gold_max` | INTEGER nullable | △ | `drop_type=gold`일 때만. `gold_min ≤ gold_max` |
| `drop_rate` | REAL | ✅ | 0.0 초과 ~ 1.0 이하 |
| `rarity_grade` | TEXT | ✅ | `common` / `rare` / `epic` / `legendary` |
| `quantity` | INTEGER | ✅ | 기본 1 |

**제약:**
- `drop_type='gold'` → `item_id` IS NULL, `gold_min/max` NOT NULL
- `drop_type!='gold'` → `item_id` NOT NULL, `gold_min/max` IS NULL
- `drop_rate > 0.0` 필수 (0.0 행 생성 금지)

---

### 엘리트당 드랍 행 수 상한

| 구분 | 드랍 행 수 | 기대 Σ drop_rate |
|------|-----------|-----------------|
| 보통 엘리트 | **4~6행** | 1.55 ~ 2.00 |
| 유니크 엘리트 | **7~9행** | 2.80 ~ 3.60 |

**카테고리별 최대 행 수:**

| drop_type | 보통 엘리트 | 유니크 엘리트 |
|-----------|-----------|--------------|
| `gold` | 1행 | 2행 (기본 + 잭팟) |
| `essence` | 3행 | 4행 |
| `personal_equipment` | 2행 | 3행 |
| `guild_artifact` | 1행 (legendary, rate≤0.02) | 2행 |

**필수 행 (엘리트당 반드시 포함):**
- `gold` common 1행 (`drop_rate=1.00`) — 전 엘리트 필수
- `essence` 주 드랍축 1행 이상 — 전 엘리트 필수
- `guild_artifact` signature drop 1행 — **유니크 8종만** 필수

---

### drop_rate 범위 가이드

| drop_type | rarity_grade | 보통 엘리트 | 유니크 엘리트 |
|-----------|--------------|-----------|--------------|
| gold 기본 | common | **1.00** 고정 | **1.00** 고정 |
| gold 잭팟 | rare | — | T2: 0.10 / T3: 0.08 / T4: 0.06 / T5: 0.05 |
| essence 주축 | rare | **0.30 ~ 0.50** | **0.50 ~ 0.70** |
| essence 부축 | rare (보통) / epic (유니크) | **0.15 ~ 0.30** | **0.30 ~ 0.45** |
| essence 상위 티어 | epic (보통) / legendary (유니크) | **0.03 ~ 0.08** (3행 선택 시) | **0.05 ~ 0.15** |
| personal_equipment 동티어 | rare | **0.08 ~ 0.15** | **0.20 ~ 0.35** |
| personal_equipment 상위 티어 | epic | — | **0.10 ~ 0.20** |
| personal_equipment 전설 | legendary | — | **0.03 ~ 0.05** (2종 유니크 한정) |
| guild_artifact signature | rare (T2~T3) / epic (T4) / legendary (T5) | **0.005 ~ 0.02** (선택) | **아래 확정표 준수** |
| guild_artifact 보조 | rare | — | **0.04 ~ 0.06** |

---

### 골드 min/max 확정표

| 엘리트 티어 | 구분 | gold_min | gold_max |
|------------|------|---------|---------|
| T2 | 보통 기본 | 200 | 350 |
| T2 | 유니크 기본 | 300 | 500 |
| T2 | 유니크 잭팟 | 700 | 1200 |
| T3 | 보통 기본 | 300 | 550 |
| T3 | 유니크 기본 | 400 | 700 |
| T3 | 유니크 잭팟 | 1000 | 1700 |
| T4 | 보통 기본 | 450 | 800 |
| T4 | 유니크 기본 | 600 | 1100 |
| T4 | 유니크 잭팟 | 2000 | 3200 |
| T5 | 유니크 기본 | 1000 | 1800 |
| T5 | 유니크 잭팟 | 3000 | 5000 |

---

### Signature Drop 확정 매핑 (유니크 8종)

**이 매핑은 고정. data-generator는 반드시 준수한다.**

| elite_id | item_id | drop_rate | rarity_grade |
|----------|---------|-----------|--------------|
| `elite_wolf_ulbur` | `guild_banner_standard` | 0.15 | rare |
| `elite_golem_steel` | `guild_artifact_guardian_emblem` | 0.15 | rare |
| `elite_hydra_swamp` | `guild_artifact_golden_scale` | 0.12 | rare |
| `elite_skeleton_general` | `guild_artifact_honor_horn` | 0.12 | rare |
| `elite_guardian_desert` | `guild_artifact_guardian_emblem` | 0.10 | epic |
| `elite_witch_morgan` | `guild_artifact_golden_scale` | 0.12 | rare |
| `elite_kraken_abyss` | `guild_artifact_honor_horn` | 0.10 | epic |
| `elite_lich_primordial` | `guild_banner_standard` | 0.06 | legendary |
| `elite_lich_primordial` | `guild_artifact_guardian_emblem` | 0.06 | legendary |

> **주의**: item_id는 M2a 실제 생성된 ID와 다를 수 있음. 생성 전 Supabase `items` 테이블에서 banner·artifact ID를 조회하여 확인 후 대입.

---

### 정수 티어 허용 매트릭스

| 엘리트 티어 | 보통 엘리트 essence 허용 tier | 유니크 엘리트 essence 허용 tier |
|------------|----------------------------|-------------------------------|
| T2 | T1 (주) + T2 (부) | T1, T2, T3 |
| T3 | T1, T2 (주) + T3 (부) | T2, T3, T4 |
| T4 | T2, T3 (주) + T4 (부) | T3, T4, T5 |
| T5 | — (보통 없음) | T4, T5 |

### 개인 장비 티어 허용 매트릭스

| 엘리트 티어 | 보통 엘리트 | 유니크 엘리트 |
|------------|-----------|--------------|
| T2 | T2만 | T2, T3 |
| T3 | T2, T3 | T3, T4 |
| T4 | T3, T4 | T4, T5 |
| T5 | — | T5 |

---

### 타입 가족 → 정수 축 매핑

| 타입 가족 | 주 드랍 정수(essence_KEY) | 부 드랍 | 미드랍 |
|----------|--------------------------|---------|-------|
| golem, troll | `essence_str`, `essence_vit` | — | `essence_int`, `essence_agi` |
| orc | `essence_str`, `essence_int` | — | `essence_vit`, `essence_agi` |
| goblin, insect | `essence_agi`, `essence_int` | — | `essence_str`, `essence_vit` |
| lizardman | `essence_agi`, `essence_str` | — | `essence_int`, `essence_vit` |
| undead, demon | `essence_int`, `essence_agi` | — | `essence_str`, `essence_vit` |
| elemental | `essence_int` | 원소별 부축† | `essence_str`, `essence_vit` |
| beast | `essence_agi`, `essence_str` | — | `essence_int`, `essence_vit` |
| unique_transcendent | 서사 반영 자유 | — | — |

> **†정령 원소별 부축**: 화염→`essence_str` / 물·바람→`essence_agi` / 대지→`essence_vit`

**주 드랍 축은 반드시 1행 이상 포함. 미드랍 축은 절대 포함하지 않는다 (서사 일관성).**

### 타입 가족 → 개인 장비 슬롯 매핑

| 타입 가족 | 주 드랍 슬롯 | 미드랍 슬롯 |
|----------|-----------|-----------|
| golem, troll | armor, helmet | weapon, boots |
| orc | weapon | helmet |
| goblin | boots, accessory | armor, helmet |
| lizardman | weapon, armor | accessory |
| undead, demon | accessory | boots (낮음) |
| elemental | accessory | weapon, armor, helmet |
| beast | boots | weapon, armor |
| insect | accessory, boots | weapon, armor, helmet |
| unique_transcendent | 서사 반영 자유 | — |

---

### M2a item_id 참조 목록 (생성 전 Supabase에서 실재 확인)

**정수 (essence) — 20종, `essence_{stat}_{tn}` 형식:**
- `essence_str_t1` ~ `essence_str_t5`
- `essence_int_t1` ~ `essence_int_t5`
- `essence_vit_t1` ~ `essence_vit_t5`
- `essence_agi_t1` ~ `essence_agi_t5`

**개인 장비 — 6종 (아래 ID는 M2a 생성 기본 형식, 실제 ID 확인 필수):**
- weapon/T3: `equip_weapon_steel_sword`
- armor/T3: `equip_armor_chain_mail`
- helmet/T2: `equip_helmet_iron_helm`
- boots/T3: `equip_boots_gale_leather`
- accessory/T4: `equip_accessory_silver_ring`
- accessory/T5(전설): `equip_accessory_soul_seal` (또는 실제 생성된 전설 ID)

**용병단 장비 — 4종 (Signature Drop 대상, 실제 ID 확인 필수):**
- banner/T3: `guild_banner_standard`
- artifact/T3: `guild_artifact_golden_scale`
- artifact/T4: `guild_artifact_honor_horn`
- artifact/T5: `guild_artifact_guardian_emblem`

---

### CSV 출력 포맷 (elite_loot_tables)

**헤더:**
```csv
id,elite_id,drop_type,item_id,gold_min,gold_max,drop_rate,rarity_grade,quantity
```

**예시 행:**
```csv
elite_golem_rusty_gold_01,elite_golem_rusty,gold,,200,350,1.00,common,1
elite_golem_rusty_essence_01,elite_golem_rusty,essence,essence_str_t1,,, 0.40,rare,1
elite_golem_rusty_essence_02,elite_golem_rusty,essence,essence_vit_t1,,,0.22,rare,1
elite_golem_rusty_equipment_01,elite_golem_rusty,personal_equipment,equip_helmet_iron_helm,,,0.10,rare,1
elite_golem_rusty_equipment_02,elite_golem_rusty,personal_equipment,equip_armor_chain_mail,,,0.05,epic,1
```

**주의:**
- gold 행: `item_id`, `drop_rate` 이후 두 칸(gold_min, gold_max) 값 채우기. item_id 칸 비움
- non-gold 행: `item_id` 채우기. gold_min, gold_max 칸 비움
- `drop_rate` 소수점 2자리 (예: 0.40)

---

## 자체 검증 체크리스트

### elite_monsters (39행)

- [ ] 총 행 수 = 39 (보통 31 + 유니크 8)
- [ ] 모든 `id`가 유일한가
- [ ] 보통 31종 이름이 고정 목록과 일치하는가
- [ ] 유니크 8종 이름·tier·power·spawn_rate·duration_multiplier가 고정 목록과 일치하는가
- [ ] 모든 `environment_tags` 값이 8개 허용 태그 중에서만 선택되었는가
- [ ] 모든 `stat_weight` 합계가 1.0인가
- [ ] `is_unique=true`인 행이 정확히 8개인가
- [ ] 유니크 8종에 `lore`, `title`, `fixed_region_environments` 모두 채워졌는가
- [ ] 보통 31종에 `lore`, `title`, `fixed_region_environments`가 모두 NULL(비어있음)인가
- [ ] `type_family` 값이 허용 11개 중 하나인가

### elite_loot_tables (200~270행)

- [ ] 총 행 수 200~270 범위 내인가
- [ ] 모든 엘리트(39종)가 최소 1개 드랍 행을 가지는가
- [ ] 모든 엘리트에 `drop_type='gold'`, `rarity_grade='common'`, `drop_rate=1.00` 행이 1개 이상인가
- [ ] 모든 엘리트에 `drop_type='essence'` 행이 1개 이상인가
- [ ] 유니크 8종 각각에 signature `guild_artifact` 행이 있는가 (위 매핑 준수)
- [ ] 보통 엘리트 드랍 행 수 4~6행 범위인가
- [ ] 유니크 엘리트 드랍 행 수 7~9행 범위인가
- [ ] 보통 엘리트 Σ drop_rate: 1.55 ≤ 합계 ≤ 2.00인가
- [ ] 유니크 엘리트 Σ drop_rate: 2.80 ≤ 합계 ≤ 3.60인가
- [ ] 보통 essence Σ drop_rate: 0.55 ~ 0.90인가
- [ ] 유니크 essence Σ drop_rate: 1.00 ~ 1.65인가
- [ ] `drop_type='gold'` 행의 `item_id`가 NULL이고 `gold_min/max`가 설정되었는가
- [ ] `drop_type!='gold'` 행의 `item_id`가 NOT NULL이고 `gold_min/max`가 NULL인가
- [ ] `drop_rate > 0.0` 전 행 준수인가
- [ ] 정수 허용 티어 매트릭스 준수 (보통 T4 엘리트가 T5 정수를 드랍하지 않는가)
- [ ] 미드랍 축 정수가 포함되지 않았는가
- [ ] `guild_artifact` 행이 유니크 엘리트에서만 나타나거나, 보통 엘리트에서는 rate≤0.02·legendary인가
- [ ] `item_id` 참조 무결성: M2a `items` 테이블에 실재하는 ID인가 (Supabase MCP로 확인)

## 생성 후 안내

```
## 엘리트 몬스터 생성 완료

- elite_monsters: 39행 (보통 31 + 유니크 8)
  - T2 ×{N} / T3 ×{N} / T4 ×{N} / T5 ×1
- elite_loot_tables: {N}행
  - 보통 엘리트 평균 {N.N}행 / 유니크 평균 {N.N}행
  - signature drop 8종 매핑: 확인 완료

검증 결과:
- elite_monsters 체크리스트: 모두 통과 / N개 실패
- elite_loot_tables 체크리스트: 모두 통과 / N개 실패

Supabase에 쓰시겠습니까? (y / 수정 후 진행 / n)
```
