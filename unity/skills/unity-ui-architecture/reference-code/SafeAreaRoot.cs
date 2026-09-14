// unity-ui-architecture 참조 코드. 네임스페이스와 이름을 프로젝트에 맞춰 바꾼다.
// 두는 곳: 프레젠테이션 어셈블리.
//
// 붙이는 위치가 규칙의 전부다.
//  - 붙인다      : 버튼·텍스트가 노치에 걸리는 일반 패널.
//  - 붙이지 않는다: 전체 화면 딤(노치 뒤까지 덮어야 한다).
//  - 붙이지 않는다: 이미 safe area가 반영된 좌표를 런타임에 받는 오브젝트(인셋 이중 적용).
// 상위 하나로 통합하지 마라.

using UnityEngine;

namespace Game.UI
{
    /// <summary>프리팹의 지정 영역에 기기 safe area를 적용한다.</summary>
    [RequireComponent(typeof(RectTransform))]
    public sealed class SafeAreaRoot : MonoBehaviour
    {
        private Rect lastArea;

        private void OnEnable() => Apply();

        private void Update()
        {
            if (SafeArea.PixelRect() != lastArea) Apply();
        }

        public void Apply()
        {
            var area = SafeArea.PixelRect();
            var rect = (RectTransform)transform;
            float width = Mathf.Max(1, Screen.width);
            float height = Mathf.Max(1, Screen.height);
            rect.anchorMin = new Vector2(area.xMin / width, area.yMin / height);
            rect.anchorMax = new Vector2(area.xMax / width, area.yMax / height);
            rect.offsetMin = rect.offsetMax = Vector2.zero;
            lastArea = area;
        }
    }
}
