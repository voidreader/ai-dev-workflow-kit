// unity-ui-architecture 참조 코드. 네임스페이스와 이름을 프로젝트에 맞춰 바꾼다.
// 두는 곳: UnityEngine을 참조하지 않는 어셈블리 (에디터 없이 dotnet으로 테스트하려고).

namespace Game.UI
{
    /// <summary>세로 화면에서 가로만 목표 비율로 제한한다. 세로는 건드리지 않는다.</summary>
    /// <remarks>
    /// 폰(9:16~9:20)에서는 <c>parentHeight * PortraitAspect</c>가 항상 <c>parentWidth</c>보다 커서
    /// 클램프가 발동하지 않는다. 가로가 넓은 태블릿에서만 걸린다.
    /// </remarks>
    public static class UiFrameLayout
    {
        /// <summary>세로 화면의 목표 가로/세로 비율. 9:16이다.</summary>
        public const float PortraitAspect = 9f / 16f;

        public static float ClampWidth(float parentWidth, float parentHeight, float aspect)
        {
            if (parentWidth <= 0f || parentHeight <= 0f) return 0f;
            if (aspect <= 0f) return parentWidth;
            float max = parentHeight * aspect;
            return parentWidth < max ? parentWidth : max;
        }

        public static float ClampWidth(float parentWidth, float parentHeight) =>
            ClampWidth(parentWidth, parentHeight, PortraitAspect);
    }
}
