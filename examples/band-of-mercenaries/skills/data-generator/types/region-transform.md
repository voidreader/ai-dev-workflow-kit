# region-transform — 지역 변형 트리거 + 섹터 전용 퀘스트 풀

> M3 마일스톤에서 신규 생성되는 지역 변형 18개 트리거와 섹터 전용 퀘스트 풀 34행을 생성하는 타입.
> 두 단계의 data-generator 호출에 사용된다:
> 1. 페이즈 3-2: `region_discoveries` 18행 (`discovery_type='transform'`)
> 2. 페이즈 3-3: `quest_pools` 34행 (`sector_type IS NOT NULL`)
>
> 입력 기획서: `Docs/content-design/[content]20260423_region_transform.md`
> 입력 밸런스: `Docs/balance-design/[balance]20260424_sector_transform_quests.md` (페이즈 2-2)
> 선행 조건: `chain_quests` 24행 생성 완료 (페이즈 3-1)

## 선행 DDL

### DDL-A: `quest_pools.special_flags` 컬럼 추가

페이즈 3-3 실행 전 Supabase MCP `apply_migration`으로 컬럼 추가:

```sql
ALTER TABLE quest_pools ADD COLUMN IF NOT EXISTS special_flags JSONB NULL DEFAULT '{}'::jsonb;

-- data_versions bump (기존 quest_pools 엔트리 version +1)
UPDATE data_versions SET version = version + 1 WHERE table_name = 'quest_pools';
```

### DDL-B: `region_discoveries` 확장 (기존 테이블, 추가 DDL 불필요)

`discovery_type='transform'`은 기존 CHECK 제약에 이미 허용되어 있거나(현 스키마 검증 필요), 문자열이므로 추가 DDL 없이 사용 가능.

```sql
-- 생성 전 CHECK 제약 확인
SELECT pg_get_constraintdef(oid) FROM pg_constraint
  WHERE conname LIKE '%region_discoveries%' AND contype='c';
```

만약 `discovery_type`이 enum 또는 CHECK로 `'transform'`이 허용되지 않는다면:
```sql
ALTER TABLE region_discoveries DROP CONSTRAINT region_discoveries_discovery_type_check;
ALTER TABLE region_discoveries ADD CONSTRAINT region_discoveries_discovery_type_check
  CHECK (discovery_type IN ('faction_clue','hidden_quest','transform','lore','item'));
```

---

## 대상 테이블

1. **`region_discoveries`** — 기존 테이블. `discovery_type='transform'` 행 18개 INSERT (페이즈 3-2)
2. **`quest_pools`** — 기존 테이블. `sector_type` 값 있는 행 34개 INSERT (페이즈 3-3)

---

## 대상 1: `region_discoveries` 18행 (페이즈 3-2)

### 스키마 (기존)

| 컬럼 | 타입 | 값 |
|---|---|---|
| `id` | TEXT PK | `rdsc_transform_{region_slug}_{type}` (예: `rdsc_transform_north_plains_village`) |
| `region_id` | INT FK | `regions.id` 실존 |
| `knowledge_threshold` | INT | **98** (일괄, 단 체인 5/6 연관 리전 2~3행은 88/83 조정) |
| `discovery_type` | TEXT | `'transform'` |
| `discovery_data` | JSONB | 아래 구조 |
| `description` | TEXT | 예고문 (1문장, 20~50자) |

### `discovery_data` JSONB 구조

```json
{
  "transform_type": "village" | "ruins" | "hidden",
  "sector_index": 0,                      // 0~9 사이 정수
  "transformed_name": "개척 마을",         // 한국어, UI 표시
  "narrative_template": "{region.name}에 변화의 기운이 감돌았다. 용병단의 흔적을 따라 개척민들이 정착했다. {merc.name}이 그 첫 손님을 맞이한다."
}
```

### 18개 변형 대상 리전 선정 기준

기획서 §2 테마 매칭 준수. 생성 전 필수 쿼리:

