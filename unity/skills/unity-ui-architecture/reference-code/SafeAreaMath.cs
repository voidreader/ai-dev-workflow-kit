// unity-ui-architecture 참조 코드. 네임스페이스와 이름을 프로젝트에 맞춰 바꾼다.
// 두는 곳: UnityEngine을 참조하지 않는 어셈블리.

namespace Game.UI
{
    /// <summary>safe area 인셋의 정상화. 픽셀·월드 어느 단위로든 쓴다.</summary>
    public static class SafeAreaMath
    {
        /// <summary>상하 인셋 합의 상한(화면 높이 대비). 이상한 값이 와도 영역이 무너지지 않게 막는다.</summary>
        public const float MaxInsetRatio = 0.4f;

        /// <summary>음수를 지우고, 합이 한도를 넘으면 둘을 같은 비율로 줄인다.</summary>
        public static void ClampInsets(float height, ref float topInset, ref float bottomInset)
        {
            if (topInset < 0f) topInset = 0f;
            if (bottomInset < 0f) bottomInset = 0f;

            float limit = height * MaxInsetRatio;
            float sum = topInset + bottomInset;
            if (sum <= limit || sum <= 0f) return;

            float ratio = limit / sum;
            topInset *= ratio;
            bottomInset *= ratio;
        }
    }
}
