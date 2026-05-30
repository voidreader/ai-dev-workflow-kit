---
name: figma-to-ugui
description: >
  Figma 레이어를 UnityCatClicker의 UGUI 기반 UI (UI_View / UI_Popup + Enum 바인딩)로 변환한다.
  사용자가 Figma "Copy link to selection" URL을 제공하면 반드시 이 스킬을 사용한다.
  Figma MCP가 연결된 환경에서 동작한다.
  트리거 키워드: "figma 가져와", "figma import", "figma 링크", "피그마 화면 만들어", figma.com URL 포함된 모든 UI 작업 요청.
---

## 전제 조건

- **Figma MCP 연결 필수** — `mcp__claude_ai_Figma__get_design_context` 호출 가능 상태
- **사용자가 Figma "Copy link to selection" URL을 제공**해야 한다. 없으면 작업 시작 전에 요청할 것
- UnityCatClicker 프로젝트 규칙: `CLAUDE.md` 준수 (UI_View/UI_Popup, Enum 바인딩, Manager 접근 패턴)

## 입력 수집 (시작 시 반드시 확인)

스킬 시작 시 아래 정보를 모두 확보한 뒤 작업을 진행한다. 부족한 항목은 사용자에게 묻는다.

| 항목 | 필수 여부 | 미제공 시 처리 |
|------|-----------|---------------|
| Figma URL (Copy link to selection) | 필수 | 작업 시작 불가, 요청 |
| 팝업 여부 (팝업 / 일반 화면) | 필수 | Figma 분석 후 제안, 사용자 확인 |
| C# 클래스명 (UI_ 접두사 포함) | 권장 | Figma 레이어명 PascalCase 변환 후 사용자 확인 |

## 전체 워크플로우

다음 단계를 순서대로 진행한다.

### 1단계: Figma 데이터 가져오기

URL에서 `fileKey`와 `nodeId`를 파싱한다.
- URL 형식: `https://www.figma.com/design/{fileKey}/{name}?node-id={nodeId}`
- `node-id`의 `-`를 `:`로 변환 (예: `123-456` → `123:456`)

```
get_design_context(fileKey, nodeId) 호출
get_screenshot(fileKey, nodeId) 호출  ← 시각 참조용 전체 스크린샷
```

`get_design_context` 결과에서 추출할 정보:
- 레이어 트리 구조 (이름, 타입, visible, 크기/위치)
- 텍스트 레이어 목록 및 내용
- 버튼/상호작용 레이어 목록
- 이미지 fill이 있는 레이어 목록
- 색상, 크기, 위치 정보

### 2단계: 레이어 분석 및 클래스명 확정

**Hidden 레이어 완전 제외**: `visible: false`인 레이어와 그 하위 모든 요소는 분석에서 제외한다.

Figma 레이어명으로 C# 클래스명을 제안한다:
- 공백/특수문자 제거, PascalCase 변환
- `UI_` 접두사 자동 추가 (예: `장비 선택 팝업` → `UI_EquipmentSelectPopup`)
- 팝업 여부는 레이어 구조(딤 배경, 닫기 버튼 유무 등)를 보고 제안

> **STOP — 사용자 응답 대기 필수**
>
> 아래 항목을 질문으로 제시하고, **사용자가 응답할 때까지 파일 생성을 일절 하지 않는다.**
> "예시로 만들어보면" / "가정하고 진행하면" 같은 선제적 코드 생성도 금지한다.
> 사용자 응답이 오면 그때 3단계로 넘어간다.
>
> 확인 항목:
> 1. **팝업 여부** — 팝업(UI_Popup)인가요, 일반 화면(UI_View)인가요?
> 2. **C# 클래스명** — `{제안명}` 으로 할까요? (변경 원하면 알려주세요)

### 3단계: Enum 목록 추출

Figma 레이어를 분석하여 각 Enum에 들어갈 항목을 추출한다.
**Enum 항목명은 반드시 Unity Hierarchy의 GameObject 이름과 일치해야 바인딩된다.**

- `Texts` enum: Label/Text 레이어 — 텍스트 표시가 필요한 요소
- `Buttons` enum: 버튼 레이어 — 클릭 이벤트가 필요한 요소
- `Images` enum: 이미지 레이어 — 스프라이트/이미지 교체가 필요한 요소
- `Objects` enum: 기타 GameObject 참조가 필요한 레이어 (슬라이더, 스크롤뷰 등)

