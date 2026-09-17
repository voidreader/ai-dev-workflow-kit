import sys
from pathlib import Path

import pytest

# 훅 모듈(config/masker/rules)을 패키지 없이 임포트할 수 있게 한다 —
# 디렉토리명에 하이픈이 있어 패키지로는 임포트되지 않는다.
HOOK_DIR = Path(__file__).resolve().parent.parent
if str(HOOK_DIR) not in sys.path:
    sys.path.insert(0, str(HOOK_DIR))

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture
def fixture_text():
    def _load(name: str) -> str:
        return (FIXTURES / name).read_text(encoding="utf-8")
    return _load
