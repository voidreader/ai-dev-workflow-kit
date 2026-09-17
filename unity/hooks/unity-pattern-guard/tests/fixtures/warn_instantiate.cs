using UnityEngine;
public class Foo : MonoBehaviour {
    public GameObject Prefab;
    public void Bar() { Instantiate(Prefab); Destroy(gameObject); }
}
