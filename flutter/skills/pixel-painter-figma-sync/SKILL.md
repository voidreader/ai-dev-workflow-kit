---
name: pixel-painter-figma-sync
description: Use when a Flutter app draws pixel-art icons with CustomPainter (not PNG assets, not widget trees) and you need those icons to stay in sync with Figma. Establishes a single source of truth (pixel_specs.dart) that both the Flutter painter and a Figma scan tool consume, so editing the spec once updates both the app and Figma. NOT for ordinary widgets/PNG — use flutter-figma-export for those.
---

`pixel-painter-figma-sync` skill — `CustomPainter`로 코드가 직접 그리는 픽셀아트를 **단일 진실 원천(SSOT)** 한 곳에서 Flutter와 Figma가 똑같이 소비하게 만드는 워크플로우다.

## 언제 쓰는가 (먼저 판단)

Flutter UI를 Figma로 옮기는 길은 **대상이 무엇으로 만들어졌는지**에 따라 갈린다.

| 대상 | 어떻게 옮기나 | 도구 |
|---|---|---|
| **PNG 이미지 자산** | Figma에 이미지 업로드 | `flutter-figma-export` |
| **위젯 트리** (색·둥근모서리·텍스트 조합) | 색·크기·텍스트를 읽어 Figma 노드로 재구성 | `flutter-figma-export` |
| **`CustomPainter`로 캔버스에 직접 그린 픽셀아트** | **옮길 파일이 없다** — 그리는 *절차(코드)*만 있다 | ← **이 스킬** |

> **대부분의 UI는 `flutter-figma-export`로 충분하다.** 이 스킬은 PNG도 위젯트리도 아닌,
> 코드가 매 프레임 캔버스에 직접 찍어 그리는 픽셀아트일 때**만** 쓴다.

### 이 워크플로우가 푸는 문제

픽셀아트를 처음엔 Figma에서 **수작업으로 똑같이 그려** 맞춰두기 쉽다. 하지만:

- Flutter painter 코드가 바뀌면 Figma가 어긋난다.
- Figma를 다시 렌더링하면 또 어긋난다.
- "두 곳을 영원히 손으로 동기화"해야 하는 상태 → 지속 불가능.

이 악순환을 끊는 것이 목표다.

## 핵심 아이디어: SSOT

> **"그림 그리는 절차"를 사람도 기계도 읽을 수 있는 순수 데이터로 한 곳에 빼두고(SSOT),
> 그 데이터를 Flutter와 Figma가 *똑같이* 소비하게 만든다.**

```
   lib/shared/presentation/pixel_specs.dart   ← ★ SSOT (순수 데이터, dart:ui/material 모름)
   "정규화 좌표 위에 / 어떤 도형을 / 무슨 색키로 / 어떤 순서로 찍는가"를
   List<PixelOp> 로만 기술하는 spec 함수들
                 │
       ┌─────────┴──────────┐
       ▼                    ▼
[ Flutter 가 소비 ]     [ Figma 가 소비 ]
paintPixelSpec(...)     scan_pixel_specs.dart → pixel-specs.json
= 앱 화면에 실제로 그림   → use_figma 가 Figma 컴포넌트(variant set)로 변환
```

두 소비자가 **같은 원천**을 읽으므로, 원천을 한 번 고치면 앱 렌더와 Figma가 함께 따라온다.

## 제공 파일 (templates/)

배포 시 프로젝트의 다음 위치에 배치한다(경로는 권장 컨벤션, 프로젝트에 맞게 조정 가능).

| 템플릿 | 권장 배치 위치 | 역할 | 손대는 정도 |
|---|---|---|---|
| `pixel_specs.dart` | `lib/shared/presentation/` | **SSOT** — `PixelOp` + 색키 규약 + spec 함수 | 자료형·팩토리는 그대로, spec 함수는 새로 작성 |
| `pixel_spec_painter.dart` | `lib/shared/presentation/` | 스펙→`Canvas` 렌더(`paintPixelSpec`) | 그대로 사용 |
| `scan_pixel_specs.dart` | `tool/flutter_figma_bridge/` | 스펙→`pixel-specs.json` | import·등록부만 채움 |
| `pixel_spec_models.dart` | `tool/flutter_figma_bridge/` | scan 출력 직렬화 모델 | 그대로 사용 |

## 작업 흐름

### 1. SSOT 작성 (`pixel_specs.dart`)
- `PixelOp`/팩토리는 템플릿 그대로 둔다.
- 원본 `CustomPainter`의 `drawRect/drawOval/drawLine/drawPath`를 **1:1로** `PixelOp` 팩토리에 옮긴다.
- 좌표·크기·`strokeWeight`·`cornerRadius`를 기준 크기로 나눠 **0~1 정규화**한다.
- 색은 실제 색이 아니라 **"키 문자열"**로 적는다. `'tint'` = 위젯이 런타임에 주입하는 동적 색, 나머지는 고정 토큰색.
- 주석에 "원본 painter의 어느 줄을 어떻게 옮겼는지" 변환 규칙을 남긴다(나중에 골든 테스트로 1:1 대조).