```sql
-- 각 유형별 후보 리전 조회
SELECT id, region_name, region_tier, environment_tags
FROM regions
WHERE
  -- village 후보: plains/coast/forest
  (environment_tags ?| array['plains','coast','forest'])
  -- ruins/mountain/underground 제외 (village 선정 대상)
ORDER BY region_tier, id
LIMIT 20;
```

- **village 6개**: T1×2 + T2×2 + T3×2 (환경 plains/coast/forest에서 선정)
- **ruins 6개**: T2×1 + T3×1 + T4×2 + T5×2 (환경 ruins/underground/mountain)
- **hidden 6개**: T2×1 + T3×2 + T4×2 + T5×1 (환경 swamp/desert/forest/underground)

**리전 선정 후 data-generator는 사용자 승인 요청**:
```
18개 리전 후보를 아래와 같이 선정했습니다:
- village:
  - region_id=12 ({region_name}) / T1 / plains / → "개척 마을"
  - ...
- 동일 유형 내에서 중복 region_id 없음
- 체인 5/6 연관 리전 확인: {chain_5_regions}, {chain_6_region}
사용자 확인하시겠습니까? (y / 수정)
```

### 체인 5/6 knowledge_threshold 조정 (balance 2-1)

- **체인 5(`chain_merchant_ledger`) 연관 리전**: step 2/3/4의 region_id 중 변형 대상과 겹치는 **최대 1개 리전**에 `knowledge_threshold=88` (체인 완주 시 +10 보너스로 98 도달)
- **체인 6(`chain_forge_masters`) 연관 리전**: step 1 region_id와 겹치는 **1개 리전**에 `knowledge_threshold=83` (체인 완주 시 +15 보너스로 98 도달)
- 나머지 16~17개 리전은 `knowledge_threshold=98` 일괄

### `sector_index` 선정 가이드

리전 내 섹터 0~9 중 자연스러운 위치:
- village: 섹터 3~6 (중앙)
- ruins: 섹터 0~2 또는 7~9 (구석/외곽)
- hidden: 섹터 5~8 (중후방)

### `transformed_name` 고정 제안 (§2 표)

| transform_type | 환경 | 이름 후보 |
|---|---|---|
| village | plains | 개척 마을 / 대상 중계지 |
| village | coast | 어촌 정착지 / 국경 항구 |
| village | forest | 목재상 마을 / 사냥꾼 촌 |
| village | ruins | 재건 정착지 |
| ruins | forest | 잊힌 사당 |
| ruins | ruins | 깨어난 성채 / 부활한 유적 |
| ruins | mountain | 고대 동굴 도시 / 금단의 성좌 |
| ruins | underground | 심연의 제단 |
| hidden | swamp | 안개의 길 |
| hidden | forest | 은둔자의 오두막 |
| hidden | ruins | 비밀 지하실 |
| hidden | desert | 사라진 오아시스 |
| hidden | underground | 망각의 서고 |
| hidden | mountain | 별이 떨어진 자리 |

**18개 모두 서로 다른 이름**. 중복 발생 시 수식어 추가(예: "북부 개척 마을") 또는 data-generator 재시도.

### `narrative_template` 생성 규칙

- 1~2문장, 60~120자
- `{region.name}` 최소 1회, `{merc.name}` 최소 1회 사용
- TemplateEngine 변수만 사용 (현재 문법으로 렌더 가능한 것만)
- 톤: "변화가 남긴 흔적" 감성 — 과장 금지, 담담한 서술
- **예시**:
  - village: "{region.name}에 변화의 기운이 감돌았다. 용병단의 흔적을 따라 개척민들이 정착했다. {merc.name}이 그 첫 손님을 맞이한다."
  - ruins: "안개가 걷히자 {region.name}의 옛 사당이 모습을 드러냈다. {merc.name}은 입구의 무늬를 한참 바라봤다."
  - hidden: "{region.name}의 바닥 아래에 또 다른 공간이 있었다. {merc.name}이 조심스레 등불을 들었다."

