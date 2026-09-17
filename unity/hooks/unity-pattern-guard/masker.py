"""주석, 문자열 리터럴, #if UNITY_EDITOR 블록을 공백으로 치환한다.
라인/컬럼 번호 보존을 위해 길이를 유지한다."""

import re

# 토큰별 정규식. 순서가 중요 — 긴 매칭 우선.
_TOKEN_PATTERNS = [
    # raw string """...""" (C# 11)
    re.compile(r'"""(?:[^"]|""(?!"))*"""', re.DOTALL),
    # verbatim interpolated: $@"..." / @$"..."
    re.compile(r'[@$]{2}"(?:""|[^"])*"'),
    # verbatim @"..." — "" 가 escape
    re.compile(r'@"(?:""|[^"])*"'),
    # interpolated $"..." — \" 가 escape, {{ }} 보간
    re.compile(r'\$"(?:\\.|[^"\\])*"'),
    # 일반 "..." — \" 가 escape
    re.compile(r'"(?:\\.|[^"\\\n])*"'),
    # 블록 주석
    re.compile(r'/\*.*?\*/', re.DOTALL),
    # 라인 주석
    re.compile(r'//[^\n]*'),
]

# UNITY_EDITOR 블록: #if UNITY_EDITOR ~ #endif (중첩 미지원, 단순 케이스만)
_EDITOR_BLOCK = re.compile(
    r'#if\s+UNITY_EDITOR\b.*?#endif',
    re.DOTALL,
)


def _replace_preserving_newlines(text: str, start: int, end: int) -> str:
    """text[start:end] 영역을 공백으로 치환하되 개행은 유지."""
    chunk = text[start:end]
    replaced = "".join("\n" if c == "\n" else " " for c in chunk)
    return text[:start] + replaced + text[end:]


def mask(src: str) -> str:
    """주석/문자열/Editor 블록을 공백으로 치환한 사본을 반환."""
    result = src

    # 1) UNITY_EDITOR 블록 먼저 마스킹 (블록 안의 코드 자체를 검사 제외)
    for m in list(_EDITOR_BLOCK.finditer(result)):
        result = _replace_preserving_newlines(result, m.start(), m.end())

    # 2) 토큰 패턴을 한 번에 합쳐 처리 — 좌→우 스캔, 가장 빨리 매칭되는 것 선택
    combined = re.compile(
        "|".join(f"(?:{p.pattern})" for p in _TOKEN_PATTERNS),
        re.DOTALL,
    )
    for m in list(combined.finditer(result)):
        result = _replace_preserving_newlines(result, m.start(), m.end())

    return result
