import pytest

import config
from masker import mask
from rules import find_violations, BLOCK_RULES, WARN_RULES

def _scan(text: str):
    masked = mask(text)
    return find_violations(text, masked)

# 아래 skipif 로 걸어 둔 단언들은 kit 기본 심각도를 전제로 한다. 설치본이
# config.SEVERITY_OVERRIDES 로 심각도를 커스터마이즈하면 이 전제 자체가 깨지므로
# 구조적으로 통과할 수 없다 — 코드가 잘못된 게 아니라 단언이 kit 기본값에
# 못박혀 있는 것이다. 이 가드가 없으면 README 가 약속한 "설정을 바꿔도
# pytest tests 가 그대로 통과해야 한다"가 거짓이 되어, 커스터마이즈한
# 프로젝트에서는 항상 실패가 보이고 결국 아무도 이 스위트를 신뢰하지 않게 된다.
# kit 저장소 자체의 기본값은 빈 딕셔너리라 아래 조건은 여기서는 항상 False —
# 즉 kit 기본값에 대한 커버리지는 그대로 유지된다.
#
# 조건은 두 갈래로 나뉜다:
#   - _CUSTOMIZED (전역) — "룰 총 개수"처럼 *어떤* override 로도 값이 바뀌는 단언에만 쓴다.
#   - _skip_if_rule_overridden(rule_id) (룰 단위) — 특정 룰 하나의 기본 심각도만 보는
#     단언에 쓴다. 여기에 전역 조건을 잘못 쓰면, 그 테스트와 무관한 다른 룰을
#     override 했을 뿐인데도 함께 꺼진다 — 실제로 resources-load 와 coroutine 만
#     강등한 설치본에서 fake-null 의 warn 여부를 검증하는 유일한 테스트가 무관한
#     이유로 꺼지는 사고가 있었다. 앞으로 룰별 심각도를 단언하는 테스트를 추가할 때도
#     반드시 _skip_if_rule_overridden 을 써라 — 전역 조건을 재사용하지 마라.
_OVERRIDES = getattr(config, "SEVERITY_OVERRIDES", {})
_CUSTOMIZED = bool(_OVERRIDES)
_GLOBAL_SKIP_REASON = (
    "config.SEVERITY_OVERRIDES 가 비어있지 않다 — 룰 총 개수는 어떤 override 로도 바뀌므로 "
    "kit 기본 개수를 전제로 한 이 단언은 커스터마이즈된 설치본에서 구조적으로 통과할 수 "
    "없어 skip 한다."
)


def _skip_if_rule_overridden(rule_id: str):
    """특정 룰 하나의 기본 심각도만 전제로 하는 단언 전용 skip 조건.

    해당 룰 id 가 config.SEVERITY_OVERRIDES 에 있을 때만 skip 하므로, 무관한
    다른 룰의 override 는 이 테스트를 건드리지 않는다."""
    reason = (
        f"config.SEVERITY_OVERRIDES 에 '{rule_id}' 가 있다 — 이 단언은 '{rule_id}' 의 "
        f"kit 기본 심각도를 전제로 하므로, 그 룰만 override 된 설치본에서 skip 한다."
    )
    return pytest.mark.skipif(rule_id in _OVERRIDES, reason=reason)


@pytest.mark.skipif(_CUSTOMIZED, reason=_GLOBAL_SKIP_REASON)
def test_block_rule_count():
    assert len(BLOCK_RULES) == 5

@pytest.mark.skipif(_CUSTOMIZED, reason=_GLOBAL_SKIP_REASON)
def test_warn_rule_count():
    assert len(WARN_RULES) == 3

@_skip_if_rule_overridden("resources-load")
def test_resources_load_blocks(fixture_text):
    v = _scan(fixture_text("violation_resources_load.cs"))
    assert any(x.rule_id == "resources-load" and x.severity == "block" for x in v)

def test_camera_main_blocks(fixture_text):
    v = _scan(fixture_text("violation_camera_main.cs"))
    assert any(x.rule_id == "camera-main" for x in v)

def test_gameobject_find_blocks(fixture_text):
    v = _scan(fixture_text("violation_gameobject_find.cs"))
    ids = {x.rule_id for x in v}
    assert "gameobject-find" in ids

def test_transform_find_blocks(fixture_text):
    v = _scan(fixture_text("violation_transform_find.cs"))
    assert any(x.rule_id == "transform-find" for x in v)

def test_coroutine_blocks(fixture_text):
    v = _scan(fixture_text("violation_coroutine.cs"))
    assert any(x.rule_id == "coroutine" for x in v)

@_skip_if_rule_overridden("fake-null")
def test_fake_null_warns(fixture_text):
    v = _scan(fixture_text("warn_fake_null.cs"))
    assert any(x.rule_id == "fake-null" and x.severity == "warn" for x in v)

def test_instantiate_warns(fixture_text):
    v = _scan(fixture_text("warn_instantiate.cs"))
    assert any(x.rule_id == "instantiate-destroy" for x in v)

def test_trigger_stay_warns(fixture_text):
    v = _scan(fixture_text("warn_trigger_stay.cs"))
    assert any(x.rule_id == "trigger-stay" for x in v)

def test_no_violation_in_clean_code():
    v = _scan("public class Foo { public int X; }")
    assert v == []

def test_escape_hatch(fixture_text):
    v = _scan(fixture_text("allow_escape_hatch.cs"))
    rule_ids = [x.rule_id for x in v]
    assert "camera-main" not in rule_ids
    assert "resources-load" in rule_ids

def test_masked_content_not_matched(fixture_text):
    v = _scan(fixture_text("allow_comment.cs"))
    assert v == []