### `description` 필드

짧은 예고문. 팝업 제목·시스템 로그용. 예:
- "이 지역에 깊은 변화의 기운이 감돈다"
- "조사의 끝자락에서 새로운 땅이 열린다"
- 15~40자 문어체

---

### CSV 출력 포맷 (region_discoveries)

**헤더**:
```csv
id,region_id,knowledge_threshold,discovery_type,discovery_data,description
```

**예시 행**:
```csv
rdsc_transform_12_village,12,98,transform,"{""transform_type"":""village"",""sector_index"":4,""transformed_name"":""개척 마을"",""narrative_template"":""{region.name}에 변화의 기운이 감돌았다. 용병단의 흔적을 따라 개척민들이 정착했다. {merc.name}이 그 첫 손님을 맞이한다.""}","이 지역에 깊은 변화의 기운이 감돈다"
```

**주의**:
- `discovery_data`는 JSONB 문자열, CSV에서 쌍따옴표 이스케이프
- `narrative_template` 내부의 `{region.name}`/`{merc.name}`은 literal 그대로 저장 (런타임 치환)
- `id`는 `rdsc_transform_{region_id}_{type}` 형식 (region_slug 대신 region_id 사용 권장)

---

## 대상 2: `quest_pools` 섹터 전용 34행 (페이즈 3-3)

### 스키마 (기존 + `special_flags` 신규)

| 컬럼 | 타입 | 값 |
|---|---|---|
| `id` | TEXT PK | `qp_sector_{type}_{seq:02d}` (예: `qp_sector_village_01`) |
| `name` | TEXT | 한국어 3~8자 |
| `type` | REAL (deprecated) | **0** 고정 (legacy 필드) |
| `difficulty` | REAL | **D1~D5 스케일 (1.0~5.0)** — `difficulties.level`과 정합 |
| `min_region_diff` | REAL | 1~10 (기존 리전 티어 스케일) |
| `max_region_diff` | REAL | 1~10 |
| `type_id` | TEXT FK | `quest_types.id` (raid/hunt/escort/explore/labor) |
| `faction_tag` | TEXT | **NULL** (섹터 전용 풀은 세력 태그 없음) |
| `is_faction_exclusive` | BOOLEAN | **false** |
| `min_reputation` | INT | **0** |
| `sector_type` | TEXT | `'village'` / `'ruins'` / `'hidden'` |
| `special_flags` | JSONB | 기본 `'{}'::jsonb` — 일부 행만 값 |

**중요**: `difficulty` 필드는 **1~5 정수값을 real로** 입력한다. 기존 200행 일반 풀은 1~10 스케일 이슈가 있으나(페이즈 3-6 대응), 본 34행은 **D1~D5 스케일 강제** (balance 2-2 P4/Q-F).

---

### 유형별 분포 (balance 2-2 §5 확정)

#### Village (12행)

| type_id | 개수 | difficulty 분포 |
|---|---|---|
| escort | 4 | D2×3 / D3×1 |
| explore | 3 | D2×2 / D3×1 |
| labor | 3 | D2×2 / D3×1 |
| raid | 1 | D3 |
| hunt | 1 | D3 |

**총 D2:7 / D3:5**

**min_region_diff / max_region_diff**: 일괄 `1` / `10` (전 리전 허용 — 실 생성은 변형된 village 섹터에서만)

**`special_flags`**: 전체 12행 `{}` (플래그 없음 — 안정 소득 정체성)

#### Ruins (12행)

| type_id | 개수 | difficulty 분포 |
|---|---|---|
| hunt | 5 | D4×2 / D5×3 |
| explore | 4 | D4×3 / D5×1 |
| raid | 3 | D4×1 / D5×2 |

**총 D4:6 / D5:6**

**`min_region_diff`**: 3 / **`max_region_diff`**: 10

**`special_flags`** — 12행 중 4행 플래그 배정:

