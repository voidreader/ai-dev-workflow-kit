from masker import mask
from rules import find_violations, BLOCK_RULES, WARN_RULES

def _scan(text: str):
    masked = mask(text)
    return find_violations(text, masked)

def test_block_rule_count():
    assert len(BLOCK_RULES) == 5

def test_warn_rule_count():
    assert len(WARN_RULES) == 3

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
