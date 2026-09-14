// unity-ui-architecture 참조 코드. 네임스페이스와 이름을 프로젝트에 맞춰 바꾼다.
// 두는 곳: 프레젠테이션 어셈블리. 루트 Canvas 프리팹의 "Frame" 오브젝트에 붙인다.

using UnityEngine;

namespace Game.UI
{
    /// <summary>세로 화면의 가로 논리 크기를 9:16으로 제한한다. 세로는 부모 전체를 쓴다.</summary>
    /// <remarks>
    /// 폰(9:16~9:20)에서는 클램프가 발동하지 않아 <c>sizeDelta</c>가 0이다. 가로가 넓은
    /// 태블릿에서만 좌우에 여백이 생긴다. 그 여백에 무엇을 보일지는 프로젝트가 정한다.
    /// 프리팹 모드에서도 같은 결과를 보이려고 <c>[ExecuteAlways]</c>를 쓴다. 이게 없으면
    /// 편집 화면에서만 클램프가 빠져 런타임과 갈린다.
    /// </remarks>
    [ExecuteAlways]
    [RequireComponent(typeof(RectTransform))]
    public sealed class UiFrame : MonoBehaviour
    {
        private void OnEnable() => Apply();
        private void Update() => Apply();

        /// <summary>
        /// 가로 클램프를 적용한다. 값이 달라 실제로 썼으면 true.
        /// bool을 반환하는 이유는 아래 가드가 테스트에서 관측 가능해야 하기 때문이다.
        /// void로 두면 가드를 지워도 결과가 같아 테스트가 통과해버린다.
        /// </summary>
        public bool Apply()
        {
            var rect = (RectTransform)transform;
            var parent = rect.parent as RectTransform;
            if (parent == null) return false;
            float parentWidth = parent.rect.width;
            float width = UiFrameLayout.ClampWidth(parentWidth, parent.rect.height);
            float delta = width - parentWidth;
            // 값이 같으면 대입하지 않는다. 매 프레임 대입하면 값이 같아도 레이아웃이 더티가 된다.
            if (Mathf.Approximately(rect.sizeDelta.x, delta)) return false;
            rect.sizeDelta = new Vector2(delta, rect.sizeDelta.y);
            return true;
        }
    }
}