| id 예시 | 플래그 키 | 값 |
|---|---|---|
| `qp_sector_ruins_03` (explore D4, "유적 심층 진입") | `essence_drop_bonus` | `{"essence_tier": 3, "drop_rate": 0.08, "quantity": [1,2]}` |
| `qp_sector_ruins_05` (hunt D5, "잠든 수호 기계 파괴") | `equipment_drop_bonus` | `{"category": "personal_equipment", "tier_range": [3,4], "drop_rate": 0.05}` |
| `qp_sector_ruins_08` (hunt D5, "부활한 경비병 토벌") | `essence_drop_bonus` | `{"essence_tier": 4, "drop_rate": 0.12, "quantity": [1,1]}` |
| `qp_sector_ruins_11` (raid D4, "은닉된 보물실 약탈") | `guild_drop_ultra_rare` | `{"item_id": "guild_artifact_guardian_emblem", "drop_rate": 0.01}` |

#### Hidden (10행)

| type_id | 개수 | difficulty 분포 |
|---|---|---|
| explore | 6 | D3×2 / D4×3 / D5×1 |
| hunt | 2 | D4×1 / D5×1 |
| escort | 1 | D3 |
| raid | 1 | D4 |

**총 D3:3 / D4:5 / D5:2**

**`min_region_diff`**: 2 / **`max_region_diff`**: 10

**`special_flags`** — 10행 중 7행 플래그 배정 (balance 2-2 §5-4):

| id 예시 | 플래그 키 | 값 |
|---|---|---|
| `qp_sector_hidden_01` (explore D3, "은둔자의 가르침") | `trait_learning_boost` | `{"multiplier": 1.5, "duration_hours": 24}` |
| `qp_sector_hidden_02` (explore D5, "별의 조각 채집") | `trait_learning_boost` | `{"multiplier": 1.5, "duration_hours": 24}` |
| `qp_sector_hidden_03` (explore D4, "망각의 의식 관람") | `trait_learning_boost` | `{"multiplier": 1.5, "duration_hours": 24}` |
| `qp_sector_hidden_04` (explore D4, "기억의 파편 회수") | `guild_drop_rare` | `{"item_id": "guild_banner_standard", "drop_rate": 0.03}` |
| `qp_sector_hidden_05` (explore D4, "망각의 서고 탐사") | `guild_drop_rare` | `{"item_id": "guild_artifact_honor_horn", "drop_rate": 0.02}` |
| `qp_sector_hidden_06` (explore D5, "별이 떨어진 자리") | `guild_drop_rare` | `{"item_id": "guild_artifact_guardian_emblem", "drop_rate": 0.01}` |
| `qp_sector_hidden_07` (hunt D4, "금기된 의식 중단") | `reputation_penalty` | `{"amount": -5}` |
| `qp_sector_hidden_08~10` | `{}` (일반 3행) | - |

---

### `name` 생성 규칙

한국어 3~8자. 기획서 §4-2 + balance 2-2 §5-4 예시 참조. 34행 모두 유일.

**유형별 어투**:
- village: 일상·생활 ("장터 호위", "식량 수급", "도둑고양이 소탕", "좌판 설치")
- ruins: 유적·기계 ("수호 기계", "유적 심층", "부활한 경비병", "보물실")
- hidden: 신비·감추어진 ("은둔자의 가르침", "망각의 서고", "별의 조각", "금기된 의식")

---

### 검증 체크리스트

#### region_discoveries (18행)

- [ ] 총 행 수 = 18
- [ ] `discovery_type='transform'` 전 행
- [ ] `transform_type` 분포: village 6 / ruins 6 / hidden 6
- [ ] `knowledge_threshold` 값: 일반 16~17행 = 98 / 체인 5 연관 1행 = 88 / 체인 6 연관 1행 = 83
- [ ] 모든 `region_id`가 `regions` 테이블 실존
- [ ] 동일 `region_id`에 `transform` 행 중복 없음 (리전당 1변형)
- [ ] `sector_index` 0~9 범위
- [ ] `transformed_name` 18개 유일
- [ ] `narrative_template`에 `{region.name}` 및 `{merc.name}` 각 1회 이상
- [ ] environment_tag와 transform_type 매칭 (기획서 §2 원칙)

