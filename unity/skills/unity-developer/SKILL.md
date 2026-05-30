---
name: unity-developer
description: >
  모바일(Android/iOS/WebGL) 타깃의 Unity URP 게임 개발 전문 지식을 제공한다.
  아키텍처 설계, 성능 최적화, 플랫폼별 고려사항 판단이 필요할 때 참조한다.
disable-model-invocation: true
---

## 이 스킬을 사용하는 경우

- Unity 아키텍처 설계 또는 기술 의사결정이 필요할 때
- 모바일 성능 최적화 판단이 필요할 때
- URP 렌더링 관련 설계 결정이 필요할 때
- 스킬이 명시적으로 호출된 경우에만 사용

## 이 스킬을 사용하지 않는 경우

- Unity 개발과 무관한 작업일 때
- 스킬이 호출되지 않은 경우

## 프로젝트 환경

- 엔진: Unity 6 LTS
- 렌더 파이프라인: URP 전용
- 언어: C#
- 타깃 플랫폼: Android, iOS, WebGL
- UI: uGUI 전용
- 비동기: UniTask 또는 코루틴

## Unity 핵심 숙련도

- Unity 6 LTS 기능 및 장기 지원의 이점
- Unity 에디터 커스터마이징 및 생산성 향상 워크플로우
- 패키지 매니저 및 커스텀 패키지 개발
- Git을 활용한 버전 관리
- Android/iOS/WebGL 빌드 최적화 및 플랫폼별 설정

## URP 렌더링

- URP 최적화 및 커스터마이징
- 커스텀 렌더 기능 및 렌더러 패스
- Shader Graph를 이용한 시각적 셰이더 제작 및 모바일 최적화
- 포스트 프로세싱 스택 구성 및 모바일 성능 고려
- 모바일 타깃에 맞는 조명 및 그림자 최적화 (베이크드 라이팅 선호, 실시간 그림자 최소화)

## 모바일 성능 최적화

- CPU, GPU, 메모리 분석을 위한 Unity Profiler 활용
- 렌더링 파이프라인 최적화를 위한 Frame Debugger
- Memory Profiler를 통한 힙 및 네이티브 메모리 관리
- 물리 엔진 최적화 및 충돌 감지 효율화
- 오클루전 컬링 및 프러스텀 컬링 최적화
- 텍스처 스트리밍 및 에셋 로딩 최적화
- 드로우 콜 최소화: 배칭, 아틀라스, GPU 인스턴싱
- 모바일 GPU 대역폭 절약: 오버드로우 감소, 셰이더 복잡도 제한
- 써멀 스로틀링 대응: 프레임 레이트 캡, 동적 해상도 스케일링
- 배터리 소모 최적화

## 고급 C# 게임 프로그래밍

- C# 9.0+ 기능 및 최신 언어 패턴
- Unity 특화 C# 최적화 기법
- 고성능 코드를 위한 Job System 및 Burst Compiler
- 코루틴 대체를 위한 async/await 패턴 (UniTask)
- 메모리 관리 및 가비지 컬렉션 최적화 (모바일에서 특히 중요)
- Span<T>, stackalloc 등 할당 최소화 기법

## 게임 아키텍처 및 디자인 패턴

- UI 및 게임 로직 분리를 위한 MVC(모델-뷰-컨트롤러) 패턴
- 시스템 간 결합도를 낮추는 옵저버 패턴 / 이벤트 시스템
- 캐릭터 및 게임 상태 관리를 위한 상태 머신
- 성능 중요 상황에서의 오브젝트 풀링
- 싱글톤 패턴 활용 및 의존성 주입
- 서비스 로케이터 패턴
- 대규모 프로젝트를 위한 모듈식 아키텍처
- 데이터 기반 게임 디자인을 위한 ScriptableObject 활용

## 에셋 관리 및 최적화

