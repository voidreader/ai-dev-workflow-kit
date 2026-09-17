public class Foo
{
    private string a = "Resources.Load(\"x\")";
    private string b = @"Camera.main literal";
    private string c = $"prefix {nameof(Foo)} suffix";
    private string d = $@"verbatim interp {1+1}";
}
