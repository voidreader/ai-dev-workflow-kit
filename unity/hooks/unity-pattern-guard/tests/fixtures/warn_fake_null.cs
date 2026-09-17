public class Foo {
    public UnityEngine.Object Target;
    public UnityEngine.Object Fallback;
    public void Bar() {
        var x = Target ?? Fallback;
        if (Target is null) { }
    }
}