- 동적 콘텐츠 로딩을 위한 Addressable Assets 시스템
- 에셋 번들 생성 및 관리 전략
- 모바일 텍스처 압축: ASTC 전용 (Android/iOS 공통)
- 오디오 압축 및 모바일 메모리 고려
- 애니메이션 시스템 최적화 및 압축
- 메시 최적화 및 LOD
- 에셋 의존성 관리 및 순환 참조 방지
- WebGL에서 파일 시스템 접근 금지 — 저장은 반드시 PlayerPrefs(SaveStorage)만 사용

## UI/UX 구현

- uGUI 캔버스 최적화 및 UI 성능 튜닝 (UI Toolkit 사용하지 않음)
- 다양한 모바일 해상도 대응: Safe Area, 노치, 펀치홀 처리
- Input System을 통한 터치 입력 처리
- UI 애니메이션 및 전환 시스템
- 다국어 지원 및 현지화(i18n)

## 물리 및 애니메이션

- Unity Physics 최적화 (모바일에서 물리 연산 최소화)
- 2D 및 3D 물리 최적화 기법
- 애니메이션 상태 머신 및 블렌드 트리
- Cinemachine 카메라 시스템
- 파티클 시스템 최적화 (모바일 파티클 수 제한)

## Android/iOS 플랫폼 전용

### Android
- IL2CPP 백엔드 빌드 최적화
- Android App Bundle(AAB) 구성
- Vulkan/OpenGLES 3.0 그래픽스 API 선택
- 다양한 기기 스펙 대응 (메모리 1GB~12GB 범위)
- Google Play 스토어 정책 및 인증 요건
- ProGuard/R8 난독화 설정

### iOS
- IL2CPP 빌드 최적화
- Xcode 프로젝트 설정 및 자동화
- Metal 그래픽스 API 최적화
- App Store 심사 가이드라인 준수
- TestFlight 배포 워크플로우
- iOS 메모리 제한 대응 (jetsam 방지)

### WebGL
- 파일 시스템 접근 불가 — PlayerPrefs만 사용 (SaveStorage를 통해)
- 빌드 크기 최적화: Gzip/Brotli 압축, 불필요 에셋 제외
- 메모리 제약: 힙 크기 제한, 큰 Addressable 번들 분할 로딩
- 멀티스레딩 제한: UniTask로 비동기 처리, Job System 사용 자제
- AudioContext 정책: 사용자 인터랙션 후 첫 오디오 재생 필요
- 크로스 플랫폼 테스트: Chrome/Safari/Firefox 동작 차이 확인

### 공통
- 플랫폼 스토어 IAP 통합
- 푸시 알림 처리
- 딥 링크 / 유니버설 링크
- 광고 SDK 통합 시 성능 영향 최소화
- 크래시 리포팅 (Firebase Crashlytics 등)

## 품질 보증

- Unity Test Framework (EditMode / PlayMode)
- 성능 벤치마킹 및 회귀 테스트
- 메모리 누수 탐지 및 방지
- 실기기 테스트 (Android 다양한 기기, iOS 다양한 세대)
- 크래시 리포팅 및 애널리틱스 통합

## 설계 판단 원칙

1. 모바일 성능을 최우선으로 고려한다. 데스크톱에서 잘 돌아가도 모바일에서 문제가 되면 안 된다.
2. 메모리 할당을 최소화한다. GC 스파이크는 모바일에서 프레임 드롭의 주요 원인이다.
3. 드로우 콜을 줄인다. 배칭, 아틀라스, GPU 인스턴싱을 적극 활용한다.
4. 셰이더는 가능한 한 단순하게 유지한다. 모바일 GPU의 ALU 및 대역폭 한계를 고려한다.
5. 에셋 크기를 관리한다. 앱 다운로드 크기와 런타임 메모리 사용량을 모두 고려한다.
6. Android/iOS/WebGL 모두에서 동작을 검증한다. 한 플랫폼만 테스트하지 않는다.
7. 써멀 스로틀링을 고려한다. 지속적인 최대 성능은 불가능하다.
8. WebGL 환경에서 파일 시스템 저장을 사용하지 않는다. 반드시 PlayerPrefs를 SaveStorage를 통해 사용한다.
