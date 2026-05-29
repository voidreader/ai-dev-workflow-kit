# chain-quest — 연계 퀘스트 체인·단계

> M3 마일스톤에서 신규 생성되는 연계 퀘스트 7체인 24단계를 생성하는 타입.
> 신규 테이블 `chain_quests` 24행을 커버한다.
> 체인 진행 상태(`ChainQuestProgress`)는 런타임 Hive에만 존재하며 본 타입 범위 밖.
>
> 입력 기획서: `Docs/content-design/[content]20260423_chain_quests.md`
> 입력 밸런스: `Docs/balance-design/[balance]20260424_chain_quest_rewards.md` (페이즈 2-1 수치 조정 7건 반영)
> 선행 조건: `items` 테이블에 M2a 장비 7종 실재 확인 (생성 전 Supabase MCP 검증)

## 선행 DDL

chain-quest 벌크 생성 전 Supabase MCP `apply_migration`으로 테이블 생성:

```sql
CREATE TABLE chain_quests (
  id TEXT PRIMARY KEY,                          -- chain_{chain_id}_step{N} 형식 (예: chain_windrunner_trail_step2)
  chain_id TEXT NOT NULL,                       -- 체인 마스터 ID (7종)
  chain_name TEXT NOT NULL,                     -- 체인 한국어 이름 (예: "질풍의 발자취")
  step INT NOT NULL CHECK (step >= 1),
  total_steps INT NOT NULL CHECK (total_steps >= 2 AND total_steps <= 5),
  region_id INT,                                -- 시작 단계는 NULL(=현재 리전), 이후 단계는 지정 가능
  target_region_id INT,                         -- 타 리전 이동 단계에서만 != region_id (런타임에서 region_id가 NULL이면 user 현재 리전과 동일 해석)
  name TEXT NOT NULL,                           -- 단계 퀘스트 이름 (예: "질풍의 흔적 추적")
  description TEXT NOT NULL,                    -- 서사 훅 (TemplateEngine 문법 포함 가능)
  quest_type_id TEXT NOT NULL REFERENCES quest_types(id),  -- raid/hunt/escort/explore
  difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 5),  -- D1~D5 스케일 (difficulties.level과 정합)
  combat_power INT NOT NULL,                    -- 적 전투력 (기획서 §2 범위 중앙값)
  reward_gold INT NOT NULL,
  reward_xp INT NOT NULL DEFAULT 0,
  reward_items JSONB NOT NULL DEFAULT '{}'::jsonb,  -- 최종 단계만 아이템 지급, 그 외 '{}'
  final_reward BOOLEAN NOT NULL DEFAULT false,  -- 최종 단계 true
  final_reputation_bonus INT,                   -- 최종 단계만 값, 그 외 NULL. balance 2-1 §5-2 공식 산출값
  duration_seconds INT NOT NULL,                -- 파견 소요 시간 (초). 기획 §2 duration_minutes × 60
  next_step_delay_seconds INT NOT NULL DEFAULT 0,  -- 다음 단계까지 대기 시간 (초). 최종 단계는 0
  faction_tag_id TEXT REFERENCES factions(id),  -- 세력 연계 체인만 값, 독립 체인은 NULL
  CONSTRAINT uq_chain_step UNIQUE (chain_id, step)
);

CREATE INDEX idx_chain_quests_chain ON chain_quests(chain_id);
CREATE INDEX idx_chain_quests_region ON chain_quests(region_id);

-- data_versions 엔트리
INSERT INTO data_versions (table_name, version) VALUES ('chain_quests', 1);
```

**주의**:
- `region_id`는 페이즈 3-2에서 `region_discoveries.hidden_quest`를 배치할 때 결정. 본 타입에서는 **NULL 허용으로 입력하고 페이즈 3-2 완료 후 UPDATE** 또는 **페이즈 3-1과 3-2를 동시 실행**하여 일괄 채움 권장
- `target_region_id`는 체인 내 이동 단계에서만 `region_id`와 다른 값. 동일 리전 단계는 `region_id`와 동일 값
- `final_reputation_bonus`는 data-generator가 balance 2-1 §5-2 공식으로 계산하여 입력