### 2. 소비자 1 — Flutter 렌더 연결
- 기존 painter가 직접 `canvas.drawRect` 하던 부분을 `paintPixelSpec(canvas, size, fooSpec(), resolve)` 한 줄에 위임한다.
- `resolve`는 색키→실제 `Color` 변환 함수. `'tint'`만 위젯이 동적으로 넘기고, 나머지는 `DesignTokens` 등 고정색으로 매핑한다.

### 3. 리팩터 안전성 증명 (골든 테스트)
- 직접 그리던 코드를 "스펙 경유"로 바꿔도 **화면이 한 픽셀도 달라지면 안 된다.**
- `matchesGoldenFile`로 리팩터 전후 렌더를 픽셀 단위 비교해 증명한다.

### 4. 소비자 2 — Figma로 옮기기
- `scan_pixel_specs.dart`의 `main()`에 spec 함수를 컴포넌트로 등록(`_comp`/`_variantComp`).
- `dart run tool/flutter_figma_bridge/scan_pixel_specs.dart` → `pixel-specs.json` 생성.
- 그 JSON을 읽어 `use_figma`로 Figma **컴포넌트(variant set)** 생성. (Figma 쓰기 전 `figma-use` 스킬을 먼저 로드한다.)
- 화면 곳곳의 픽셀 아이콘을 그 컴포넌트의 **인스턴스로 교체** → 이후 컴포넌트만 고치면 인스턴스가 일괄 갱신.
- `figma-state.json`(컴포넌트↔Figma 노드 매핑)을 기록·커밋한다 → idempotent 실행과 round-trip의 ground truth.

## Figma 좌표/스케일 실전 함정

Figma는 Flutter `Canvas`와 규칙이 달라 다음을 자주 겪는다.

| 증상 | 원인 | 해결 |
|---|---|---|
| 아이콘이 몇 배 크게 보임 | 큰 컴포넌트를 인스턴스에서 작게 `resize`해도 자식 constraint가 `SCALE`이 아니면 절대값 유지 | 컴포넌트 자식 constraint를 `SCALE`로 |
| 짙은 음영이 덮임 | Figma `strokeWeight`는 **절대값** — 프레임을 줄여도 선 두께가 그대로 | 자식 strokeWeight를 비율로 축소, 또는 `node.rescale(factor)` |

> 핵심: **Figma `resize()`는 프레임만 바꾸고 자식은 constraint대로만 따라간다.**
> 크기·위치·선두께를 한꺼번에 비례 스케일하려면 `rescale()`를 쓰거나, 애초에 실제 사용 크기로 컴포넌트를 만든다.

## 유지보수 절차 (이 파이프라인의 결실)

> **픽셀아트를 바꾸고 싶다 →**
> 1. `pixel_specs.dart` **한 곳만** 수정한다.
> 2. 앱은 자동으로 새 그림이 나온다(painter가 같은 스펙을 읽으므로). → 골든 테스트 갱신/확인.
> 3. `dart run tool/flutter_figma_bridge/scan_pixel_specs.dart` 로 JSON 갱신.
> 4. `use_figma` 로 Figma 컴포넌트 재생성.
> 5. Figma 인스턴스는 컴포넌트를 참조하므로 화면 곳곳에 **자동 반영**된다.

수작업으로 Figma를 다시 그릴 일이 없다.

## examples — 실제 적용 사례 (참고용)

`pace-counter`(만보계 게임)에서 이 파이프라인을 처음 구축했다. SSOT 한 파일에서 다음을 모두 표현했다.

- **음식 태그 아이콘 10종** — `foodTagSpec(tag)`이 `FoodTag` enum 값별로 다른 도형 목록 반환 → Figma `Pixel/FoodTagIcon`의 `tag` variant 10종.
- **통화 아이콘** — `coinSpec()`/`ticketSpec()` → `Pixel/CurrencyIcon`의 `kind` variant(coin/ticket).
- **자판기 그림** — `vendingSpec()`(본체·디스플레이·색슬롯 6개·배출구) → `Pixel/VendingMachineArt` 단일 컴포넌트.

이들은 게임 도메인에 종속적이라 그대로 복사하기보다 **"spec 함수를 이렇게 쪼갠다"는 패턴 참고용**으로 본다. 템플릿의 `coinSpec()`이 도메인 비종속 최소 예시다.
