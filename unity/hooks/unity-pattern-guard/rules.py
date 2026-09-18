"""Block / Warn 룰 데이터 + 매처."""

from __future__ import annotations
from dataclasses import dataclass, replace
import re
from typing import List

from config import ASYNC_STYLE, POOLING_HINT, RESOURCE_MANAGER

try:
    from config import SEVERITY_OVERRIDES
except ImportError:  # 훅 코드만 갱신하고 config.py 는 예전 것을 쓰는 설치본 호환
    SEVERITY_OVERRIDES = {}


@dataclass(frozen=True)
class Rule:
    id: str
    severity: str  # "block" | "warn"
    pattern: re.Pattern
    message: str
    suggestion: str


@dataclass(frozen=True)
class Violation:
    rule_id: str
    severity: str
    line: int
    col: int
    snippet: str
    message: str
    suggestion: str


_BASE_BLOCK_RULES: List[Rule] = [
    Rule(
        id="resources-load",
        severity="block",
        pattern=re.compile(r"\bResources\.Load(?:Async)?\s*[<(]"),
        message="Resources.Load() 직접 호출 금지.",
        suggestion=f"{RESOURCE_MANAGER} 경유.",
    ),
    Rule(
        id="gameobject-find",
        severity="block",
        pattern=re.compile(
            r"\b(?:GameObject\.Find|FindObjectOfType|FindObjectsOfType|FindAnyObjectByType)\("
        ),
        message="런타임 오브젝트 탐색 금지.",
        suggestion="캐싱 또는 Inspector 참조 사용.",
    ),
    Rule(
        id="transform-find",
        severity="block",
        pattern=re.compile(r"\btransform\.Find\("),
        message="transform.Find() 매 프레임 호출 금지.",
        suggestion="참조 캐싱 또는 Inspector 참조 사용.",
    ),
    Rule(
        id="camera-main",
        severity="block",
        pattern=re.compile(r"\bCamera\.main\b"),
        message="Camera.main 직접 호출 금지.",
        suggestion="Awake/OnEnable 에서 캐싱.",
    ),
    Rule(
        id="coroutine",
        severity="block",
        pattern=re.compile(r"\bStartCoroutine\(|:\s*IEnumerator\b|\bIEnumerator\s+\w+\s*\("),
        message="코루틴 금지.",
        suggestion=f"{ASYNC_STYLE} 사용.",
    ),
]

_BASE_WARN_RULES: List[Rule] = [
    Rule(
        id="fake-null",
        severity="warn",
        pattern=re.compile(r"\?\?|\?\.|\bis\s+null\b"),
        message="UnityEngine.Object 에 ?? / ?. / is null 사용 금지(Fake Null).",
        suggestion="if (obj) 또는 if (obj != null) 사용. 비-Unity 타입이면 // claude-allow: fake-null 주석 추가.",
    ),
    Rule(
        id="instantiate-destroy",
        severity="warn",
        pattern=re.compile(r"\b(?:Instantiate|Destroy)\("),
        message="Instantiate/Destroy 직접 호출 의심.",
        suggestion=f"{POOLING_HINT}로 대체 검토. 1회성 생성/파괴면 // claude-allow: instantiate-destroy 주석 추가.",
    ),
    Rule(
        id="trigger-stay",
        severity="warn",
        pattern=re.compile(r"\bvoid\s+(?:OnTriggerStay|OnCollisionStay)\b"),
        message="OnTriggerStay / OnCollisionStay 정의.",
        suggestion="이벤트 기반 또는 Enter/Exit 페어로 대체 검토.",
    ),
]

_VALID_SEVERITIES = ("block", "warn")
_BASE_RULES: List[Rule] = _BASE_BLOCK_RULES + _BASE_WARN_RULES
_KNOWN_RULE_IDS = {rule.id for rule in _BASE_RULES}


def _resolve_severity(rule: Rule) -> Rule:
    severity = SEVERITY_OVERRIDES.get(rule.id, rule.severity)
    if severity not in _VALID_SEVERITIES:
        raise ValueError(
            f"config.SEVERITY_OVERRIDES['{rule.id}'] = {severity!r} — "
            f"허용값은 {_VALID_SEVERITIES} 뿐이다."
        )
    return rule if severity == rule.severity else replace(rule, severity=severity)


_unknown_ids = sorted(set(SEVERITY_OVERRIDES) - _KNOWN_RULE_IDS)
if _unknown_ids:
    raise ValueError(
        f"config.SEVERITY_OVERRIDES 에 존재하지 않는 룰 id: {_unknown_ids}. "
        f"사용 가능한 id: {sorted(_KNOWN_RULE_IDS)}"
    )

ALL_RULES: List[Rule] = [_resolve_severity(rule) for rule in _BASE_RULES]
BLOCK_RULES: List[Rule] = [rule for rule in ALL_RULES if rule.severity == "block"]
WARN_RULES: List[Rule] = [rule for rule in ALL_RULES if rule.severity == "warn"]

_ALLOW_RE = re.compile(r"//\s*claude-allow\s*:\s*([\w\-,\s]+)")


def _allowed_rules_on_line(original_line: str) -> set[str]:
    m = _ALLOW_RE.search(original_line)
    if not m:
        return set()
    return {tok.strip() for tok in m.group(1).split(",") if tok.strip()}


def find_violations(original: str, masked: str) -> List[Violation]:
    """원본 + 마스킹된 텍스트를 받아 위반 목록 반환.
    매칭은 masked 에서, 출력 스니펫과 escape-hatch 주석은 original 에서 가져온다."""
    violations: List[Violation] = []
    orig_lines = original.splitlines()

    for rule in ALL_RULES:
        for m in rule.pattern.finditer(masked):
            line_no = masked.count("\n", 0, m.start()) + 1
            line_start = masked.rfind("\n", 0, m.start()) + 1
            col = m.start() - line_start + 1

            orig_line = orig_lines[line_no - 1] if line_no - 1 < len(orig_lines) else ""

            if rule.id in _allowed_rules_on_line(orig_line):
                continue

            violations.append(
                Violation(
                    rule_id=rule.id,
                    severity=rule.severity,
                    line=line_no,
                    col=col,
                    snippet=orig_line.strip(),
                    message=rule.message,
                    suggestion=rule.suggestion,
                )
            )

    return violations