## 대상 테이블

**`chain_quests`** — 신규. 24행 (7체인 × 2~5단계)

---

## 체인 마스터 고정 목록 (7종)

**이 표는 고정. data-generator는 반드시 준수.**

| chain_id | chain_name | total_steps | 리전 티어 범위 | 지역 이동 | faction_tag_id | 최종 보상 item_id |
|---|---|---|---|---|---|---|
| `chain_roadside_shrine` | 길가의 폐사당 | 2 | T1~T2 | ❌ | NULL | `equip_helmet_iron_helm` |
| `chain_windrunner_trail` | 질풍의 발자취 | 3 | T2~T3 | ✅ (1회) | NULL | `equip_boots_gale_leather` |
| `chain_ironbound_pact` | 철갑의 서약 | 3 | T3 | ❌ | 공개(기사단형, 페이즈 3-1에서 실제 id 매핑) | `equip_armor_chain_mail` |
| `chain_blade_of_border` | 국경의 검 | 3 | T3~T4 | ✅ (1회) | 공개(용병 연합형) | `equip_weapon_steel_sword` |
| `chain_merchant_ledger` | 상인의 비망록 | 4 | T3~T4 | ✅ (2회) | 지역(상인 조합형) | `guild_artifact_golden_scale` |
| `chain_forge_masters` | 장인의 유산 | 4 | T4 | ✅ (1회 왕복) | 지역(은세공 길드형) | `equip_accessory_forge_silver_ring` |
| `chain_soul_severance` | 혼을 끊는 자 | 5 | T4~T5 | ✅ (2회) | 비밀(영혼 결사형) | `equip_accessory_soul_seal` |

**세력 매핑 절차** (data-generator가 생성 전 수행):
1. `SELECT id, name, visibility_type FROM factions` 조회
2. 각 체인의 세력 카테고리(공개/지역/비밀)와 정합하는 실제 `factions.id` 선택
3. 매핑 결과를 생성 로그에 기록 — 사용자 확인 필요 시 중단

**세력 카테고리 매칭 기준**:
- 공개(기사단형) → `visibility_type='public'` 세력 중 "기사/명예/군대" 키워드 1종
- 공개(용병 연합형) → `visibility_type='public'` 세력 중 "용병/무기" 키워드 1종
- 지역(상인 조합형) → `visibility_type='regional'` 세력 중 "상인/무역" 키워드 1종
- 지역(은세공 길드형) → `visibility_type='regional'` 세력 중 "장인/연금" 키워드 1종
- 비밀(영혼 결사형) → `visibility_type='secret'` 세력 중 "신비/영혼/어둠" 키워드 1종

---

## 단계별 고정 수치 (24행 확정표)

**이 표의 `difficulty`, `combat_power`, `reward_gold`, `duration_seconds`, `next_step_delay_seconds`, `quest_type_id`는 고정. data-generator는 `name`, `description`만 생성한다.**

### 체인 1: `chain_roadside_shrine` (길가의 폐사당, 2단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | duration_seconds | next_step_delay_seconds | final_reward | faction_tag_id |
|---|---|---|---|---|---|---|---|---|
| 1 | explore | 2 | 25 | **150** | 168 | **600** (10분) | false | NULL |
| 2 | hunt | 3 | 47 | **400** | 336 | 0 | **true** | NULL |

**최종 보상** (step 2):
- `reward_items` JSONB: `{"equip_helmet_iron_helm": 1}`
- `final_reputation_bonus`: **300** (2단계 × 150 × T2 가중 1.0)

**balance 2-1 §5-1 적용**: step 1 골드 120→150 / step 2 골드 300→400.

---

### 체인 2: `chain_windrunner_trail` (질풍의 발자취, 3단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | reward_xp | duration_seconds | next_step_delay_seconds | final_reward |
|---|---|---|---|---|---|---|---|---|
| 1 | explore | 2 | 35 | 150 | 40 | 168 | **1,800** (30분) | false |
| 2 | escort | 3 | 57 | 250 | 60 | 210 | **2,700** (45분) | false |
| 3 | hunt | 4 | 80 | 400 | 0 | 384 | 0 | **true** |

