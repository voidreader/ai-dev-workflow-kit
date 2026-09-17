#!/usr/bin/env python3
"""PreToolUse hook entrypoint.

stdin: PreToolUse event JSON — Claude Code(Write/Edit/MultiEdit)와
Codex(apply_patch, 한 호출에 여러 파일) 양쪽을 받는다.
stdout/stderr: 진단 메시지.
exit 0: 통과 또는 경고만.
exit 2: block 위반 — 에이전트가 재시도하도록 작업을 거부.
"""

from __future__ import annotations
import json
import re
import sys
from pathlib import Path

# Windows 콘솔에서 한글/유니코드 mojibake 방지 — stderr를 UTF-8로 강제.
try:
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, Exception):
    pass

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from config import EXCLUDED_SEGMENTS, SCOPE_MARKER
from masker import mask
from rules import find_violations


def _is_in_scope(file_path: str) -> bool:
    if not file_path.endswith(".cs"):
        return False
    normalized = file_path.replace("\\", "/")
    if SCOPE_MARKER not in normalized:
        return False
    return not any(seg in normalized for seg in EXCLUDED_SEGMENTS)


_PATCH_FILE_RE = re.compile(r"^\*\*\* (?:Add|Update|Move) File: (.+?)\s*$")


def _patch_text(tool_input: dict) -> str:
    """apply_patch 입력에서 패치 본문을 찾는다 — 키 이름이 클라이언트마다 달라 값으로 판별한다."""
    for value in tool_input.values():
        if isinstance(value, str) and "*** Begin Patch" in value:
            return value
    return ""


def _apply_patch_edits(text: str) -> list[tuple[str, str]]:
    """apply_patch 본문에서 (파일 경로, 새로 들어가는 줄) 쌍을 파일별로 뽑는다."""
    out: list[tuple[str, str]] = []
    path, added = "", []
    for line in text.splitlines():
        matched = _PATCH_FILE_RE.match(line)
        if matched:
            if path and added:
                out.append((path, "\n".join(added)))
            path, added = matched.group(1), []
            continue
        if line.startswith("***"):  # Begin/End Patch, Delete File 등 지시행
            continue
        if line.startswith("+") and not line.startswith("+++"):
            added.append(line[1:])
    if path and added:
        out.append((path, "\n".join(added)))
    return out


def _extract_edits(event: dict) -> list[tuple[str, str]]:
    """(파일 경로, 새로 들어가는 내용) 쌍. Claude 는 파일 1개, Codex 는 여러 개일 수 있다."""
    tool = event.get("tool_name")
    tool_input = event.get("tool_input") or {}
    file_path = tool_input.get("file_path", "")
    if tool == "Write":
        c = tool_input.get("content")
        return [(file_path, c)] if c else []
    if tool == "Edit":
        c = tool_input.get("new_string")
        return [(file_path, c)] if c else []
    if tool == "MultiEdit":
        edits = tool_input.get("edits") or []
        return [(file_path, e["new_string"]) for e in edits if e.get("new_string")]
    patch = _patch_text(tool_input)
    if patch:
        return _apply_patch_edits(patch)
    return []


def _format_violation(file_path: str, v) -> str:
    tag = "[BLOCK]" if v.severity == "block" else "[WARN]"
    return (
        f"{tag} {file_path}:{v.line} — rule: {v.rule_id}\n"
        f"  > {v.snippet}\n"
        f"  {v.message} {v.suggestion}"
    )


def main() -> int:
    raw = sys.stdin.read()
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    all_violations = []
    for file_path, payload in _extract_edits(event):
        if not _is_in_scope(file_path):
            continue
        masked = mask(payload)
        for violation in find_violations(payload, masked):
            all_violations.append((file_path, violation))

    if not all_violations:
        return 0

    has_block = any(v.severity == "block" for _, v in all_violations)
    for file_path, violation in all_violations:
        print(_format_violation(file_path, violation), file=sys.stderr)

    return 2 if has_block else 0


if __name__ == "__main__":
    sys.exit(main())
