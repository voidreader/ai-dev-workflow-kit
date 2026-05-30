---
name: unity-script-rule
description: >
  Unity에서 흔히 발생하는 실수를 방지한다 — 라이프사이클 순서, GetComponent 캐싱, 물리 타이밍, Unity의 Fake Null.
---

## 라이프사이클 순서
- `Awake`가 `Start`보다 먼저 — Awake는 자기 자신 초기화, Start는 다른 객체 참조에 사용
- `OnEnable`은 `Start`보다 먼저 호출 — 단, `Awake` 이후
- 스크립트 간 실행 순서는 보장되지 않음 — 필요하면 Script Execution Order 설정
- `Awake`는 비활성 상태에서도 호출됨 — `Start`는 활성화된 경우에만 호출

## GetComponent 성능
- `GetComponent`를 매 프레임 호출하면 느림 — `Awake` 또는 `Start`에서 캐싱
- `GetComponentInChildren`은 재귀 탐색 — 깊은 계층에서 비용이 큼
- `TryGetComponent`는 bool 반환 — null 체크를 피하고 약간 더 빠름
- `RequireComponent` 어트리뷰트 사용 — 의존성을 보장하고 문서화 역할

## 물리 타이밍
- 물리는 `FixedUpdate`에서 처리, `Update` 아님 — 프레임레이트와 무관하게 일정
- `FixedUpdate`는 프레임당 0회 또는 여러 번 실행될 수 있음 — 1:1 대응을 가정하지 말 것
- `Rigidbody.MovePosition`은 FixedUpdate에서 — `transform.position`은 물리를 우회함
- `Time.deltaTime`은 Update에서, `Time.fixedDeltaTime`은 FixedUpdate에서 — 또는 그냥 deltaTime 사용

## Unity의 Fake Null
- Destroy된 객체는 진짜 null이 아님 — `== null`은 true를 반환하지만 객체는 존재
- null 조건부 연산자 `?.`는 Unity Object에서 제대로 작동하지 않음 — `== null` 또는 `bool` 변환 사용
- 순수 C# 객체(Unity Object가 아닌 경우)에서는 `?.`, `is null` 사용 가능
- `Destroy`는 즉시 실행되지 않음 — 다음 프레임에 제거됨
- `DestroyImmediate`는 에디터에서만 사용 — 빌드에서 문제 발생

## Instantiate와 풀링
- `Instantiate`는 비용이 큼 — 자주 생성/파괴되는 객체는 풀링
- `Instantiate(prefab, parent)`로 부모 설정 — SetParent 추가 호출 불필요
- 풀에 반환할 때 `SetActive(false)` — Destroy가 아님
- 비활성 풀 객체는 부모 아래에 정리 — 하이어라키를 깔끔하게 유지

## 직렬화
- Inspector에 노출할 private 필드는 `[SerializeField]` — public보다 선호
- `public` 필드는 자동 직렬화됨 — 하지만 원치 않는 API 노출
- `[HideInInspector]`는 숨기지만 여전히 직렬화됨 — 완전히 제외하려면 `[NonSerialized]`
- 직렬화된 필드는 Inspector 값을 유지 — 코드의 기본값은 최초 직렬화 이후 무시됨

## ScriptableObject
- 에셋으로 존재하는 데이터 컨테이너 — 씬/프리팹 간 공유
- `CreateAssetMenu` 어트리뷰트로 간편 생성 — 우클릭 → Create
- 빌드에서 런타임 수정 불가 — 변경 사항이 저장되지 않음 (에디터에서만 가능)
- 설정, 아이템 데이터베이스에 적합 — 프리팹 중복 감소

## 흔한 실수
- `Find` 메서드를 매 프레임 호출 — 참조를 캐싱할 것
- 태그 문자열 비교 — `tag == "Enemy"` 대신 `CompareTag("Enemy")` 사용
- 물리 쿼리는 할당 발생 — `NonAlloc` 변형 사용: `RaycastNonAlloc`
- UI 앵커 설정 오류 — 다른 해상도에서 예상치 못한 늘어남
- `async/await`를 컨텍스트 없이 사용 — UniTask 또는 신중한 에러 처리 필요
