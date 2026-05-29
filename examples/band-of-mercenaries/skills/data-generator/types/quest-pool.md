# quest-pool — 일반 퀘스트 풀

> `quest_pools` 테이블에 허드렛일(is_fixed=false) 또는 고정 사건(is_fixed=true) 행을 추가할 때 사용한다.
> 세력 전용 퀘스트는 `faction-quest.md` 타입을 사용한다.

## 대상 테이블

**`quest_pools`** (Supabase)

## 스키마 필드

| 필드 | 타입 | NOT NULL | 기본값 | 설명 |
|------|------|----------|--------|------|
| `id` | text | ✅ | — | 고유 ID. 섹터·리전 접두사 규칙 준수 (아래 참조) |
| `name` | text | ✅ | — | 퀘스트 이름. 한국어. 15자 이내 권장 |
| `type` | real | ✅ | 0 | 레거시 필드. 항상 **0** 입력 |
| `type_id` | text | ✅ | — | 퀘스트 유형: escort / explore / hunt / labor / raid / survey |
| `difficulty` | real | ✅ | — | 난이도 1~5 |
| `min_region_diff` | real | ✅ | — | 최소 리전 차이 |
| `max_region_diff` | real | ✅ | — | 최대 리전 차이 |
| `is_faction_exclusive` | boolean | ✅ | false | 세력 전용 여부. 허드렛일은 항상 false |
| `min_reputation` | integer | ✅ | 0 | 최소 명성. 일반적으로 0 |
| `sector_type` | text | ❌ | null | village / dungeon / field / null |
| `enemy_name` | text | ❌ | null | 적 이름. hunt·raid는 필수, 나머지는 선택 |
| `is_fixed` | boolean | ✅ | — | true=고정 사건, false=허드렛일 |
| `fixed_chain_id` | text | ❌ | null | is_fixed=true 전용. chain_id (예: settlement_3_pyegwang_reopen) |
| `fixed_step` | integer | ❌ | null | is_fixed=true 전용. 단계 번호 |
| `trust_threshold` | integer | ❌ | null | is_fixed=true 전용. 노출 최소 신뢰도 단계 |
| `reward_gold_override` | integer | ❌ | null | 기본 골드 보상 오버라이드 |
| `reward_xp_bonus_override` | integer | ❌ | null | 추가 XP 오버라이드 |
| `duration_override_seconds` | integer | ❌ | null | 파견 시간 오버라이드 (초) |
| `trust_reward_override` | integer | ❌ | null | 마을 신뢰도 보상 오버라이드 |
| `min_trust_level` | integer | ✅ | 0 | 노출 최소 신뢰도 레벨. 허드렛일은 0 |
| `faction_tag` | text | ❌ | null | 세력 태그. 허드렛일은 null |
| `special_flags` | jsonb | ❌ | null | 특수 플래그. 일반적으로 null |

## ID 명명 규칙

### 허드렛일 (is_fixed=false)

```
qp_{region_abbr}_{sector_abbr}_{num}_{slug}
```

더스트빌(region 3) 기준:
- 마을(village, sector 1): `qp_dv_v{num}_{slug}`
- 폐광(dungeon, sector 2): `qp_dv_d{num}_{slug}`
- 마른 초원(field, sector 3): `qp_dv_f3_{slug}`
- 먼지로 덮인 길(field, sector 4): `qp_dv_r4_{slug}`

### 고정 사건 (is_fixed=true)

```
qp_{event_name}_step{N}
```

예: `qp_pyegwang_step1`

## 톤/세계관 규칙

### 이름 규칙

- 명사구 또는 동사구. "의뢰", "임무" 접미사 **붙이지 않는다**
- 15자 이내. 구체적 행동 중심 (예: "박쥐 쫓기", "잡석 정리")
- 영웅적 과장 없음. 허드렛일은 "마을 일손 부탁" 톤

### 더스트빌 세계관 키워드

먼지 · 산악 · 폐광 · 변방 · 박쥐 · 도굴꾼 · 약초 · 행상 · 들개 · 도적

### 인명 사용 시

마을 NPC 이름 우선: 파슨(촌장) / 하겐(대장장이) / 네리스(약초상) / 데얀(광부 노인)

## 수치 기준 (D1 허드렛일 기본값)

| 항목 | 값 |
|------|-----|
| difficulty | 1 |
| min_region_diff | 1 |
| max_region_diff | 1 |
| is_faction_exclusive | false |
| min_reputation | 0 |
| min_trust_level | 0 |
| type | 0 (레거시) |

> description 컬럼은 quest_pools에 존재하지 않는다. 퀘스트 설명 텍스트는 기획서에만 보존하고 DB에는 저장하지 않는다.

## 상호 참조

생성 전 다음을 Supabase MCP로 확인한다:

1. **`quest_types` 테이블**: `type_id` 값이 실존하는가 (escort/explore/hunt/labor/raid/survey)
2. **`quest_pools` 테이블**: 동일 `name` 기존 항목 존재 여부 (중복 방지)
3. **is_fixed=true 생성 시**: `fixed_chain_id`가 chain_quests에 실존하는가

## CSV 출력 포맷

**허드렛일 헤더:**
```csv
id,name,type,type_id,difficulty,min_region_diff,max_region_diff,is_faction_exclusive,min_reputation,sector_type,enemy_name,is_fixed,min_trust_level
```

**고정 사건 헤더 (추가 필드 포함):**
```csv
id,name,type,type_id,difficulty,min_region_diff,max_region_diff,is_faction_exclusive,min_reputation,sector_type,enemy_name,is_fixed,fixed_chain_id,fixed_step,trust_threshold,reward_gold_override,duration_override_seconds,trust_reward_override,min_trust_level
```

## 자체 검증 체크리스트

- [ ] 모든 `id`가 명명 규칙을 따르는가
- [ ] 모든 `id`·`name`이 기존 quest_pools과 중복되지 않는가
- [ ] `type_id`가 quest_types 테이블에 실존하는가
- [ ] `type` 컬럼이 모두 0인가 (레거시)
- [ ] `min_region_diff <= max_region_diff`인가
- [ ] hunt·raid 타입에 `enemy_name`이 설정되었는가
- [ ] 허드렛일의 `is_fixed = false`인가
