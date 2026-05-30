---
name: automate-unity-task
description: unity_tasks.md 파일을 받아서 Unity Editor 프리팹 자동 생성 스크립트를 작성한다. 마크다운 문서가 첨부되지 않으면 진행되지 않는다.
---

Recommended Model : Claude Opus
** 한국어 스타일 유지 **

## 언제 사용하나요?

- 자동으로 사용되지 않도록 한다.
- 사용자가 `unity_tasks.md` 파일을 전달하며 프리팹 자동 생성을 요청할 때 사용한다.

## Instructions

### 1. 입력 검증 (필수 — 문서 없으면 중단)

사용자가 마크다운 파일 경로를 전달했는지 확인한다.

- **파일이 전달되지 않은 경우:**
  - 사용자에게 다음 메시지를 출력하고 **즉시 중단**한다:
    ```
    ⚠️ unity_tasks 마크다운 파일 경로를 전달해주세요.
    예: /automate-unity-task @Docs/step10_unity_tasks.md
    ```
  - 경로가 전달될 때까지 어떤 작업도 진행하지 않는다.

- **파일이 전달된 경우:**
  - 해당 파일을 Read 도구로 읽는다.
  - 파일 내용에 프리팹 구조 정의(트리 형태 계층 구조)가 포함되어 있는지 확인한다.
  - 프리팹 구조가 없으면 사용자에게 알리고 중단한다.

### 2. 문서 분석

unity_tasks.md에서 다음 정보를 추출한다:

#### 2-1. 프리팹 작업 분류

각 섹션을 다음 유형으로 분류한다:

| 유형 | 판단 기준 | 생성할 코드 |
|---|---|---|
| **신규 생성** | "신규 생성", "새로 생성" 키워드 | `SaveAsPrefabAsset()` |
| **기존 갱신** | "갱신", "수정", "추가할 항목" 키워드 | `LoadPrefabContents()` → 수정 → `SaveAsPrefabAsset()` |
| **수동 작업 없음** | "수동 작업 없음" 키워드 | 코드 생성 불필요 — 건너뜀 |

#### 2-2. 프리팹별 추출 정보

각 프리팹 섹션에서 다음을 파싱한다:

- **프리팹 이름** — 섹션 제목에서 추출 (예: `UI_MemorialCard.prefab`)
- **저장 경로** — "위치" 항목 또는 기존 프리팹 경로에서 추출
- **계층 구조** — 트리 형태 (`├── `, `└── `, `│   `) 파싱
  ```
  UI_MemorialCard (UI_MemorialCard.cs)
  ├── AcquiredArea (GameObject)
  │   └── ImageCard (Image)
  └── EmptyArea (GameObject)
  ```
- **각 노드 정보:**
  - 오브젝트 이름 (Bind 시스템 enum 이름과 일치해야 함)
  - 컴포넌트 종류 (괄호 안): `Image`, `TextMeshProUGUI`/`TMP`, `Button`, `GameObject`, 커스텀 스크립트
  - 설명 주석 (← 뒤)
- **컴포넌트 설정** — 섹션별 상세 설정값:
  - RectTransform: 앵커, 크기, 위치
  - Image: color, preserveAspect, raycastTarget
  - TextMeshProUGUI: fontSize, alignment, color, text 기본값
  - GridLayoutGroup: cellSize, spacing, constraint 등
  - ContentSizeFitter, ScrollRect, Mask 등
  - LayoutElement, HorizontalLayoutGroup, VerticalLayoutGroup 등
- **초기 활성 상태** — "기본 비활성화" 등 키워드로 `SetActive(false)` 여부 판단
- **SerializeField 연결** — `_cardPrefab` 등 인스펙터 필드 자동 연결 정보
- **Enum 바인딩 이름** — 주의사항 섹션의 이름 일치 목록

### 3. 기존 코드베이스 참조

자동 생성 스크립트 작성 전에 다음을 확인한다:

#### 3-1. 대상 스크립트의 enum 정의 확인

