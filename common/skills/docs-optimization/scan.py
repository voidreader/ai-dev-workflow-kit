#!/usr/bin/env python3
"""문서 정리 후보 검사기 — 죽은 심볼·배치 이탈·이력 문장·중복을 뽑는다.

사용: python .claude/skills/docs-optimization/scan.py [문서경로 ...]
인자가 없으면 git이 추적하는 CLAUDE.md 전수 + .claude/rules/*.md 가 대상이다.

출력은 판정 결과가 아니라 후보 목록이다 — 규약인지 이력인지는 문서를 읽고 사람이 정한다.
"""
from __future__ import annotations

import collections
import pathlib
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

# ── 프로젝트 설정 (설치 후 여기만 고친다) ─────────────────────────────
# 리포지토리 루트 — 이 스크립트가 <root>/.claude/skills/docs-optimization/ 에 있다고 본다.
ROOT = pathlib.Path(__file__).resolve().parents[3]
# 코드 루트. 죽은 심볼·배치 이탈 판정이 이 아래 .cs 를 읽는다.
#   범용: "Assets"    게임 코드가 한 폴더에 모인 프로젝트: "Client/Assets/Game/Scripts"
CODE_SUBDIR = "Assets"
# 애셋 파일명을 수집할 git 경로 — 프리팹·씬 이름이 "죽은 심볼"로 잡히지 않게 한다.
ASSET_SUBDIR = "Assets"
# ──────────────────────────────────────────────────────────────────

CODE = ROOT / CODE_SUBDIR

# 백틱 안의 코드 식별자.
SYMBOL = re.compile(r"`([A-Za-z_][A-Za-z0-9_]*)`")
# 이력 서술 신호 — 날짜가 박힌 경위, 폐기된 대안, 되돌린 기록.
HISTORY = re.compile(r"20\d\d-\d\d-\d\d|폐기|되돌렸|철회했|이관됐|였다가|시도했")
# 죽은 심볼과 겹치면 강한 신호 — 없어진 것을 설명하는 문장이다.
DISCARDED = re.compile(r"폐기|제거됐|제거했|삭제됐|철회|없앴|사라졌|더 이상")
# 배치 이탈 판정 조건 — 표본이 작거나 절이 작으면 옮겨도 이득이 없어 판정하지 않는다.
# 참조 수가 한 자리면 심볼 몇 개가 비율을 좌우해 판정이 흔들린다(실측: 같은 절이 66%→81%).
MIN_REFS = 8
MIN_SECTION_BYTES = 3000


def code_words() -> set[str]:
    """코드 식별자 + 애셋 파일명 집합. 죽은 심볼 판정의 기준이다.

    애셋 이름(프리팹·씬·아틀라스)을 넣어야 `CM_Battle_Global` 같은 오브젝트 이름이
    "코드에 없다"로 잡히지 않는다.
    """
    words: set[str] = set()
    for path in CODE.rglob("*.cs"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        words.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text))
    listed = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", ASSET_SUBDIR],
        capture_output=True, text=True, encoding="utf-8",
    ).stdout
    for line in listed.splitlines():
        path = pathlib.PurePosixPath(line)
        words.add(path.stem)
        # 셰이더 내부 식별자(ComputeFogFactor·SV_Depth 등)는 .cs에 없어 오탐이 된다.
        if path.suffix in (".shader", ".hlsl", ".cginc", ".compute"):
            text = (ROOT / line).read_text(encoding="utf-8", errors="ignore")
            words.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text))
    return words


def symbol_dirs() -> dict[str, list[str]]:
    """파일명 → 그 파일이 있는 디렉토리. 배치 이탈 판정에 쓴다."""
    idx: dict[str, list[str]] = collections.defaultdict(list)
    for path in CODE.rglob("*.cs"):
        idx[path.stem].append(path.parent.relative_to(CODE).as_posix())
    return idx


def targets(argv: list[str]) -> list[pathlib.Path]:
    if argv:
        return [pathlib.Path(a) for a in argv]
    out = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "*CLAUDE.md", ".claude/rules/*.md"],
        capture_output=True, text=True, encoding="utf-8",
    ).stdout
    return [ROOT / line for line in out.splitlines() if line]


def sections(text: str):
    """h2/h3 단위로 (제목, 시작행, 본문)을 낸다."""
    title, start, buf = "(머리말)", 1, []
    for i, line in enumerate(text.splitlines(), 1):
        if line.startswith("## ") or line.startswith("### "):
            if buf:
                yield title, start, "\n".join(buf)
            title, start, buf = line.lstrip("# ").strip(), i, [line]
        else:
            buf.append(line)
    if buf:
        yield title, start, "\n".join(buf)


