---
name: error-handling
description: >
  Unity C# 프로젝트의 에러 처리, 방어적 코딩, 로깅 규칙을 정의한다.
  null 체크, 예외 처리, 디버그 로깅, 어서션에 관한 판단이 필요할 때 참조한다.
---

# 에러 처리 패턴 (Unity C#)

이 스킬은 프로젝트의 에러 처리와 방어적 코딩 규칙을 정의한다.

## Null 체크 원칙

Unity에서 null 체크는 일반 C#과 다르다. Unity Object는 Fake Null을 사용하므로 주의가 필요하다.

```csharp
// Unity Object (MonoBehaviour, GameObject, Component 등)
// 올바름 — Unity의 == 연산자가 Fake Null을 처리
if (targetObject == null) { ... }
if (!targetObject) { ... }

// 금지 — Fake Null을 감지하지 못함
if (targetObject is null) { ... }
targetObject?.DoSomething();  // Destroy된 객체에서 오작동

// 순수 C# 객체 (Unity Object가 아닌 경우)
// 여기서는 is null, ?. 모두 사용 가능
if (data is null) { ... }
callback?.Invoke();
```

## SerializeField 참조 검증

Inspector에서 할당하는 참조는 Awake에서 검증한다.

```csharp
[SerializeField] private Transform _spawnPoint;
[SerializeField] private ParticleSystem _hitEffect;

private void Awake()
{
    Debug.Assert(_spawnPoint != null, $"[{name}] _spawnPoint이 할당되지 않았습니다.", this);
    Debug.Assert(_hitEffect != null, $"[{name}] _hitEffect가 할당되지 않았습니다.", this);
}
```

규칙:
- `[SerializeField]` 참조는 Awake에서 `Debug.Assert`로 검증한다.
- Assert 메시지에 오브젝트 이름을 포함하여 어떤 오브젝트에서 문제가 발생했는지 식별 가능하게 한다.
- 세 번째 인자로 `this`를 전달하여 Console에서 클릭 시 해당 오브젝트로 이동 가능하게 한다.

## GetComponent 방어

```csharp
// RequireComponent로 컴파일 타임에 보장
[RequireComponent(typeof(Rigidbody))]
public class PlayerMovement : MonoBehaviour
{
    private Rigidbody _rigidbody;

    private void Awake()
    {
        _rigidbody = GetComponent<Rigidbody>();
    }
}

// RequireComponent가 불가능한 경우 TryGetComponent 사용
private void Awake()
{
    if (!TryGetComponent(out AudioSource audio))
    {
        Debug.LogWarning($"[{name}] AudioSource가 없습니다. 사운드가 재생되지 않습니다.", this);
        return;
    }
    _audioSource = audio;
}
```

규칙:
- 반드시 있어야 하는 컴포넌트: `[RequireComponent]` + `GetComponent` (Awake).
- 있으면 좋은 컴포넌트: `TryGetComponent` + 없을 때의 폴백 로직.
- `GetComponent`를 Update에서 호출하지 않는다. 반드시 캐싱.

## 예외 처리

Unity에서 예외(Exception)는 제한적으로 사용한다.

```csharp
// 사용하는 경우: 파일 I/O, 네트워크, JSON 파싱 등 외부 시스템
public SaveData LoadSave(string path)
{
    try
    {
        string json = File.ReadAllText(path);
        return JsonUtility.FromJson<SaveData>(json);
    }
    catch (FileNotFoundException)
    {
        Debug.Log("세이브 파일이 없습니다. 새 게임을 시작합니다.");
        return new SaveData();
    }
    catch (Exception e)
    {
        Debug.LogError($"세이브 로드 실패: {e.Message}");
        return new SaveData();
    }
}

// 사용하지 않는 경우: 일반 게임플레이 로직
// 금지 — try-catch로 일반 로직을 감싸지 않는다
try { enemy.TakeDamage(10); } catch { }

// 올바름 — 사전 조건 검사
if (enemy != null && enemy.IsAlive)
{
    enemy.TakeDamage(10);
}
```