프리팹에 연결될 C# 스크립트 파일을 읽어서 실제 enum 정의를 확인한다.

- `Assets/@Project/1. Scripts/UI/` 하위에서 해당 스크립트를 찾는다.
- `Images`, `Texts`, `Buttons`, `GameObjects` enum 값과 문서의 오브젝트 이름이 일치하는지 교차 검증한다.
- **불일치 발견 시** 사용자에게 경고하고 확인을 요청한다.

#### 3-2. 기존 프리팹 확인 (갱신 작업인 경우)

- 갱신 대상 프리팹이 실제로 존재하는지 확인한다.
- 없으면 사용자에게 알린다.

#### 3-3. UI_Base Bind 시스템 이해

오브젝트 이름이 enum 값과 **정확히 일치**해야 `UI_Base.Bind`에서 찾을 수 있다는 점을 항상 고려한다.

### 4. Editor 스크립트 생성

`Assets/@Project/1. Scripts/Editor/` 에 C# Editor 스크립트를 생성한다.

#### 4-1. 파일명 규칙

- `{PrefabGroupName}PrefabGenerator.cs`
- 예: `MemorialPrefabGenerator.cs`, `CatPopupPrefabGenerator.cs`
- 이미 동일 이름의 파일이 있으면 사용자에게 덮어쓸지 확인한다.

#### 4-2. 코드 구조 템플릿

```csharp
#if UNITY_EDITOR
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;
using TMPro;

/// <summary>
/// {설명} - 자동 생성된 프리팹 빌더
/// 메뉴: Tools > Claude > {그룹명}
/// </summary>
public static class {ClassName}PrefabGenerator
{
    // 프리팹 경로 상수
    private static readonly string XxxPrefabPath = "Assets/@Project/2. Prefabs/UI/...";

    // ─── 신규 생성 ───
    [MenuItem("Tools/Claude/{그룹명}/1. {프리팹명} 생성")]
    public static void Create{Name}() { ... }

    // ─── 기존 갱신 ───
    [MenuItem("Tools/Claude/{그룹명}/2. {프리팹명} 갱신")]
    public static void Update{Name}() { ... }

    // ─── 전체 실행 ───
    [MenuItem("Tools/Claude/{그룹명}/★ 전체 실행")]
    public static void CreateAll() { ... }

    // ─── 유틸리티 ───
    private static GameObject CreateUIObject(string name, Transform parent,
        Vector2 anchorMin, Vector2 anchorMax, Vector2 sizeDelta) { ... }
    private static void SetAnchoredPosition(GameObject go, Vector2 pos) { ... }
    private static void SavePrefab(GameObject root, string path) { ... }
}
#endif
```

#### 4-3. 메뉴 경로 규칙

**반드시 `Tools/Claude/` 접두사를 사용한다.**

```csharp
[MenuItem("Tools/Claude/{그룹명}/{번호}. {작업명}")]
```

예시:
```
Tools > Claude > Memorial > 1. UI_MemorialCard 생성
Tools > Claude > Memorial > 2. UI_MemorialDetailPopup 생성
Tools > Claude > Memorial > 3. UI_MemorialPopup 갱신
Tools > Claude > Memorial > ★ 전체 실행
```

#### 4-4. 생성 코드 작성 규칙

**GameObject 생성:**
```csharp
var go = new GameObject("이름");
go.layer = LayerMask.NameToLayer("UI");
var rect = go.AddComponent<RectTransform>();
rect.SetParent(parent, false);
```

**컴포넌트 추가:**
- 문서에 `(Image)` → `AddComponent<Image>()` + `AddComponent<CanvasRenderer>()`
- 문서에 `(TMP)` 또는 `(TextMeshProUGUI)` → `AddComponent<TextMeshProUGUI>()`
- 문서에 `(Button)` → `AddComponent<Image>()` + `AddComponent<Button>()`
- 문서에 커스텀 스크립트명 (예: `UI_MemorialCard.cs`) → `AddComponent<UI_MemorialCard>()`
- 문서에 `(GameObject)` → 컴포넌트 추가 없음 (순수 빈 오브젝트, Bind용 컨테이너)