**최종 보상** (step 3):
- `reward_items` JSONB: `{"equip_boots_gale_leather": 1}`
- `final_reputation_bonus`: **540** (3 × 150 × 1.2 T3)

**단계 2의 `target_region_id` != `region_id`** (지역 이동 단계). 단계 3은 `target_region_id == region_id(step 2의 target)` 동일 리전.

---

### 체인 3: `chain_ironbound_pact` (철갑의 서약, 3단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | duration_seconds | next_step_delay_seconds | final_reward |
|---|---|---|---|---|---|---|---|
| 1 | hunt | 3 | 62 | 250 | 336 | **2,700** (45분) | false |
| 2 | escort | 3 | 67 | 300 | 315 | **3,600** (1시간) | false |
| 3 | hunt | 4 | 97 | 500 | 384 | 0 | **true** |

**최종 보상** (step 3):
- `reward_items` JSONB: `{"equip_armor_chain_mail": 1}`
- `final_reputation_bonus`: **540**

**모든 단계 동일 리전** (지역 이동 없음). 세력 연계: 공개(기사단형).

---

### 체인 4: `chain_blade_of_border` (국경의 검, 3단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | reward_xp | duration_seconds | next_step_delay_seconds | final_reward |
|---|---|---|---|---|---|---|---|---|
| 1 | raid | 3 | 70 | 280 | 0 | 252 | **3,600** (1시간) | false |
| 2 | hunt | 4 | 97 | 450 | 80 | 384 | **5,400** (1.5시간) | false |
| 3 | hunt | 5 | 135 | 700 | 0 | 432 | 0 | **true** |

**최종 보상** (step 3):
- `reward_items` JSONB: `{"equip_weapon_steel_sword": 1}`
- `final_reputation_bonus`: **540**

**step 2 이동**. 세력 연계: 공개(용병 연합형).

---

### 체인 5: `chain_merchant_ledger` (상인의 비망록, 4단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | duration_seconds | next_step_delay_seconds | final_reward |
|---|---|---|---|---|---|---|---|
| 1 | explore | 3 | 75 | 250 | 294 | **3,600** (1시간) | false |
| 2 | escort | 3 | 85 | 350 | 315 | **7,200** (2시간) | false |
| 3 | raid | 4 | 115 | 500 | 288 | **7,200** (2시간) | false |
| 4 | hunt | 4 | 125 | 700 | 384 | 0 | **true** |

**최종 보상** (step 4):
- `reward_items` JSONB: `{"guild_artifact_golden_scale": 1}`
- `final_reputation_bonus`: **720** (4 × 150 × 1.2)

**step 2·3 이동 (2회)**. step 4는 step 3 동일 리전.

---

### 체인 6: `chain_forge_masters` (장인의 유산, 4단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | duration_seconds | next_step_delay_seconds | final_reward |
|---|---|---|---|---|---|---|---|
| 1 | explore | 4 | 102 | 400 | 392 | **5,400** (1.5시간) | false |
| 2 | hunt | 4 | 120 | 500 | 384 | **7,200** (2시간) | false |
| 3 | escort | 4 | 130 | 600 | 360 | **10,800** (3시간) | false |
| 4 | raid | 5 | 157 | 900 | 324 | 0 | **true** |

**최종 보상** (step 4):
- `reward_items` JSONB: `{"equip_accessory_forge_silver_ring": 1}`
- `final_reputation_bonus`: **900** (4 × 150 × 1.5 T4)

**왕복 이동 구조**: step 3 타 리전, step 4는 step 1·2와 동일 리전 복귀.

---

### 체인 7: `chain_soul_severance` (혼을 끊는 자, 5단계)

| step | quest_type_id | difficulty | combat_power | reward_gold | duration_seconds | next_step_delay_seconds | final_reward |
|---|---|---|---|---|---|---|---|
| 1 | explore | 4 | 125 | 450 | 392 | **10,800** (3시간) | false |
| 2 | escort | 5 | 150 | 600 | 405 | **7,200** (2시간) | false |
| 3 | hunt | 5 | 165 | 750 | 432 | **14,400** (4시간) | false |
| 4 | explore | 5 | 185 | 900 | 378 | **14,400** (4시간, balance 2-1 A5) | false |
| 5 | hunt | 5 | 205 | 1,500 | 432 | 0 | **true** |

