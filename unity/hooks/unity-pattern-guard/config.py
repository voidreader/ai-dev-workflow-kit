"""프로젝트 설정 — 설치 후 고치는 곳은 이 파일 하나다.

kit 기본값은 어떤 Unity 프로젝트에서도 일단 동작하는 범용값이다. 그대로 두면
검사 범위가 넓고(서드파티 에셋까지 검사) 제안 문구가 두루뭉술하므로,
설치 직후 아래 값을 프로젝트에 맞게 좁힌다.
"""

# 검사 대상 판별 — 파일 경로에 이 문자열이 들어 있는 .cs 만 검사한다.
# 좁힐수록 서드파티 에셋(Assets/Plugins, Assets/ThirdParty)이 걸리지 않는다.
#   범용: "Assets/"            게임 코드가 한 폴더에 모인 프로젝트: "Assets/Game/"
SCOPE_MARKER = "Assets/"

# 검사에서 제외하는 경로 세그먼트.
#   '/Editor/' — Unity 컨벤션상 에디터 전용 코드라 런타임 룰 대상이 아니다.
# 저수준 API 직접 호출이 정당한 부트스트랩 계층이 있으면 여기에 추가한다.
#   예) 매니저를 등록하는 계층: ("/Editor/", "/Editor.", "/Global/Managers/")
EXCLUDED_SEGMENTS = ("/Editor/", "/Editor.")

# 위반 메시지에 실을 프로젝트 고유 대안 이름.
# 구체적인 심볼 이름을 넣어야 에이전트가 바로 고칠 수 있다.
RESOURCE_MANAGER = "프로젝트 리소스 매니저"            # 예) "Global.ResourceMgr"
ASYNC_STYLE = "UniTask 또는 async/await(Awaitable)"     # 예) "UniTask"
POOLING_HINT = "오브젝트 풀"                            # 예) "Global.EffectMgr / 도메인별 전용 풀"

# 룰 심각도 덮어쓰기 — 룰 id → "block" | "warn".
# rules.py 를 고치지 않고 프로젝트 사정에 맞춰 차단/경고를 조정한다.
# 빈 딕셔너리면 rules.py 기본값을 그대로 쓴다.
#   예) 레거시 코드가 이미 코루틴을 쓰고 있어 당장 걷어낼 수 없는 프로젝트:
#       {"coroutine": "warn"}
# 존재하지 않는 룰 id 나 "block"/"warn" 이 아닌 값을 넣으면 훅이 즉시 실패한다 —
# 오타가 조용히 무시되면 가드가 꺼진 줄 모르게 되기 때문이다.
SEVERITY_OVERRIDES = {}