**RectTransform 설정:**
- Stretch(부모 크기에 맞춤): `anchorMin=(0,0), anchorMax=(1,1), sizeDelta=(0,0)`
- 고정 크기 중앙: `anchorMin=(0.5,0.5), anchorMax=(0.5,0.5), sizeDelta=(w,h)`
- 문서에 크기 명시 없으면 Stretch 기본 적용

**초기 상태:**
- "기본 비활성화" → `go.SetActive(false);`
- "기본 활성화" 또는 명시 없음 → `SetActive(true)` (기본값이므로 생략 가능)

**SerializeField 연결 (Reflection 사용):**
```csharp
var field = typeof(TargetClass).GetField("_fieldName",
    System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
if (field != null)
    field.SetValue(component, value);
```

**기존 프리팹 갱신 패턴:**
```csharp
var root = PrefabUtility.LoadPrefabContents(assetPath);
try
{
    // 이미 존재하는지 확인 후 추가
    if (parent.Find("ChildName") == null)
    {
        // 추가 작업
    }
    PrefabUtility.SaveAsPrefabAsset(root, assetPath);
}
finally
{
    PrefabUtility.UnloadPrefabContents(root);
}
```

**프리팹 저장:**
```csharp
private static void SavePrefab(GameObject root, string path)
{
    string dir = System.IO.Path.GetDirectoryName(path);
    if (!System.IO.Directory.Exists(dir))
        System.IO.Directory.CreateDirectory(dir);
    PrefabUtility.SaveAsPrefabAsset(root, path);
    Object.DestroyImmediate(root);
    AssetDatabase.Refresh();
}
```

### 5. 생성 결과 검증

생성된 C# 파일에 대해 다음을 검증한다:

- `#if UNITY_EDITOR` / `#endif` 래핑 확인
- 모든 `using` 구문 포함 확인
- 오브젝트 이름과 스크립트 enum 값 일치 확인
- 계층 구조의 parent-child 관계가 문서와 일치하는지 확인
- 컴파일 에러 가능성 점검 (타입 오류, 누락된 참조 등)

### 6. 사용자 안내 출력

작업 완료 후 다음을 출력한다:

```
✅ Editor 스크립트 생성 완료

📄 생성 파일: Assets/@Project/1. Scripts/Editor/{FileName}.cs
📁 메뉴 경로: Tools > Claude > {그룹명}

🔧 Unity에서 실행 방법:
1. Unity Editor로 돌아가면 스크립트가 자동 컴파일됩니다
2. 메뉴: Tools > Claude > {그룹명} > ★ 전체 실행
3. 또는 개별 메뉴 항목을 선택하여 단계별 실행

⚠️ 자동 생성 후 수동 조정이 필요한 항목:
- (문서에서 파악한 수동 작업 목록)
```

### 7. 자동화 불가 항목 안내

다음은 Editor 스크립트로 자동화할 수 없으므로 별도로 안내한다:

- **스프라이트/이미지 에셋 할당** — 에셋이 프로젝트에 없거나 경로를 특정할 수 없는 경우
- **폰트 에셋 교체** — TMP 기본 폰트가 아닌 커스텀 폰트 사용 시
- **Addressable 등록** — Addressable Groups 설정은 API로 가능하나, 라벨/그룹이 사전에 존재해야 함
- **세부 디자인 조정** — 색상, 간격, 크기 등 정확한 수치가 문서에 없는 경우
- **애니메이션/트위닝 설정** — DOTween, Animator 등

### 8. 기존 스크립트 처리

이미 `Assets/@Project/1. Scripts/Editor/` 에 동일한 이름의 Generator가 존재하는 경우:

- 사용자에게 알리고 덮어쓸지 확인한다.
- 기존 파일의 메뉴 경로가 `Tools/Claude/` 가 아닌 경우, 마이그레이션을 제안한다.