**최종 보상** (step 5):
- `reward_items` JSONB: `{"equip_accessory_soul_seal": 1}`
- `final_reputation_bonus`: **1,350** (5 × 150 × 1.8 T5)

**step 2·3 동일 타 리전 / step 4·5 동일 T5 리전**. 총 delay 13시간(balance 2-1 §5-6 반영, step 4 next_step_delay 6h→4h 단축).

---

## 생성 필드 — `name` (단계 이름)

data-generator가 생성한다. 규칙:

- 한국어 4~8자
- 단계 서사에 맞는 동사/명사 중심 (예: "폐사당 입구", "질풍의 발자취 추적")
- 체인 이름과 혼동 금지 (chain_name은 별도)
- 24 단계 모두 유일

## 생성 필드 — `description` (서사 훅)

data-generator가 생성한다. 규칙:

### 길이
- 1~2문장, 50~150자
- TemplateEngine 변수 0~2개 사용 (`{region.name}`, `{merc.name}`, `{merc.job}` 등)
- `[if joined_faction:<id>]...[else]...[/if]` 블록 가능(세력 연계 체인 3·4·5·6·7에서 옵션)
- `[pick A|B[|C]]` 블록 가능 (변주 추가)

### 톤
- 정통 판타지 문어체 ("~였다", "~하였다")
- 체인 감성:
  - 입문(1~2): 소박·호기심 ("용병 하나가 문고리에 새겨진 문양을 알아본다")
  - 중급(3~4·5): 무게감 + 서사 ("서약의 계승자가 된다", "장부의 비밀은 산길 너머에")
  - 상급(6): 장인·유산 ("반지에 은이 녹아들며 대장간의 불이 다시 피어난다")
  - 엔드(7): 결사·운명 ("옛 전사가 혼을 끊어 만들었다는 부적")
- 금지: 현대어, 영단어, 레퍼런스 고유명사

### 변수 활용 가이드
- `{merc.name}`: 체인 주인공(ChainQuestProgress.protagonistMercId)에 바인딩 — 설명 상 "용병 한 명" 언급 시 자연스럽게
- `{region.name}`: 단계 1에 특히 활용 ("이 지역의 폐사당이 오랜 먼지에 덮여 있다")
- `{merc.job}`: 전문성 언급 시 ("도적/기사/현자의 눈이 ~을 읽는다")

### 샘플 (기획서 §2 참조)

- 체인 1 step 1: "{region.name}의 폐사당 입구가 오랜 먼지에 덮여 있다. 용병 하나가 문고리에 새겨진 문양을 알아본다."
- 체인 1 step 2: "사당 깊은 곳, 옛 수호자의 뼈가 여전히 투구를 쓴 채 앉아 있다. {merc.name}은 예를 갖춰 투구를 건네받는다."
- 체인 7 step 5: "옛 전사가 혼을 끊어 만들었다는 부적. 새로운 주인이 그것을 건네받는다. [if has_trait:brave]{merc.name}은 눈을 감지 않는다.[/if]"

---

## 검증 체크리스트

### 스키마 검증

- [ ] 총 행 수 = 24
- [ ] `chain_id` 7종만 등장, 각 체인별 `total_steps`와 실제 행 수 일치 (2+3+3+3+4+4+5 = 24)
- [ ] 모든 `id`가 유일
- [ ] 각 체인별 step 1..N이 중복 없이 존재
- [ ] `difficulty` 모든 행 1~5 범위
- [ ] 최종 단계만 `final_reward=true`, 나머지 false
- [ ] 최종 단계의 `reward_items` JSONB가 §고정표 item_id 매핑 준수
- [ ] 최종 단계의 `final_reputation_bonus`가 공식 `total_steps × 150 × tier_weight` 산출값과 일치
- [ ] 비최종 단계의 `reward_items = '{}'::jsonb`, `final_reputation_bonus IS NULL`
- [ ] 최종 단계의 `next_step_delay_seconds = 0`
- [ ] `quest_type_id` 모두 `quest_types.id` FK 실존 (`raid`/`hunt`/`escort`/`explore`)
- [ ] 세력 연계 체인(3·4·5·6·7)의 `faction_tag_id`가 `factions.id` 실존
- [ ] 독립 체인(1·2)의 `faction_tag_id IS NULL`