def doc_dir_of(doc: pathlib.Path) -> str:
    """문서가 놓인 디렉토리를 Scripts 기준 상대경로로. 배치 이탈 비교용."""
    rel = doc.parent.resolve().relative_to(ROOT) if ROOT in doc.parent.resolve().parents or doc.parent.resolve() == ROOT else doc.parent
    return str(rel).replace("\\", "/").replace(CODE_SUBDIR + "/", "").replace(CODE_SUBDIR, "")


def report_dead(text: str, words: set[str]) -> None:
    found: dict[str, list[int]] = collections.defaultdict(list)
    starred: set[str] = set()
    for i, line in enumerate(text.splitlines(), 1):
        # `>` 인용은 포인터·출처 줄이라 그 심볼은 이 문서가 다루는 대상이 아니다.
        if line.lstrip().startswith(">"):
            continue
        for sym in SYMBOL.findall(line):
            # 소문자 단어·짧은 토큰은 산문일 가능성이 커서 제외한다.
            if len(sym) > 3 and any(c.isupper() for c in sym) and sym not in words:
                found[sym].append(i)
                if DISCARDED.search(line):
                    starred.add(sym)
    if not found:
        return
    print("  [죽은 심볼] 코드·애셋에 없는 식별자 (★ = 그 문장이 폐기를 말한다 — 정리 1순위)")
    for sym, lines in sorted(found.items(), key=lambda kv: (kv[0] not in starred, -len(kv[1]))):
        mark = "★ " if sym in starred else "  "
        print(f"    {mark}{sym}  행 {lines[0]}" + (f" 외 {len(lines) - 1}곳" if len(lines) > 1 else ""))


def report_placement(doc: pathlib.Path, text: str, dirs: dict[str, list[str]]) -> None:
    here = doc_dir_of(doc)
    rows = []
    for title, start, body in sections(text):
        cnt: collections.Counter = collections.Counter()
        for sym in set(SYMBOL.findall(body)):
            for d in dirs.get(sym, []):
                cnt[d] += 1
        total = sum(cnt.values())
        if total < MIN_REFS or len(body.encode("utf-8")) < MIN_SECTION_BYTES:
            continue
        top, n = cnt.most_common(1)[0]
        if n * 2 >= total and top != here:
            rows.append((len(body.encode("utf-8")), title, start, top, 100 * n // total, total))
    if not rows:
        return
    print("  [배치 이탈] 참조 코드가 다른 폴더에 몰린 절 (n=참조 수, 작을수록 판정이 흔들린다)")
    for size, title, start, top, pct, total in sorted(rows, reverse=True):
        print(f"    {size:6,}B  행 {start:5d}  {title[:34]:36s} -> {top} ({pct}%, n={total})")


def report_history(text: str) -> None:
    # `>` 인용은 다른 문서를 가리키는 포인터 관례라 이력이 아니다.
    hits = [
        (i, line.strip())
        for i, line in enumerate(text.splitlines(), 1)
        if HISTORY.search(line) and not line.lstrip().startswith(">")
    ]
    if not hits:
        return
    print(f"  [이력 문장] {len(hits)}곳")
    for i, line in hits[:12]:
        print(f"    행 {i:5d}  {line[:90]}")
    if len(hits) > 12:
        print(f"    ... 외 {len(hits) - 12}곳")


def report_duplicates(docs: dict[pathlib.Path, str]) -> None:
    seen: dict[str, list[str]] = collections.defaultdict(list)
    for doc, text in docs.items():
        for para in text.split("\n\n"):
            key = re.sub(r"\s+", " ", para).strip()
            if len(key) >= 120:
                seen[key].append(doc.name)
    dups = {k: v for k, v in seen.items() if len(set(v)) > 1}
    if not dups:
        return
    print("\n## 문서 간 중복 문단")
    for key, where in dups.items():
        print(f"  {' / '.join(sorted(set(where)))}: {key[:90]}")


def main() -> int:
    words = code_words()
    dirs = symbol_dirs()
    loaded = {}
    for doc in targets(sys.argv[1:]):
        text = doc.read_text(encoding="utf-8")
        loaded[doc] = text
        rel = str(doc.resolve()).replace(str(ROOT) + "\\", "").replace("\\", "/")
        print(f"\n## {rel}  ({len(text.encode('utf-8')):,} bytes)")
        report_dead(text, words)
        report_placement(doc, text, dirs)
        report_history(text)
    report_duplicates(loaded)
    return 0


if __name__ == "__main__":
    sys.exit(main())
