# quest-narrative — 퀘스트 결과 서사 템플릿

> M3 마일스톤에서 신규 생성되는 퀘스트 서사 템플릿 88행 + `quest_pools.enemy_name` 컬럼 추가.
> 신규 테이블 `quest_narratives` 88행을 커버한다.
>
> 입력 기획서: `Docs/content-design/[content]20260424_quest_narratives.md` (페이즈 1-4)
> 입력 밸런스: 없음 (본 타입은 순수 텍스트 생성, 수치 밸런스 무관)
> 선행 조건: `quest_types` 6종 존재 (labor/raid/explore/escort/hunt/survey 현 상태)

## 선행 DDL

### DDL-A: `quest_narratives` 테이블 생성

```sql
CREATE TABLE quest_narratives (
  id TEXT PRIMARY KEY,                                -- qn_{type}_{result}_{nn} 형식 (예: qn_raid_success_01)
  quest_type TEXT NOT NULL REFERENCES quest_types(id),
  result_type TEXT NOT NULL CHECK (result_type IN ('greatSuccess','success','failure','criticalFailure')),
  is_elite BOOLEAN NOT NULL DEFAULT false,
  template TEXT NOT NULL,                             -- TemplateEngine 문법 (40~120자, 1~2문장)
  weight INT NOT NULL DEFAULT 1,
  description TEXT,                                   -- 선택 맥락 설명 (생성·편집 시 참고용), nullable
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_qn_type_result ON quest_narratives(quest_type, result_type, is_elite);

-- data_versions 엔트리
INSERT INTO data_versions (table_name, version) VALUES ('quest_narratives', 1);
```

### DDL-B: `quest_pools.enemy_name` 컬럼 추가

```sql
ALTER TABLE quest_pools ADD COLUMN IF NOT EXISTS enemy_name TEXT NULL;

-- data_versions bump
UPDATE data_versions SET version = version + 1 WHERE table_name = 'quest_pools';
```

**`enemy_name` 용도**: TemplateEngine의 `{quest.enemy}` 변수가 이 컬럼을 참조. 일반 퀘스트 풀에서 "도적", "늑대", "고블린" 등의 적 명칭이 서사에서 자동 치환되도록 함. NULL이면 fallback `"적"` 사용.

**`enemy_name` 채움 작업은 본 타입 범위 밖** (페이즈 3-6 일반 퀘 재분류 작업). 본 타입은 `quest_narratives` 88행만 생성.

---

## 대상 테이블

**`quest_narratives`** — 신규. 88행

---

## 88행 매트릭스 분포

기획서 §(B) 매트릭스 β 확정. 88행 = **일반 64 + 라벨+확장 16 + 엘리트 8**.

### 분포표

| quest_type | is_elite | result_type | 변형 수 | 행 수 |
|---|---|---|---|---|
| raid | false | greatSuccess/success/failure/criticalFailure | 4 각 변형 | **16** |
| hunt | false | 4 result | 4 | **16** |
| escort | false | 4 result | 4 | **16** |
| explore | false | 4 result | 4 | **16** |
| labor | false | 4 result | 2 | **8** |
| survey | false | 4 result | 2 | **8** |
| raid | **true (elite)** | 4 result | 1 | **4** |
| hunt | **true (elite)** | 4 result | 1 | **4** |
| **합계** | | | | **88** |

**주석**:
- `labor` / `survey`는 M3 스키마 확장 유형. 활성 구현 없으나 서사 템플릿 스텁 8행씩 사전 준비 (페이즈 3-6에서 일반 퀘 재분류 시 활용)
- `escort` / `explore`는 기획서에 16 = 4 × 4변형으로 명시 (총 합 일치 확인 시 raid/hunt 동일 패턴)

### result_type 매핑

Flutter `QuestResult` enum과 정합:
- `greatSuccess`: 대성공 (보상 2배)
- `success`: 성공
- `failure`: 실패
- `criticalFailure`: 대실패

---

## 템플릿 생성 규칙

### 길이

- 1~2문장, **40~120자**
- 변주 블록(`[pick]`) 포함 시 렌더 결과 기준 길이 유지

### TemplateEngine 문법 활용

