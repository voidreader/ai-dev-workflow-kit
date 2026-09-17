from masker import mask

def test_mask_preserves_length():
    src = "var x = 1; // comment\nvar y = 2;"
    masked = mask(src)
    assert len(masked) == len(src)
    assert masked.count("\n") == src.count("\n")

def test_mask_line_comment(fixture_text):
    src = fixture_text("allow_comment.cs")
    masked = mask(src)
    assert "Resources.Load" not in masked
    assert "Camera.main" not in masked
    assert "public class Foo" in masked
    assert "public void Bar()" in masked

def test_mask_string_literals(fixture_text):
    src = fixture_text("allow_string_literal.cs")
    masked = mask(src)
    assert "Resources.Load" not in masked
    assert "Camera.main" not in masked
    assert "private string a" in masked

def test_mask_editor_block(fixture_text):
    src = fixture_text("allow_editor_block.cs")
    masked = mask(src)
    assert "Resources.Load" not in masked
    assert "Camera.main" not in masked
    assert "public void Runtime()" in masked
    # 주의: #if UNITY_EDITOR ~ #endif 블록 전체가 마스킹되므로
    # EditorOnly 메서드 시그니처도 사라지는 게 정상이다.

def test_mask_keeps_code_outside():
    src = 'var a = "literal"; var b = Camera.main;'
    masked = mask(src)
    assert "literal" not in masked
    assert "Camera.main" in masked  # 문자열 밖이므로 유지