규칙:
- 게임플레이 로직에서는 try-catch 대신 사전 조건 검사(Guard Clause)를 사용한다.
- try-catch는 파일 I/O, 네트워크, 서드파티 라이브러리 호출에만 사용한다.
- catch 블록에서 예외를 삼키지(swallow) 않는다. 최소한 로그를 남긴다.
- 빈 catch `catch { }` 금지.

## 로깅 규칙

```csharp
// 로그 레벨 사용 기준
Debug.Log("플레이어 스폰 완료");              // 정보: 정상 흐름의 주요 이벤트
Debug.LogWarning("적 스폰 포인트 부족");       // 경고: 동작은 하지만 의도와 다름
Debug.LogError("필수 리소스 로드 실패");        // 에러: 기능이 정상 동작하지 않음
Debug.Assert(condition, "이건 절대 일어나면 안 됨"); // 어서션: 개발 중 가정 검증
```

규칙:
- 모든 로그에 컨텍스트를 포함한다: `$"[{name}] 메시지"` 또는 `$"[{GetType().Name}] 메시지"`.
- 프레임마다 반복되는 로그를 남기지 않는다 (Update에서 Debug.Log 금지).
- 릴리스 빌드에서는 로그를 비활성화하거나 커스텀 로거를 사용한다.
- `Debug.LogException(e)`은 Exception 객체가 있을 때 사용한다 (스택 트레이스 보존).

## UniTask 비동기 안전 패턴

이 프로젝트는 코루틴을 사용하지 않는다. 모든 비동기 처리는 UniTask로 수행한다.

### CancellationToken 필수 전달

```csharp
// MonoBehaviour에서 비동기 작업 시 반드시 취소 토큰 전달
private async UniTaskVoid HandleAbilityAsync()
{
    var token = this.GetCancellationTokenOnDestroy();

    await UniTask.Delay(1000, cancellationToken: token);
    // 이 시점에서 오브젝트가 파괴되었으면 자동 취소
    DoSomething();
}
```

규칙:
- `GetCancellationTokenOnDestroy()`를 항상 전달한다.
- `async void` 금지. `async UniTaskVoid` 또는 `async UniTask`를 사용한다.
- fire-and-forget은 `UniTaskVoid`로, await이 필요하면 `UniTask`로 반환한다.

### 중복 실행 방지

```csharp
private CancellationTokenSource _fadeCts;

public void StartFade()
{
    // 기존 작업 취소
    _fadeCts?.Cancel();
    _fadeCts?.Dispose();
    _fadeCts = new CancellationTokenSource();

    FadeAsync(_fadeCts.Token).Forget();
}

private async UniTask FadeAsync(CancellationToken token)
{
    float elapsed = 0f;
    while (elapsed < 1f)
    {
        elapsed += Time.deltaTime;
        // ... 페이드 로직
        await UniTask.Yield(token);
    }
}

private void OnDestroy()
{
    _fadeCts?.Cancel();
    _fadeCts?.Dispose();
}
```

규칙:
- CancellationTokenSource를 캐싱하여 중복 실행을 방지한다.
- 새 작업 시작 전에 기존 CTS를 Cancel + Dispose한다.
- OnDestroy에서 CTS를 정리한다.

### UniTask에서의 예외 처리

```csharp
private async UniTask LoadDataAsync(CancellationToken token)
{
    try
    {
        var data = await resourceManager.LoadAsync<TextAsset>("config", token);
        // ... 데이터 처리
    }
    catch (OperationCanceledException)
    {
        // 취소는 정상 흐름 — 로그 불필요
    }
    catch (Exception e)
    {
        Debug.LogError($"[{name}] 데이터 로드 실패: {e.Message}");
    }
}
```

규칙:
- `OperationCanceledException`은 별도 catch하여 무시한다 (오브젝트 파괴 시 정상 발생).
- 그 외 예외는 반드시 로그를 남긴다.
