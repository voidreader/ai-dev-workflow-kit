---
name: unity-ugui-ui
description: UnityCatClicker 프로젝트에서 UGUI 기반 UI(UI_View / UI_Popup)를 신규 생성하거나 수정할 때 사용한다. 사용자가 "UI 만들어줘", "팝업 추가", "화면 추가", "UI 수정", UI_XXX 클래스 작업을 언급하면 반드시 이 스킬을 사용한다. UI Toolkit 작업에는 사용하지 않는다.
---

# UGUI 기반 UI 생성/수정 스킬

UnityCatClicker 프로젝트의 UGUI 기반 UI를 **기획서 + 체크리스트 기반**으로 안전하게 생성·수정한다.

## 전제 조건

이 스킬은 프로젝트의 다음 규칙을 기반으로 동작한다:

- `CLAUDE.md` — 프로젝트 전역 컨벤션 (Manager 접근, UI 규칙, SaveData, 네이밍)
- **UI 클래스 계층**: `UI_Base` 직접 상속 금지 / 화면형 → `UI_View` / 팝업형 → `UI_Popup`
- **Enum 바인딩**: Hierarchy GameObject 이름과 Enum 항목명 반드시 일치

## 작업 분기

사용자 요청을 분석해 둘 중 하나의 모드로 진입한다:

| 모드 | 트리거 예시 |
|------|-------------|
| **CREATE** | "UI 새로 만들어줘", "팝업 추가해줘", "XXX 화면 만들어줘" |
| **MODIFY** | "UI_XXX 버튼 추가", "텍스트 변경", "UI_XXX 수정" |

요청이 애매하면 사용자에게 짧게 물어본다: **"신규 UI 생성인가요, 기존 UI 수정인가요?"**

## 공통 원칙

1. `UI_View`는 화면형, `UI_Popup`은 팝업형 — 잘못 상속하면 UIManager가 오작동
2. Enum 항목명 = Hierarchy GameObject 이름 — 불일치 시 런타임 NullReference
3. `Init()`에서 바인딩 후 `Refresh()` 호출
4. 이벤트는 `BindEvent`로만 연결, `AddListener` 직접 사용 자제
5. Manager 접근은 `Managers.XX`를 통해서만
6. `UnityEngine.Object`에 `?.`/`??`/`is null` 금지 → `if (obj != null)` 또는 `if (obj)` 사용

## 전체 워크플로우 (CREATE 모드)

```
1. 기획서 또는 요구사항 분석
2. 팝업/화면 여부 결정
3. Enum 목록 추출 (Texts, Buttons, Images, Objects)
4. C# 스크립트 생성 (Init, Refresh, OnClickXXX 메서드)
5. 프리팹 생성 안내 체크리스트 출력
```

### C# 코드 템플릿 (CREATE용)

**UI_View (화면형)**:

```csharp
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UI_[ClassName] : UI_View
{
    enum Texts { /* 텍스트 요소들 */ }
    enum Buttons { /* 버튼 요소들 */ }
    enum Images { /* 이미지 요소들 */ }

    public override bool Init()
    {
        if (base.Init() == false) return false;

        BindText(typeof(Texts));
        BindButton(typeof(Buttons));
        BindImage(typeof(Images));

        // 버튼 이벤트 연결
        // GetButton((int)Buttons.XXX).gameObject.BindEvent(OnClickXXX);

        Refresh();
        return true;
    }

    void Refresh()
    {
        // UI 데이터 반영
    }
}
```

**UI_Popup (팝업형)**:

```csharp
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UI_[ClassName] : UI_Popup
{
    enum Texts { /* 텍스트 요소들 */ }
    enum Buttons { CloseButton, /* 기타 버튼들 */ }
    enum Images { /* 이미지 요소들 */ }

    public override bool Init()
    {
        if (base.Init() == false) return false;

        BindText(typeof(Texts));
        BindButton(typeof(Buttons));
        BindImage(typeof(Images));

        GetButton((int)Buttons.CloseButton).gameObject.BindEvent(OnClickClose);
        // GetButton((int)Buttons.XXX).gameObject.BindEvent(OnClickXXX);

        Refresh();
        return true;
    }

    void Refresh()
    {
        // UI 데이터 반영
    }

    void OnClickClose()
    {
        Debug.Log("[UI_ClassName] 닫기");
        Managers.UI.ClosePopupUI();
    }
}
```

코드 생성 시 준수 사항:
- 실제 요구사항에 맞는 Enum 항목을 채운다
- 사용하는 Enum만 Bind한다 (Texts가 없으면 `BindText` 생략)
- 로그 형식: `Debug.Log("[클래스명] 메시지")`
- 한국어 주석 사용

## 전체 워크플로우 (MODIFY 모드)

```
1. 대상 파일 읽기: Assets/@Project/1. Scripts/UI/{ClassName}.cs
2. 수정 범위 판단 (작은 수정 vs 큰 수정)
3. Enum 항목 추가/변경 시 Hierarchy 오브젝트명 일치 확인 안내
4. 수정 적용
5. 영향받는 시스템 확인 (UIManager, 호출부 등)
```

수정 규모 판단:
- **작은 수정** (Enum 1~2개 추가, 이벤트 핸들러 추가, 데이터 반영 로직 변경) → 바로 적용
- **큰 수정** (상속 변경, Init 구조 재편, 전체 레이아웃 변경) → 수정 계획을 먼저 설명하고 사용자 확인 후 적용

## UIManager 사용 패턴

```csharp
// 팝업 열기
Managers.UI.ShowPopupUI<UI_ExamplePopup>();

// 씬 UI 설정
Managers.UI.ShowSceneUI<UI_MainScene>();

// 팝업 닫기 (팝업 내부에서)
Managers.UI.ClosePopupUI();
```

## 파일 경로

| 종류 | 경로 |
|------|------|
| C# 스크립트 | `Assets/@Project/1. Scripts/UI/{ClassName}.cs` |
| 프리팹 | `Assets/@Project/2. Prefabs/UI/{ClassName}.prefab` |

## 금지 사항

- `UI_Base` 직접 상속 금지
- `Resources.Load` 직접 사용 금지 (ResourceManager 통해)
- `UnityEngine.Object`에 `?.`/`??`/`is null` 금지
- Enum 항목명과 GameObject 이름 불일치 허용 금지
- `AddListener` 직접 사용 자제 (`BindEvent` 사용)
- Manager 직접 인스턴스화 금지 (`Managers.XX` 통해 접근)

## 완료 시 출력 포맷

```
## 완료
- 생성/수정 파일: Assets/@Project/1. Scripts/UI/{ClassName}.cs
- Enum 항목:
  - Texts: {목록}
  - Buttons: {목록}
  - Images: {목록}

## Unity 에디터에서 직접 수행해주세요
1. Assets/@Project/2. Prefabs/UI/ 에 프리팹 생성
2. 프리팹 Hierarchy에서 Enum 항목명과 오브젝트명 일치 확인
3. 최상위 오브젝트에 {ClassName} 컴포넌트 부착 확인
4. Play Mode에서 UI 정상 표시 확인
```
