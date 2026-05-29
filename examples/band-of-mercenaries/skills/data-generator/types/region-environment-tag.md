# region-environment-tag — 리전 환경 태그 부여

> M2b 마일스톤에서 기존 `regions` 테이블(199행)에 `environment_tags JSONB` 컬럼을 추가하고 각 리전에 1~3개 환경 태그를 부여하는 타입.
> 엘리트 몬스터 출현·파견 상성 기반 전략 지도의 인프라로, M3 지역 변형에도 재활용된다.

## 대상 테이블

**`regions`** — 기존 199행 **UPDATE**

**전제 조건:**
- `regions.environment_tags JSONB` 컬럼이 이미 DB에 존재해야 함 (DDL은 페이즈 4-1 마이그레이션 담당)
- 컬럼이 없으면 중단하고 "페이즈 4-1 마이그레이션 선행 필요" 안내
- 기존 `environment_tags` 값이 NULL이 아닌 행이 있으면 덮어쓰기 전 확인

---

## 환경 태그 세트 (8종)

| 태그 | 한국어 | 리전 특성 키워드 |
|------|--------|----------------|
| `ruins` | 폐허 | 고대 유적, 폐광, 버려진 요새, 잊혀진 탑, 고대 유산, 폐성, 무너진 |
| `forest` | 숲 | 숲, 정글, 원시림, 삼림, 수풀, 나무, 깊은 숲, 목재 |
| `swamp` | 습지 | 늪, 습지, 안개 계곡, 진흙, 저지대, 흑수, 독 안개 |
| `mountain` | 산악 | 산, 산맥, 봉우리, 고산, 협곡, 절벽, 고원, 산악, 험준 |
| `desert` | 사막 | 사막, 황야, 모래, 건조, 불모지, 황폐, 소금 평원 |
| `coast` | 해안 | 해안, 해변, 항구, 섬, 바다, 절벽, 해협, 만, 포구, 해변 |
| `underground` | 지하 | 동굴, 지하, 광산, 지하 미궁, 갱도, 지하 도시, 함몰, 공동 |
| `plains` | 평원 | 평원, 초원, 농지, 마을, 평야, 분지, 목초지, 들판, 평탄 |

---

## 분류 규칙

### 기본 규칙

1. **키워드 기반 분류**: 리전 `name` + `description`(또는 `region_name`) 텍스트에서 위 키워드를 찾아 태그 1~3개 선정
2. **최소 1개**: 특수한 서사 리전 외에는 태그 없이 빈 배열로 남기지 않는다
3. **최대 3개**: 단일 리전에 4개 이상 태그 금지
4. **우선순위**: 환경적 특성이 강할수록 먼저 선정. "폐광" = ruins 강함 + underground 강함 + mountain 약함 → `[ruins, underground, mountain]`

### 태그 선정 결정 트리

```
1. 리전 이름/설명에서 키워드 탐색
2. 가장 강한 특성 1개 선정 (primary tag)
3. 보조 특성이 있으면 추가 (secondary tag, 최대 1개 더)
4. 세 번째 환경이 명시적이면 추가 (tertiary, 최대 1개)
5. 모호하면 1~2개로 유지
```

### 다중 태그 예시

| 리전 유형 | 추천 태그 조합 |
|---------|-------------|
| 폐광 (버려진 광산 내부) | `[ruins, underground, mountain]` |
| 늪의 고대 유적 | `[ruins, swamp]` |
| 항구 마을 주변 | `[coast, plains]` |
| 해안 동굴 | `[coast, underground]` |
| 깊은 숲 폐허 | `[forest, ruins]` |
| 고산 협곡 | `[mountain]` |
| 사막 고대 신전 | `[desert, ruins]` |
| 해안 절벽 | `[coast, mountain]` |
| 초원 마을 | `[plains]` |
| 평원 + 강 | `[plains]` |

---

## 충돌 검증 규칙 (공존 불가 조합)

아래 쌍은 **물리적·생태적으로 모순** — 동시 부여 금지:

| 금지 조합 | 이유 |
|---------|------|
| `desert` + `swamp` | 사막과 습지는 공존 불가 |
| `desert` + `coast` | 사막 내륙과 해안 직접 조합 불가 (해안 사막 리전 제외 — 특수 지형은 허용) |
| `coast` + `underground` | 해안과 지하 동시 제외 — `[coast, underground]`는 "해안 동굴"로 의미가 있으므로 **허용 예외** |

> `desert` + `coast` 예외: "소금 사막 해안" 같이 설명에 명확히 양쪽이 묘사된 경우 허용

---

## 분포 목표 (±30% 허용)

