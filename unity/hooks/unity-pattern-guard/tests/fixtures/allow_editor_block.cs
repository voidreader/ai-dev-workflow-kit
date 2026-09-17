public class Foo
{
#if UNITY_EDITOR
    public void EditorOnly()
    {
        var x = Resources.Load<UnityEngine.Object>("path");
        var cam = Camera.main;
    }
#endif
    public void Runtime() { }
}
