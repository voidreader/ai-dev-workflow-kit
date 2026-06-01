# Flutter 어댑터

| 슬롯 | 값 |
|---|---|
| 검증모드 | build-gate |
| 게이트 명령 | `flutter analyze <변경 파일>` + (모델 변경 시) `dart run build_runner build --delete-conflicting-outputs` |
| coder 규칙 | 없음 (Flutter 규칙은 coder 본문에 내장) |
| 2단계 reviewer | flutter-reviewer |
| build resolver | dart-build-resolver |
| 작업 디렉토리 | band_of_mercenaries |

## 스택 특이사항

- **검증모드 build-gate**: task마다 coder 구현 후 `flutter analyze`(변경 파일 한정)를 PASS시킨다.
  freezed/json_serializable/hive/riverpod 모델 변경 시 `build_runner`를 먼저 실행한다.
- 게이트 실패가 3개 이상 에러·코드생성 충돌·의존성 충돌이면 `dart-build-resolver`에 위임한다.
- TDD는 강제하지 않는다. 기존 테스트가 있으면 coder가 실행해 회귀만 확인한다.