기획서 §3.7 기반 예상 분포. 생성 결과가 아래 범위에서 ±30% 벗어나면 재조정.

| 태그 | 목표 리전 수 | 허용 범위 | 주력 티어 |
|------|------------|---------|---------|
| `plains` | ~50 | 35 ~ 65 | T1~T2 주력 |
| `forest` | ~35 | 25 ~ 45 | T1~T3 |
| `mountain` | ~30 | 21 ~ 39 | T3~T5 |
| `ruins` | ~30 | 21 ~ 39 | T3~T5 |
| `coast` | ~25 | 18 ~ 33 | T1~T4 |
| `desert` | ~20 | 14 ~ 26 | T3~T5 |
| `underground` | ~20 | 14 ~ 26 | T2~T5 |
| `swamp` | ~15 | 11 ~ 20 | T2~T4 |

> 합계가 199보다 클 수 있음 (다중 태그이므로 중복 집계 정상)

### 티어별 태그 경향

| 리전 티어 | 주로 나타나는 태그 | 드문 태그 |
|---------|----------------|---------|
| T1 | plains, coast, forest | mountain, ruins, underground |
| T2 | forest, plains, coast | desert, underground |
| T3 | mountain, forest, swamp, coast | — |
| T4 | ruins, mountain, desert, underground | plains |
| T5 | ruins, underground, desert, mountain | plains, coast |

---

## 리전 데이터 접근 방법

> **중요**: 실데이터 분석 결과 `description` 컬럼은 전 행이 "{region_name} 지역" 플레이스홀더임. 키워드 분류 불가.
> **이 세계에서는 아래 "region_name 기반 분기 매핑 테이블"이 일반 키워드 분류보다 우선한다.**

data-generator는 다음 순서로 리전 목록을 처리한다:

1. Supabase MCP로 `SELECT id, region_name, region_tier FROM regions ORDER BY id` 조회
   - 컬럼명 주의: `region_name` (name 아님), `region_tier` (tier 아님)
2. 아래 **분기 매핑 테이블**을 기준으로 태그 선정 (키워드 분류 불필요)
3. 분기 규칙에 따라 region_id 오름차순 기준으로 보조 태그 대상 결정
4. 분포 검증 — 아래 "최종 분포 목표"와 대조

---

## region_name 기반 분기 매핑 테이블

> 밸런스 분석 근거: `Docs/balance-design/[balance]20260423_region-naming-reform.md`
> **전제 조건**: 이름 개편 SQL이 먼저 실행되어야 한다 (아래 "이름 개편 선행 작업" 참고).

| region_name | tier | 수 | 분기 규칙 | 태그 조합 |
|------------|------|---|---------|---------|
| 초원 | T1 | 22 | 단일 | `["plains"]` × 22 |
| **해안** | T1 | 18 | 단일 | `["coast"]` × 18 |
| 숲 | T2 | 25 | 단일 | `["forest"]` × 25 |
| **늪** | T2 | 11 | 단일 | `["swamp"]` × 11 |
| 폐허 | T3 | 29 | 단일 | `["ruins"]` × 29 |
| 산악 | T4 | 25 | 단일 | `["mountain"]` × 25 |
| 전쟁터 | T5 | 20 | 단일 | `["plains"]` × 20 |
| 고대유적 | T6 | 18 | **첫 9개** (ID ASC): 지상유적 / 나머지 9개: 지하복합 | `["ruins","underground"]` × 9 / `["underground"]` × 9 |
| 황무지 | T7 | 15 | 단일 | `["desert"]` × 15 |
| 마계경계 | T8 | 10 | 단일 | `["mountain"]` × 10 |
| 심연 | T10 | 6 | 단일 | `["underground"]` × 6 |

**세만틱 해석 주의:**
- 전쟁터 → `["plains"]` only: 현재 진행형 전장, 아직 폐허화 안 됨
- 마계경계 → `["mountain"]`: 마계 차단 산악 방벽
- 고대유적 후반 9개 → `["underground"]` only: 지하 미로만 남은 고대 도시

---

## 이름 개편 선행 작업

**data-generator 실행 전 다음 SQL이 Supabase에 적용되어 있어야 한다.**

```sql
-- 초원 18개 → 해안
UPDATE regions SET region_name = '해안' 
WHERE id IN (99,110,111,118,119,120,127,129,132,138,142,161,163,165,177,185,190,193);

-- 숲 11개 → 늪
UPDATE regions SET region_name = '늪' 
WHERE id IN (146,147,149,151,153,164,168,175,178,194,195);

-- 폐허 1개 → 숲
UPDATE regions SET region_name = '숲' WHERE id = 5;
```

