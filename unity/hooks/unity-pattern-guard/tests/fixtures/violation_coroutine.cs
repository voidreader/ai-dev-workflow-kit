using System.Collections;
public class Foo {
    public void A() { StartCoroutine(Bar()); }
    private IEnumerator Bar() { yield return null; }
}