#### quest_pools sector (34행)

- [ ] 총 행 수 = 34 (village 12 + ruins 12 + hidden 10)
- [ ] `sector_type` 값 3종만 등장, 분포 12/12/10
- [ ] `difficulty` 모든 행 1.0~5.0 범위 (D1~D5 스케일 정합)
- [ ] `type_id`가 `quest_types.id` 실존 (raid/hunt/escort/explore/labor)
- [ ] `is_faction_exclusive=false` 전 행
- [ ] `faction_tag IS NULL` 전 행
- [ ] `min_reputation=0` 전 행
- [ ] village 유형 분포: escort 4/explore 3/labor 3/raid 1/hunt 1
- [ ] village 난이도 분포: D2×7, D3×5
- [ ] ruins 유형 분포: hunt 5/explore 4/raid 3
- [ ] ruins 난이도 분포: D4×6, D5×6
- [ ] hidden 유형 분포: explore 6/hunt 2/escort 1/raid 1
- [ ] hidden 난이도 분포: D3×3, D4×5, D5×2
- [ ] `special_flags` 배정:
  - village: 전 12행 `{}`
  - ruins: 4행 플래그 / 8행 `{}`
  - hidden: 7행 플래그 / 3행 `{}`
- [ ] `special_flags` 키 제한: `trait_learning_boost`, `guild_drop_rare`, `guild_drop_ultra_rare`, `essence_drop_bonus`, `equipment_drop_bonus`, `reputation_penalty` 외 금지
- [ ] `guild_drop_rare`의 `item_id` M2a `guild_*` 3종 실존: `guild_banner_standard` / `guild_artifact_honor_horn` / `guild_artifact_guardian_emblem`
- [ ] `essence_drop_bonus`·`equipment_drop_bonus`의 tier_range가 유효

---

### CSV 출력 포맷

**region_discoveries**: 위 §대상 1 참조

**quest_pools** 헤더:
```csv
id,name,type,difficulty,min_region_diff,max_region_diff,type_id,faction_tag,is_faction_exclusive,min_reputation,sector_type,special_flags
```

**예시 행** (village labor D2):
```csv
qp_sector_village_07,좌판 설치,0,2.0,1,10,labor,,false,0,village,{}
```

**예시 행** (hidden trait_learning_boost):
```csv
qp_sector_hidden_01,은둔자의 가르침,0,3.0,2,10,explore,,false,0,hidden,"{""trait_learning_boost"":{""multiplier"":1.5,""duration_hours"":24}}"
```

---

## 생성 순서

**data-generator는 두 단계 분리 실행 권장**:

1. 페이즈 3-2: `region_discoveries` 18행 (CSV: `[region-transform]20260424_m3-triggers.csv`)
2. 페이즈 3-3: `quest_pools` sector 34행 (CSV: `[region-transform]20260424_m3-sector-pools.csv`)

CSV 출력 후 사용자 승인 → Supabase INSERT.

---

## 생성 후 안내 포맷

```
## region-transform 생성 완료

### region_discoveries (페이즈 3-2)
- 총 행 수: 18
- 분포: village 6 / ruins 6 / hidden 6
- 체인 연관 조정: 체인 5 연관 리전 1개 knowledge_threshold=88, 체인 6 연관 1개 =83
- 선정된 리전 ID: [목록]

### quest_pools sector (페이즈 3-3)
- 총 행 수: 34
- 분포: village 12 / ruins 12 / hidden 10
- special_flags 배정: 12행 (ruins 4 + hidden 7 + reputation_penalty 1)
- DDL 선행 확인: quest_pools.special_flags 컬럼 존재

검증 결과:
- region_discoveries 체크리스트: 통과/실패
- quest_pools sector 체크리스트: 통과/실패

Supabase에 쓰시겠습니까?
```