완료 후 검증:
```sql
SELECT region_name, COUNT(*) FROM regions GROUP BY region_name ORDER BY COUNT(*) DESC;
-- 기대: 초원22 / 숲25 / 폐허29 / 산악25 / 전쟁터20 / 고대유적18 / 해안18 / 황무지15 / 늪11 / 마계경계10 / 심연6
```

---

## 최종 분포 목표 (이름 개편 후)

| 태그 | 달성 수 | 목표 범위 |
|------|--------|---------|
| plains | 42 | 35~65 ✓ |
| forest | 25 | 25~45 ✓ |
| mountain | 35 | 21~39 ✓ |
| ruins | 38 | 21~39 ✓ |
| coast | 18 | 18~33 ✓ |
| desert | 15 | 14~26 ✓ |
| underground | 24 | 14~26 ✓ |
| swamp | 11 | 11~20 ✓ |
| **총 태그 수** | **208** | 평균 1.05/리전 |

---

## 출력 포맷

### CSV 포맷

**헤더:**
```csv
region_id,environment_tags
```

**예시:**
```csv
1,"[""plains""]"
2,"[""forest"",""mountain""]"
3,"[""ruins"",""underground""]"
4,"[""coast""]"
5,"[""desert"",""ruins""]"
```

**주의:**
- `environment_tags`는 JSON 배열 문자열. 쌍따옴표 이스케이프 (`""`)
- 단일 태그도 배열 형식: `["plains"]` (not `"plains"`)
- 빈 배열 `[]`은 최소화 (특수 서사 리전 한정)

### SQL UPDATE 포맷 (대체 출력)

```sql
UPDATE regions SET environment_tags = '["ruins","underground"]'::jsonb WHERE id = 3;
UPDATE regions SET environment_tags = '["plains"]'::jsonb WHERE id = 1;
-- ... 199행
```

기본 출력은 **CSV**. 사용자가 SQL 형식을 요청하면 UPDATE 형식으로 제공.

---

## 생성 전 확인 사항

data-generator 실행 전 다음을 Supabase MCP로 확인:

1. **`regions` 테이블 존재 여부** + `environment_tags` 컬럼 존재 여부
2. **현재 NULL 비율**: `SELECT count(*) FROM regions WHERE environment_tags IS NULL` — 이미 채워진 행 있으면 보고
3. **리전 총 행 수**: `SELECT count(*) FROM regions` — 199행 아니면 경고

---

## 자체 검증 체크리스트

- [ ] 출력 행 수 = 199 (전 리전 커버)
- [ ] 모든 `region_id`가 유일하고 `regions.id`에 존재하는가
- [ ] 각 `environment_tags` 값이 8개 허용 태그 중에서만 선택되었는가
- [ ] 각 리전의 태그 수가 1~3개인가 (빈 배열은 특수 리전만)
- [ ] 금지 조합(`desert+swamp`, `desert+coast` 기본) 없는가
- [ ] 태그별 분포가 목표 범위(±30%) 내인가:
  - plains: 35~65개 리전
  - forest: 25~45개
  - mountain: 21~39개
  - ruins: 21~39개
  - coast: 18~33개
  - desert: 14~26개
  - underground: 14~26개
  - swamp: 11~20개
- [ ] 고티어(T4~T5) 리전에 `plains` 태그 단독 부여 없는가 (plains는 저티어 우선)
- [ ] T1 리전에 `mountain`, `ruins`, `underground` 단독 부여 없는가 (티어 경향 준수)

---

## 생성 후 안내

```
## 리전 환경 태그 부여 완료

- 처리 리전: 199개
- 태그별 분포:
  plains: {N}개 / forest: {N}개 / mountain: {N}개 / ruins: {N}개
  coast: {N}개 / desert: {N}개 / underground: {N}개 / swamp: {N}개
- 평균 태그 수: {N.N}개/리전
- 빈 배열 리전: {N}개

검증 결과:
- 분포 목표 범위: 통과 / 초과 태그 {태그명}
- 금지 조합: 없음 / 발견 {N}건

CSV 파일을 Supabase에 반영하시겠습니까?
페이즈 4-1 마이그레이션(environment_tags 컬럼 추가) 완료 후 실행 필요합니다.
```

## 상호 참조

- 엘리트 몬스터 출현 환경 매핑: `types/elite-monster.md` §보통 엘리트 31종 고정 목록의 `environment_tags` 열
- 유니크 엘리트 `fixed_region_environments`: `types/elite-monster.md` §유니크 엘리트 8종 고정 목록
- region_discoveries elite 타입 배치(페이즈 3-6): 환경 태그 부여 완료 후 유니크 엘리트 서식 리전 ID 특정 가능