### 수치 검증

- [ ] 체인 1 step 1 reward_gold = 150 (balance 2-1 §5-1 적용)
- [ ] 체인 1 step 2 reward_gold = 400
- [ ] 체인 7 step 4 next_step_delay_seconds = 14,400 (6h→4h 단축)
- [ ] 체인 7 전체 delay 합계 = 46,800초 (13시간)
- [ ] 모든 단계 `combat_power`, `reward_gold`, `duration_seconds`가 §고정표 값과 일치
- [ ] 최종 보상 item_id 7종(`equip_helmet_iron_helm`/`equip_boots_gale_leather`/`equip_armor_chain_mail`/`equip_weapon_steel_sword`/`guild_artifact_golden_scale`/`equip_accessory_forge_silver_ring`/`equip_accessory_soul_seal`)이 `items` 테이블 실존

### 텍스트 검증

- [ ] `name`: 24개 고유, 4~8자 한국어
- [ ] `description`: 50~150자, 1~2문장, 문어체
- [ ] TemplateEngine 문법 오류 없음 (`{`/`}` 짝, `[if]...[/if]` 닫힘)
- [ ] 금칙어(현대어/영단어/레퍼런스 고유명사) 없음

---

## CSV 출력 포맷

**헤더**:
```csv
id,chain_id,chain_name,step,total_steps,region_id,target_region_id,name,description,quest_type_id,difficulty,combat_power,reward_gold,reward_xp,reward_items,final_reward,final_reputation_bonus,duration_seconds,next_step_delay_seconds,faction_tag_id
```

**예시 행** (체인 1 step 1):
```csv
chain_roadside_shrine_step1,chain_roadside_shrine,길가의 폐사당,1,2,,,"폐사당 입구","{region.name}의 폐사당 입구가 오랜 먼지에 덮여 있다. 용병 하나가 문고리에 새겨진 문양을 알아본다.",explore,2,25,150,0,{},false,,168,600,
```

**주의**:
- `region_id`, `target_region_id`는 **CSV에서 비움**(NULL 입력) — 페이즈 3-2 완료 후 UPDATE 또는 동시 실행
- `reward_items`는 JSONB 문자열, 쌍따옴표 이스케이프 (`""`)
- 비최종 단계 `reward_items = "{}"`, 최종 단계 `reward_items = "{""equip_xxx_yyy"": 1}"`
- `description`의 TemplateEngine 변수 `{region.name}`은 런타임 치환 — CSV에는 literal `{region.name}` 그대로 저장
- `faction_tag_id`는 체인 3~7에만 값, 1·2는 비움

---

## 생성 후 안내 포맷

```
## chain_quests 생성 완료

- 총 행 수: 24
- 체인 분포: 2+3+3+3+4+4+5
- 세력 매핑: 5체인 확정 (실제 factions.id 매핑 결과 기록)
- 최종 보상 item FK: 7종 검증 완료
- balance 2-1 수치 조정 적용:
  - 체인 1 step 1 골드 150 / step 2 골드 400
  - 체인 7 step 4 delay 4시간

검증 결과:
- 스키마 체크리스트: 모두 통과 / N개 실패
- 수치 체크리스트: 모두 통과 / N개 실패
- 텍스트 체크리스트: 모두 통과 / N개 실패

다음 단계:
- 페이즈 3-2: region_discoveries의 hidden_quest 행을 생성하여 이 24 체인의 region_id를 확정
- Supabase에 쓰시겠습니까? (y / 수정 후 진행 / n)

주의: region_id가 NULL인 상태로 INSERT되므로, 페이즈 3-2 완료 후 반드시 UPDATE 실행 필요
```
