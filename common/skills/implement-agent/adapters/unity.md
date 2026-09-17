# Unity 어댑터

| 슬롯 | 값 |
|---|---|
| 검증모드 | build-gate |
| 게이트 명령 | Unity MCP Bridge §4-1 컴파일 게이트 (`skills/_shared/unity-mcp-bridge.md`) — 미연결이면 정적 점검 |
| coder 규칙 | error-handling, unity-script-rule |
| 2단계 reviewer | 없음 — main 직접 리뷰 (TASK 적으면 경량 검증) |
| build resolver | 없음 |
| 작업 디렉토리 | . |

## 스택 특이사항

- **검증모드 build-gate**: task마다 coder 구현 후 Unity 컴파일 검증을 PASS시킨다.
- 컴파일 검증은 **Unity MCP Bridge**가 담당한다 — UnityMCP 연결 시 `refresh_unity` →
  `read_console(types:["Error"])` 0건을 확인하고, 미연결이면 정적 점검으로 폴백하며 그 사실을
  산출물에 ⚠️ 로 남긴다. 브리지 문서(`unity/skills/_shared/`)를 스킬과 함께 설치해야 한다.
- coder는 `error-handling`·`unity-script-rule` 스킬을 preload해 라이프사이클·GetComponent 캐싱·
  Fake Null 등 Unity 관용 실수를 방지한다.
- TDD는 강제하지 않는다. 게임 로직은 주로 사용자 플레이 테스트로 검증한다.