항목명 변환 규칙:
- 레이어명의 공백/특수문자 제거, PascalCase 변환
- 의미 있는 접미사 유지 (예: `TitleText`, `CloseButton`, `CatImage`)

### 4단계: C# 스크립트 생성

저장 경로: `Assets/@Project/1. Scripts/UI/{ClassName}.cs`

**UI_View (화면형)**:

```csharp
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UI_ExampleScene : UI_View
{
    enum Texts { TitleText }
    enum Buttons { SettingButton }
    enum Images { BackgroundImage }

    public override bool Init()
    {
        if (base.Init() == false) return false;

        BindText(typeof(Texts));
        BindButton(typeof(Buttons));
        BindImage(typeof(Images));

        GetButton((int)Buttons.SettingButton).gameObject.BindEvent(OnClickSetting);

        Refresh();
        return true;
    }

    void Refresh()
    {
        // UI 갱신
    }

    void OnClickSetting()
    {
        Debug.Log("[UI_ExampleScene] 설정 클릭");
        Managers.UI.ShowPopupUI<UI_SettingPopup>();
    }
}
```

**UI_Popup (팝업형)**:

```csharp
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UI_ExamplePopup : UI_Popup
{
    enum Texts { TitleText, DescText }
    enum Buttons { CloseButton, ConfirmButton }

    public override bool Init()
    {
        if (base.Init() == false) return false;

        BindText(typeof(Texts));
        BindButton(typeof(Buttons));

        GetButton((int)Buttons.CloseButton).gameObject.BindEvent(OnClickClose);
        GetButton((int)Buttons.ConfirmButton).gameObject.BindEvent(OnClickConfirm);

        Refresh();
        return true;
    }

    void Refresh()
    {
        // UI 갱신
    }

    void OnClickClose()
    {
        Debug.Log("[UI_ExamplePopup] 닫기");
        Managers.UI.ClosePopupUI();
    }

    void OnClickConfirm()
    {
        Debug.Log("[UI_ExamplePopup] 확인");
    }
}
```

실제 코드 생성 시 규칙:
- Figma에서 추출한 실제 Enum 항목과 버튼 이벤트를 채운다
- 팝업이면 닫기 버튼(`OnClickClose` → `Managers.UI.ClosePopupUI()`)을 반드시 포함한다
- Manager 접근은 `Managers.XX` 형태만 사용한다
- 로그 형식: `Debug.Log("[클래스명] 메시지")`
- `UnityEngine.Object`에 `?.`/`??`/`is null` 금지 → `if (obj != null)` 또는 `if (obj)` 사용

### 5단계: 완료 보고

작업 완료 후 아래 형식으로 출력한다.

---

## 완료

- 생성 파일: `Assets/@Project/1. Scripts/UI/{ClassName}.cs`
- Enum 항목:
  - Texts: {목록}
  - Buttons: {목록}
  - Images: {목록}

## Unity 에디터에서 직접 수행해주세요

1. `Assets/@Project/2. Prefabs/UI/` 에 프리팹 생성
2. 프리팹 Hierarchy에서 Enum 항목명과 GameObject 이름이 정확히 일치하는지 확인
   - 불일치 시 런타임 NullReference 발생
3. 최상위 오브젝트에 `{ClassName}` 컴포넌트 부착 확인
4. Play Mode에서 UI 정상 표시 확인
5. 팝업이면: 딤 배경, 닫기 버튼 동작 확인

---

## 주의사항

- **UI Toolkit(UXML/USS) 생성 금지** — 이 프로젝트는 UGUI 기반
- `Resources.Load` 직접 사용 금지 — `ResourceManager` (`Managers.Resource`) 통해 접근
- `UnityEngine.Object`에 `?.`/`??`/`is null` 금지 → `if (obj != null)` 또는 `if (obj)` 사용
- Enum 항목명은 반드시 Hierarchy GameObject 이름과 일치시켜야 바인딩됨
- `UI_Base` 직접 상속 금지 — 화면형은 `UI_View`, 팝업형은 `UI_Popup` 상속
- `AddListener` 직접 사용 자제 — `BindEvent`로 이벤트 연결
