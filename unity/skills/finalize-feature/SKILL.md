---
name: finalize-feature
description: 개발이 완료된 기능을 정리하고 문서를 업데이트한 후 git 커밋을 생성한다. 이 Skill은 push를 수행하지 않는다.
---

Recommended Model : Claude Sonnet

## 언제 사용하나요?

- 자동으로 사용되지 않도록 한다.
- 반드시 사용자의 호출에 의해서만 실행된다.
- implement-spec 또는 implement-agent 스킬 이후에 사용된다.
- 명세서 없는 소규모 작업(버그 수정, 밸런스 조정 등)은 `finalize-minor-task`를 사용한다.

## Instructions:

### 1. 현재 작업 변경 사항 분석

- `git status` 로 수정/추가된 파일 목록 확인
- `git diff` 로 변경 내용 파악
- 구현된 기능 단위를 추론한다

### 2. 커밋 scope 결정

다음 우선순위로 scope를 결정한다:

1. `Docs/` 에서 `{specBase}_plan.md` 파일을 찾아 명세서 이름에서 scope 추출
2. plan 파일이 없으면 `Docs/` 의 명세서 파일명에서 추출 (예: `20260305_feature_name.md`)

### 3. 커밋 메시지 생성

기존 커밋 히스토리의 스타일을 확인하고, 변경 성격에 맞는 prefix를 선택한다:

- `feat:` — 새 기능 추가
- `fix:` — 버그 수정
- `refactor:` — 리팩토링
- `chore:` — 빌드, 설정, 기타

형식:

```
{prefix}: {scope} 구현 — {핵심요약1/핵심요약2/핵심요약3}

- 구현 상세 내용
- 구현 상세 내용
- 구현 상세 내용

Co-Authored-By: Claude <noreply@anthropic.com>
```

작성 규칙:

- 요약 라인은 3~7개의 핵심 항목을 "/" 로 구분한다.
- Bullet 목록은 실제 구현 내용만 작성한다.
- 변경되지 않은 내용은 절대 작성하지 않는다.
- 기술적인 용어를 유지한다.
- 한국어 스타일을 유지한다.

### 4. CLAUDE.md 업데이트 (조건부)

다음 **갱신 트리거 체크리스트** 중 하나라도 해당하면 CLAUDE.md를 업데이트한다:

- [ ] 새로운 매니저 또는 시스템 클래스 추가
- [ ] UI 계층 구조 변경
- [ ] 새로운 SaveData 클래스 추가
- [ ] 데이터 테이블 신규 등록
- [ ] 코딩 컨벤션 또는 금지 사항 변경
- [ ] 주요 게임플레이 시스템 신규 추가

해당하지 않으면 CLAUDE.md를 수정하지 않는다 (단순 버그 수정, 소규모 기능 추가, UI 조정 등).

업데이트 규칙:

- 파일 전체를 수정하지 말고, 관련 섹션을 찾아 업데이트하거나 append 한다.

### 5. CHANGELOG Fragment 생성

**CHANGELOG.md를 직접 수정하지 않는다.** 대신 개별 fragment 파일을 생성한다.

파일 위치: `Docs/changelog-fragments/`

파일명: `YYYYMMDD_{scope}.md`

- 예: `20260320_cat-system.md`

내용 포맷:

```markdown
### {제목}

- 변경 내용 1
- 변경 내용 2
```

작성 규칙:

- 사용자 관점에서 간단히 요약
- 기술 용어 유지
- 한국어 스타일 유지

> fragment 합산은 `merge-changelog` 스킬로 별도 수행한다.

### 6. 문서 아카이브

**먼저 `Docs/` 에서 implement-spec이 생성한 산출물 문서가 있는지 확인한다.**

네이밍 규칙: 명세서가 `{specBase}.md`이면, 관련 산출물은 `{specBase}_plan.md`, `{specBase}_unity_tasks.md`이다.

`Docs/` 에서 명세서와 동일한 `{specBase}` 네이밍의 파일들을 수집한다:
- `{specBase}.md` — 명세서 원본
- `{specBase}_plan.md` — 구현 계획 문서
- `{specBase}_unity_tasks.md` — 유니티 수동 작업 문서 (존재하는 경우)

아카이브 수행:
1. `Docs/Archive/{specBase}/` 폴더를 생성한다.
2. `{specBase}.md` → `spec.md`로 이름 변경하여 아카이브 폴더에 저장한다.
3. `{specBase}_plan.md` → `plan.md`로 이름 변경하여 아카이브 폴더에 저장한다.
4. `{specBase}_unity_tasks.md` → `unity_tasks.md`로 이름 변경하여 아카이브 폴더에 저장한다 (존재하는 경우).
5. `Docs/` 의 원본 파일들을 삭제한다 (`git rm` 사용).

**아카이브 문서 갱신**: implement-spec 이후 사용자 테스트 피드백, 오류 수정, 추가 구현 등이 진행된 경우, 아카이브 문서를 업데이트한다:

- **plan.md**: `## 추가 변경 사항` 섹션을 하단에 추가한다. implement-spec이 작성한 기존 내용은 유지하고, 이후 변경된 파일 목록과 수정 내역을 추가 기재한다.
- **unity_tasks.md**: 추가 작업에서 새로운 Unity 수동 작업이 발생했으면 기존 파일에 항목을 추가한다. 기존 항목 중 이미 해결된 것이 있으면 완료 표시한다.
- **spec.md**: 명세서 원본이므로 수정하지 않는다.

### 7. git 커밋 수행

- 변경된 파일을 **개별적으로 스테이징**한다 (`git add .` 사용 금지).
  - 예: `git add "Assets/@Project/1. Scripts/" Docs/ CLAUDE.md`
  - `.gitignore`에 포함되지 않는 임시 파일이나 민감 파일이 섞이지 않도록 주의한다.
- **HEREDOC을 사용하여** 멀티라인 커밋 메시지를 작성한다:

```bash
git commit -m "$(cat <<'EOF'
feat: {scope} 구현 — {핵심요약1/핵심요약2}

- 상세 내용

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

중요:

- **git push 는 절대 실행하지 않는다.**
- commit 까지만 수행하고 종료한다.

### 8. 결과 출력

사용자에게 다음을 출력한다:

- 생성된 커밋 메시지
- 커밋에 포함된 파일 목록
- push가 수행되지 않았음을 명시
- Unity 에디터에서 수동 작업이 필요한 경우 해당 내용 안내
