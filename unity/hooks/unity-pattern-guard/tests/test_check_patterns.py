"""훅 엔트리포인트 검사 — 경로는 config 값에서 만든다.

config.SCOPE_MARKER / EXCLUDED_SEGMENTS 를 프로젝트에 맞게 고쳐도 이 테스트가
그대로 통과해야 한다. 경로를 하드코딩하면 설정을 바꾼 순간 테스트가 거짓으로 깨진다.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

HOOK_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HOOK_DIR))

from config import EXCLUDED_SEGMENTS, SCOPE_MARKER  # noqa: E402

HOOK = HOOK_DIR / "check_patterns.py"

IN_SCOPE = f"{SCOPE_MARKER.rstrip('/')}/Scripts/Foo.cs"
OUT_OF_SCOPE = "Packages/com.example.pkg/Runtime/Foo.cs"


def excluded_path(segment: str) -> str:
    """제외 세그먼트가 들어간 경로. '/Editor/' 와 '/Editor.' 양쪽 형태를 모두 만든다."""
    return f"{SCOPE_MARKER.rstrip('/')}/Scripts{segment}Foo.cs"


def run_hook(event: dict) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )


def write_event(file_path: str, content: str) -> dict:
    return {
        "tool_name": "Write",
        "tool_input": {"file_path": file_path, "content": content},
    }


def edit_event(file_path: str, new_string: str) -> dict:
    return {
        "tool_name": "Edit",
        "tool_input": {"file_path": file_path, "new_string": new_string},
    }


def multiedit_event(file_path: str, new_strings: list) -> dict:
    return {
        "tool_name": "MultiEdit",
        "tool_input": {
            "file_path": file_path,
            "edits": [{"new_string": s} for s in new_strings],
        },
    }


def test_out_of_scope_path_passes():
    r = run_hook(write_event(OUT_OF_SCOPE, "var x = Camera.main;"))
    assert r.returncode == 0
    assert r.stderr == ""


def test_non_cs_file_passes():
    r = run_hook(write_event(f"{SCOPE_MARKER.rstrip('/')}/Scripts/foo.txt", "Camera.main"))
    assert r.returncode == 0


@pytest.mark.parametrize("segment", EXCLUDED_SEGMENTS)
def test_excluded_segment_passes(segment):
    # 제외 경로는 룰 대상이 아니다 — 세그먼트를 추가하면 이 테스트가 자동으로 함께 검사한다.
    r = run_hook(write_event(
        excluded_path(segment),
        "public class V { void X() { var c = Camera.main; } }",
    ))
    assert r.returncode == 0
    assert r.stderr == ""


def test_block_triggers_exit2():
    r = run_hook(write_event(IN_SCOPE, "public class Foo { void Bar() { var c = Camera.main; } }"))
    assert r.returncode == 2
    assert "[BLOCK]" in r.stderr
    assert "camera-main" in r.stderr


def test_block_with_warn_still_exits_2():
    r = run_hook(write_event(
        IN_SCOPE,
        "public class Foo { void Bar() { var c = Camera.main; Instantiate(null); } }",
    ))
    assert r.returncode == 2


def test_warn_only_exits_0():
    r = run_hook(write_event(
        IN_SCOPE,
        "public class Foo { UnityEngine.Object T; void Bar() { var x = T ?? T; } }",
    ))
    assert r.returncode == 0
    assert "[WARN]" in r.stderr
    assert "fake-null" in r.stderr


def test_edit_event_checks_new_string():
    r = run_hook(edit_event(IN_SCOPE, "var c = Camera.main;"))
    assert r.returncode == 2


def test_multiedit_checks_all_new_strings():
    r = run_hook(multiedit_event(IN_SCOPE, ["var ok = 1;", "var bad = Camera.main;"]))
    assert r.returncode == 2


def test_clean_code_passes():
    r = run_hook(write_event(IN_SCOPE, "public class Foo { public int X = 1; }"))
    assert r.returncode == 0
    assert r.stderr == ""


def test_absolute_path_in_scope():
    r = run_hook(write_event(f"C:/Workspace/MyProject/{IN_SCOPE}", "var c = Camera.main;"))
    assert r.returncode == 2


def test_invalid_json_passes():
    r = subprocess.run(
        [sys.executable, str(HOOK)],
        input="not json",
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    assert r.returncode == 0


# --- Codex: 편집이 apply_patch 한 툴로 오고 한 호출에 여러 파일이 담긴다 ---

def apply_patch_event(patch: str) -> dict:
    return {"tool_name": "apply_patch", "tool_input": {"command": patch}}


def test_apply_patch_block_triggers_exit2():
    r = run_hook(apply_patch_event(
        "*** Begin Patch\n"
        f"*** Update File: {IN_SCOPE}\n"
        "@@\n"
        "-var ok = 1;\n"
        "+var c = Camera.main;\n"
        "*** End Patch\n"
    ))
    assert r.returncode == 2
    assert "camera-main" in r.stderr


def test_apply_patch_out_of_scope_passes():
    r = run_hook(apply_patch_event(
        "*** Begin Patch\n"
        f"*** Update File: {OUT_OF_SCOPE}\n"
        "+var c = Camera.main;\n"
        "*** End Patch\n"
    ))
    assert r.returncode == 0
    assert r.stderr == ""


def test_apply_patch_reports_offending_file_among_many():
    clean = IN_SCOPE.replace("Foo.cs", "Clean.cs")
    bad = IN_SCOPE.replace("Foo.cs", "Bad.cs")
    r = run_hook(apply_patch_event(
        "*** Begin Patch\n"
        f"*** Update File: {clean}\n"
        "+var ok = 1;\n"
        f"*** Add File: {bad}\n"
        "+var c = Camera.main;\n"
        "*** End Patch\n"
    ))
    assert r.returncode == 2
    assert "Bad.cs" in r.stderr
    assert "Clean.cs" not in r.stderr


def test_apply_patch_removed_lines_ignored():
    # 지워지는 줄(-)은 위반이어도 검사 대상이 아니다.
    r = run_hook(apply_patch_event(
        "*** Begin Patch\n"
        f"*** Update File: {IN_SCOPE}\n"
        "-var c = Camera.main;\n"
        "+var c = _cachedCamera;\n"
        "*** End Patch\n"
    ))
    assert r.returncode == 0