- **필수**: 각 템플릿에 `{merc.name}` 또는 `{merc.job}` 중 최소 1회
- **권장**: `{region.name}` 1회 (특히 explore/survey)
- **선택**: `{quest.enemy}` 사용 (raid/hunt/escort — fallback "적" 지원)
- **변주**: `[pick A|B|C]` 블록, 행당 0~2개, 각 2~4 후보
- **조건 분기**: `[if region.sector_type=="ruins"]...[/if]` 블록 (기획 §4 D옵션 인라인 섹터 분기)
- **금지**:
  - TemplateEngine 문법 범위 외 변수 (페이즈 1-1 카탈로그 30 키만)
  - 중첩 `[pick]` 블록 (허용 안 됨)
  - `[if]` 2단계 초과 중첩

### 톤 매트릭스 (result_type별)

| result_type | 감성 | 동사 | 톤 예시 |
|---|---|---|---|
| greatSuccess | 고양·위업 | "이뤄냈다", "압도했다", "역사에 남겼다" | "{merc.name}의 일격이 적장을 갈랐다. 남은 적들은 무기를 내려놓았다." |
| success | 담담·완료 | "끝냈다", "돌아왔다", "수행했다" | "의뢰는 예정대로 완료되었다. {merc.name}의 이마에는 땀 한 방울이 흘렀다." |
| failure | 좌절·후퇴 | "밀렸다", "물러섰다", "놓쳤다" | "수적 열세를 견디지 못했다. {merc.name}은 일행을 챙겨 뒤로 물러섰다." |
| criticalFailure | 참혹·상실 | "잃었다", "쓰러졌다", "절규했다" | "전장에 붉은 자국이 남았다. {merc.name}은 돌아오지 못한 이름을 되새겼다." |

### quest_type별 특성

| quest_type | 주 배경 | 핵심 어휘 | `{quest.enemy}` 사용 |
|---|---|---|---|
| raid | 약탈·공격 | 기습, 포위, 약탈품 | ✅ 권장 ("도적단", "밀수꾼") |
| hunt | 사냥·토벌 | 추적, 일격, 송곳니 | ✅ 권장 ("늑대 무리", "거대 곰") |
| escort | 호위·동행 | 행렬, 경계, 무사 도착 | ✅ 드물게 ("습격자") |
| explore | 탐험·조사 | 흔적, 지도, 발자국 | ❌ 불필요 (적 없는 탐사) |
| labor | 잡일·일상 | 짐, 정리, 땀, 단조로움 | ❌ 불필요 |
| survey | 지역조사 | 관측, 기록, 지식, 소견 | ❌ 불필요 |

### 엘리트 전용 8행 (is_elite=true)

- raid × 4 result / hunt × 4 result
- 엘리트 몬스터 서사 톤 (거대한 상대·1회성·서사적)
- `{quest.enemy}` 강조 활용 ("태고의 리치", "심연의 크라켄" 등 유니크명 치환)
- greatSuccess: "{merc.name}이 전설의 {quest.enemy}를 베었다. 그의 이름은 오래 전해질 것이다."
- criticalFailure: "{quest.enemy}의 그림자 아래 일행은 흩어졌다. {merc.name}의 검은 땅에 떨어졌다."

### 섹터 분기 (D옵션) 사용 예

explore 성공 변형 중 1~2행에 인라인 분기:
```
{merc.name}이 {region.name}의 경계에 다다랐다. [if region.sector_type=="ruins"]돌이 부서진 복도에 메아리가 길었다.[else if region.sector_type=="village"]마을 어귀의 사람들이 조용히 고개를 끄덕였다.[else]자국만 남은 자리에 바람이 불었다.[/if]
```

---

## 변형 수 계산 (seq 번호 규칙)

id 명명 규칙: `qn_{type}_{result}_{nn}` (nn = 01~)

| quest_type | result | 변형 수 | id 예시 |
|---|---|---|---|
| raid (일반) | greatSuccess | 4 | `qn_raid_greatSuccess_01` ~ `qn_raid_greatSuccess_04` |
| raid (일반) | success | 4 | `qn_raid_success_01` ~ `_04` |
| raid (일반) | failure | 4 | `qn_raid_failure_01` ~ `_04` |
| raid (일반) | criticalFailure | 4 | `qn_raid_criticalFailure_01` ~ `_04` |
| ... (hunt/escort/explore 동일 × 4변형) | | | |
| labor (일반) | 각 result | 2 | `qn_labor_success_01` ~ `_02` |
| survey (일반) | 각 result | 2 | `qn_survey_success_01` ~ `_02` |
| raid (엘리트) | 각 result | 1 | `qn_raid_elite_success_01` |
| hunt (엘리트) | 각 result | 1 | `qn_hunt_elite_success_01` |

