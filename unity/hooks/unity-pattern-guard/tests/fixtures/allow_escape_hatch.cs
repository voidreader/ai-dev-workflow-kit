public class Foo {
    public void Bar() {
        var cam = Camera.main; // claude-allow: camera-main
        var go = Resources.Load<UnityEngine.Object>("x"); // 여기는 차단되어야 함
    }
}
