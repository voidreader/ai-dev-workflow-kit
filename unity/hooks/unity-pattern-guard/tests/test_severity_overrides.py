"""SEVERITY_OVERRIDES — config.py 만으로 룰 심각도를 바꿀 수 있는지 검증.

rules.py 는 임포트 시점에 config 값을 읽어 목록을 만든다. 따라서 덮어쓰기를
바꾼 뒤에는 reload 가 필요하고, 테스트가 끝나면 원래 값으로 되돌려 다른
테스트 모듈에 영향을 주지 않아야 한다.
"""

import importlib

import pytest

import config
import rules


@pytest.fixture
def with_overrides():
    """덮어쓰기를 적용한 rules 모듈을 돌려주고, 끝나면 원상복구한다."""
    original = getattr(config, "SEVERITY_OVERRIDES", {})

    def _apply(overrides):
        config.SEVERITY_OVERRIDES = overrides
        return importlib.reload(rules)

    yield _apply

    config.SEVERITY_OVERRIDES = original
    importlib.reload(rules)


@pytest.mark.skipif(
    bool(getattr(config, "SEVERITY_OVERRIDES", {})),
    reason=(
        "config.SEVERITY_OVERRIDES 가 비어있지 않다 — 이 단언은 kit 기본값({})을 전제로 하므로 "
        "커스터마이즈된 설치본(바로 이 기능을 쓰라고 만든 설정)에서는 항상 실패한다. "
        "설치본에서 실제로 검증해야 할 것은 '커스터마이즈했을 때도 스위트가 통과하는가'지, "
        "'커스터마이즈하지 않았는가'가 아니므로 여기서는 skip 한다."
    ),
)
def test_default_overrides_are_empty():
    assert config.SEVERITY_OVERRIDES == {}


def test_block_rule_can_be_demoted_to_warn(with_overrides):
    reloaded = with_overrides({"coroutine": "warn"})

    assert all(r.id != "coroutine" for r in reloaded.BLOCK_RULES)
    assert any(r.id == "coroutine" and r.severity == "warn" for r in reloaded.WARN_RULES)
    assert len(reloaded.ALL_RULES) == 8


def test_warn_rule_can_be_promoted_to_block(with_overrides):
    reloaded = with_overrides({"fake-null": "block"})

    assert any(r.id == "fake-null" and r.severity == "block" for r in reloaded.BLOCK_RULES)
    assert all(r.id != "fake-null" for r in reloaded.WARN_RULES)


def test_demoted_rule_reports_warn_severity_in_violations(with_overrides):
    reloaded = with_overrides({"camera-main": "warn"})
    source = "public class Foo { void A() { var c = Camera.main; } }"

    from masker import mask

    found = [v for v in reloaded.find_violations(source, mask(source)) if v.rule_id == "camera-main"]
    assert found and all(v.severity == "warn" for v in found)


def test_unknown_rule_id_raises(with_overrides):
    with pytest.raises(ValueError, match="camera_main"):
        with_overrides({"camera_main": "warn"})  # 밑줄 오타 — 조용히 무시되면 안 된다


def test_invalid_severity_raises(with_overrides):
    with pytest.raises(ValueError, match="fatal"):
        with_overrides({"camera-main": "fatal"})