엘리트 ID는 `qn_{type}_elite_{result}_01` 형식으로 구분.

---

## `weight` 필드

초기값 모두 **1**. 운영 중 특정 템플릿이 과다 출현하면 운영자가 수동 조정.

기획서 Q-8: 초기 차등 없이 일괄 1. 운영 데이터로 학습 후 M4 이후 조정 검토.

---

## `description` 필드

선택적 메모. 편집자 참고용. 예: "사당 탐사 전용 (R1 유적 변형 대응)", "도적 포획 성공 한정" 등. **null 허용** (비워도 무방).

---

## 검증 체크리스트

### 수량 검증

- [ ] 총 행 수 = 88
- [ ] 분포: raid 16 / hunt 16 / escort 16 / explore 16 / labor 8 / survey 8 / raid_elite 4 / hunt_elite 4
- [ ] is_elite=true 행 정확히 8개
- [ ] 각 quest_type × result_type 조합에 최소 1개 행 존재

### 스키마 검증

- [ ] `quest_type`이 `quest_types.id` 실존 (labor/raid/explore/escort/hunt/survey 6종)
- [ ] `result_type`이 4종 enum 중 하나
- [ ] 모든 `id`가 유일
- [ ] `template` NOT NULL, 비어있지 않음
- [ ] `weight = 1` 전 행 (초기값)

### 텍스트 검증

- [ ] `template` 길이 40~120자 (변주 블록 렌더 결과 기준)
- [ ] 각 template에 `{merc.name}` 또는 `{merc.job}` 최소 1회
- [ ] explore/survey template에 `{region.name}` 1회 이상 (권장, 미적용 10% 허용)
- [ ] raid/hunt/escort template에 `{quest.enemy}` 1회 이상 (권장, 미적용 20% 허용)
- [ ] `[pick]` 블록 개수: 0~2/행, 각 블록 2~4 후보
- [ ] `[pick]` 중첩 없음
- [ ] `[if]` 블록 2단계 초과 중첩 없음
- [ ] TemplateEngine 변수 카탈로그(30 키) 외 변수 없음
- [ ] 현대어/영단어/레퍼런스 고유명사 없음

### 톤 검증

- [ ] greatSuccess 고양·위업 어휘 중심
- [ ] criticalFailure 참혹·상실 어휘 중심
- [ ] 엘리트 전용 8행이 일반 행과 구분되는 "서사적 위업/참변" 톤

---

## CSV 출력 포맷

**헤더**:
```csv
id,quest_type,result_type,is_elite,template,weight,description
```

**예시 행**:
```csv
qn_raid_success_01,raid,success,false,"{merc.name}이 {quest.enemy}의 퇴로를 차단했다. [pick 약탈품|노획물|전리품]은 짐승처럼 쌓여 있었다.",1,
qn_hunt_greatSuccess_elite_01,hunt,greatSuccess,true,"{merc.name}의 창 끝에 {quest.enemy}의 그림자가 부서졌다. 전설은 이렇게 마감된다.",1,엘리트 전용
```

**주의**:
- `template` 내 쌍따옴표(`"`)는 CSV 이스케이프 (``""``)
- TemplateEngine 변수 `{merc.name}` 등은 literal 그대로 저장
- `is_elite`는 `true` / `false` (소문자)

---

## 생성 후 안내 포맷

```
## quest_narratives 생성 완료

- 총 행 수: 88
- 분포 검증: raid 16 / hunt 16 / escort 16 / explore 16 / labor 8 / survey 8 / raid_elite 4 / hunt_elite 4

톤 샘플 (result_type별 1행씩):
- greatSuccess: "{내용}"
- success: "{내용}"
- failure: "{내용}"
- criticalFailure: "{내용}"

TemplateEngine 변수 사용 통계:
- {merc.name}: N회 / {merc.job}: N회
- {region.name}: N회
- {quest.enemy}: N회
- [pick] 블록: N개 (평균 N개/행)
- [if region.sector_type]: N개 (explore 중심)

검증 결과:
- 수량 체크리스트: 통과/실패
- 스키마 체크리스트: 통과/실패
- 텍스트 체크리스트: 통과/실패
- 톤 체크리스트: 통과/실패

Supabase에 쓰시겠습니까? (y / 수정 후 진행 / n)
```
