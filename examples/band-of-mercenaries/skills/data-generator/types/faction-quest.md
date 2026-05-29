# faction-quest — 세력 전용 퀘스트

> 세력 가입 플레이어에게 제공되는 전용 퀘스트 풀. M1 마일스톤에서 `quest_pools` 테이블의 `faction_tag` 필드를 활용하여 구현된다.

## 대상 테이블

**`quest_pools`** (Supabase)

**전제 조건:** M1에서 `quest_pools` 테이블에 `faction_tag`(text, nullable) 필드가 추가되어 있어야 한다. 미추가 상태에서 실행하면 스키마 에러가 발생하므로, 스키마 확장이 완료되었는지 operation-bom의 `table-config.ts`로 먼저 확인한다.

## 스키마 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `id` | text | ✅ | 고유 ID. 형식: `fq_{faction_key}_{slug}` (예: `fq_shadow_guild_recover_artifact`) |
| `name` | text | ✅ | 퀘스트 이름. 한국어. 15자 이내 권장 |
| `type` | real (1~4) | ✅ | 퀘스트 유형 ID: 1=약탈, 2=토벌, 3=호위, 4=탐험 |
| `difficulty` | real (1~5) | ✅ | 난이도. balance-designer가 확정한 범위 내 |
| `min_region_diff` | real | ✅ | 최소 리전 차이 (이동 거리 하한) |
| `max_region_diff` | real | ✅ | 최대 리전 차이 (이동 거리 상한) |
| `faction_tag` | text | ✅ | 세력 ID. `factions.id`와 일치해야 함 |
| `sector_type` | text | ❌ | 섹터 변형 타입 (M3에서 채움. 현재는 null) |

## 톤/세계관 규칙

### 이름 규칙

- 세력의 **철학(philosophy)과 분위기**를 반영한다
- 명사구 또는 명령형. "의뢰", "임무" 등의 접미사는 **붙이지 않는다**
- 기존 `quest_pools`의 이름 패턴을 참고 (단문, 구체적 행동 중심)

**좋은 예 (세력: 그림자 길드 — 은밀·정보):**
- "잃어버린 암호첩 회수"
- "배신자 추적"
- "밀서 전달"

**나쁜 예:**
- "그림자 길드의 긴급 의뢰" (세력 이름 노출 금지)
- "적을 처치하세요" (세력 특성 불반영)

### 퀘스트 유형 배분

세력 철학에 맞는 유형 분포를 유지한다. 기획서에서 배분을 지정하지 않은 경우 아래를 기본값으로 사용한다:

- **공격/무력 세력** (예: 용병 길드, 군벌): 약탈 40%, 토벌 40%, 호위 10%, 탐험 10%
- **정보/은밀 세력** (예: 그림자 길드, 첩보단): 탐험 40%, 호위 30%, 토벌 20%, 약탈 10%
- **보호/질서 세력** (예: 기사단, 상인 연합): 호위 50%, 토벌 30%, 탐험 15%, 약탈 5%
- **탐구/학술 세력** (예: 연구 결사): 탐험 60%, 호위 20%, 토벌 15%, 약탈 5%

### 난이도·거리 배분

세력의 `tier_range` (factions 테이블)와 일치시킨다:
- T1~T2 세력: difficulty 1~3, region_diff 0~3
- T2~T4 세력: difficulty 2~4, region_diff 1~5
- T4~T5 세력: difficulty 3~5, region_diff 2~8

balance-designer 산출물이 이 범위를 변경하는 경우 그 값을 우선한다.

## 상호 참조

생성 전 다음을 Supabase MCP로 확인한다:

1. **`factions` 테이블**: `faction_tag`에 들어갈 세력 ID가 실존하는가
2. **`quest_pools` 테이블**: 동일 `(faction_tag, name)` 조합의 기존 항목이 있는가 (중복 방지)
3. **`difficulties` 테이블**: 생성할 `difficulty` 값이 1~5 범위의 실존 ID인가

## 생성 수량 가이드라인

기획서에 수량이 지정되지 않은 경우:
- 세력당 최소 10개, 권장 15~20개 (퀘스트 자동 갱신 사이클을 고려한 최소치)
- 난이도별 최소 2개 (플레이어 성장 구간마다 선택지 보장)
- 유형별 최소 1개 (배분 비율 존중)

## CSV 출력 포맷

**헤더:**
```csv
id,name,type,difficulty,min_region_diff,max_region_diff,faction_tag,sector_type
```

**예시 행:**
```csv
fq_shadow_guild_recover_artifact,잃어버린 암호첩 회수,4,3,2,5,shadow_guild,
fq_shadow_guild_track_traitor,배신자 추적,2,2,1,3,shadow_guild,
```

**주의:**
- `sector_type`은 M1 시점에서 모두 빈 값
- `faction_tag`는 기획서와 Supabase `factions.id`가 정확히 일치해야 함
- 한국어 텍스트는 쌍따옴표로 감싸지 않되, 쉼표가 포함되면 감싼다

## 자체 검증 체크리스트

생성 직후 다음을 확인한다:

- [ ] 모든 `id`가 `fq_{faction_key}_{slug}` 형식을 따르는가
- [ ] 모든 `id`가 유일한가 (내부 중복 없음)
- [ ] 모든 `name`이 기존 `quest_pools`와 중복되지 않는가
- [ ] 모든 `faction_tag`가 `factions.id`에 실존하는가
- [ ] `type` 값이 1~4인가
- [ ] `difficulty` 값이 1~5이고 기획서 범위 내인가
- [ ] `min_region_diff <= max_region_diff`인가
- [ ] 유형 배분이 기획서 또는 기본 분포와 일치하는가

## 기획서에서 추출해야 할 항목

`--brief` 기획서를 읽을 때 다음을 추출한다:

1. **대상 세력 ID** (하나 또는 여러 개)
2. **세력 철학/분위기** — 이름 톤 결정
3. **유형 배분** — 지정된 경우 기본값 대체
4. **난이도 범위** — balance-designer 산출물 우선
5. **거리 범위** — balance-designer 산출물 우선
6. **생성 수량** — 명시된 경우 따름, 미지정 시 가이드라인 사용
7. **특수 제약** — 특정 리전에만 등장해야 하는가 등

추출 불가 항목은 사용자에게 질문한다. 기본값을 임의로 적용하지 않는다.
