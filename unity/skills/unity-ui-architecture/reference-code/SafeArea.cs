// unity-ui-architecture 참조 코드. 네임스페이스와 이름을 프로젝트에 맞춰 바꾼다.
// 두는 곳: 프레젠테이션 어셈블리.

using UnityEngine;

namespace Game.UI
{
    /// <summary>
    /// Screen.safeArea에서 인셋을 픽셀 영역으로 읽는다.
    /// 에디터와 WebGL에서는 인셋이 항상 0이다. 눈으로 볼 때는 <see cref="DebugInsetPx"/>로
    /// 강제하고, 최종 확인은 노치 있는 실기로 한다.
    /// </summary>
    public static class SafeArea
    {
        /// <summary>강제 인셋(픽셀). null이면 Screen.safeArea를 쓴다. x가 위, y가 아래.</summary>
        public static Vector2? DebugInsetPx;

        /// <summary>좌우를 포함한 화면 안전 영역 픽셀 사각형.</summary>
        public static Rect PixelRect()
        {
            if (DebugInsetPx.HasValue)
            {
                float top = DebugInsetPx.Value.x;
                float bottom = DebugInsetPx.Value.y;
                SafeAreaMath.ClampInsets(Screen.height, ref top, ref bottom);
                return new Rect(0f, bottom, Screen.width, Mathf.Max(0f, Screen.height - top - bottom));
            }
            return Screen.safeArea;
        }

        /// <summary>합이 화면 높이의 한도를 넘지 않도록 이미 줄인 값을 준다.</summary>
        public static void InsetPixels(out float top, out float bottom)
        {
            float height = Screen.height;
            var area = PixelRect();
            top = height - area.yMax;
            bottom = area.yMin;
            if (height <= 0f) { top = 0f; bottom = 0f; return; }
            SafeAreaMath.ClampInsets(height, ref top, ref bottom);
        }
    }
}
