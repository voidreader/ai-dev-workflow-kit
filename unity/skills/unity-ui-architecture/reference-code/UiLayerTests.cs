// unity-ui-architecture 참조 코드. 경로·패널 이름·타입을 프로젝트에 맞춰 바꾼다.
// 두는 곳: 에디터 테스트 어셈블리(EditMode).
//
// 프리팹 에셋을 직접 읽으므로 플레이 모드가 필요 없다. 빠르고, 저작값 자체를 검사한다.
//
// 중요: 이 단언들이 "실제로 실패할 수 있는지" 먼저 확인한다. 대상을 잠깐 망가뜨리고
// (계층 순서 바꾸기, 컴포넌트 떼기, 스프라이트를 null로) 빨간불이 나오는지 본다.
// 관측할 수 없는 것은 단언할 수 없다 — 필요하면 프로덕션 코드 시그니처를 바꾼다.

using System.Collections.Generic;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace Game.UI.Tests
{
    public class UiLayerTests
    {
        // --- 프로젝트에 맞춰 고칠 값 ---
        private const string UiRootPath = "Assets/Content/UI/UiRoot.prefab";
        private const string PanelDir = "Assets/Content/UI/";

        private static readonly string[] Screens = { "GameControls", "LobbyPanel" };
        private static readonly string[] Popups = { "SettingsPanel", "ClearPanel" };
        private static readonly string[] Overlays = { "InputBlocker", "Toast", "DimPanel" };
        // --------------------------------

        private static Transform Root() =>
            AssetDatabase.LoadAssetAtPath<GameObject>(UiRootPath).transform;

        [Test]
        public void 루트_아래_자식은_Frame과_Overlays_둘뿐이다()
        {
            // Overlays는 전체 화면을 덮어야 하므로 Frame의 가로 클램프 밖에 있다.
            var root = Root();
            Assert.That(root.childCount, Is.EqualTo(2), "루트에는 Frame, Overlays만 있어야 합니다.");
            Assert.That(root.GetChild(0).name, Is.EqualTo("Frame"));
            Assert.That(root.GetChild(1).name, Is.EqualTo("Overlays"));
        }

        [Test]
        public void Frame에는_UiFrame이_붙어_있다()
        {
            Assert.That(Root().Find("Frame").GetComponent<UiFrame>(), Is.Not.Null);
        }

        [Test]
        public void Frame_아래_레이어_두_개가_정해진_순서로_있다()
        {
            var frame = Root().Find("Frame");
            Assert.That(frame.childCount, Is.EqualTo(2));
            Assert.That(frame.GetChild(0).name, Is.EqualTo("Screens"));
            Assert.That(frame.GetChild(1).name, Is.EqualTo("Popups"));
        }

        [Test]
        public void 각_패널이_정해진_레이어에_정해진_순서로_있다()
        {
            var root = Root();
            AssertChildren(root.Find("Frame/Screens"), Screens);
            AssertChildren(root.Find("Frame/Popups"), Popups);
            AssertChildren(root.Find("Overlays"), Overlays);
        }

        [Test]
        public void 레이어_컨테이너는_전체_스트레치다()
        {
            var root = Root();
            foreach (var path in new[] { "Frame", "Frame/Screens", "Frame/Popups", "Overlays" })
            {
                var rect = (RectTransform)root.Find(path);
                Assert.That(rect.anchorMin, Is.EqualTo(Vector2.zero), path);
                Assert.That(rect.anchorMax, Is.EqualTo(Vector2.one), path);
                Assert.That(rect.anchoredPosition, Is.EqualTo(Vector2.zero), path);
                Assert.That(rect.pivot, Is.EqualTo(new Vector2(0.5f, 0.5f)), path);
            }
            // Frame의 sizeDelta.x는 UiFrame이 채운다. 폰 비율에서는 0이다.
            foreach (var path in new[] { "Frame/Screens", "Frame/Popups", "Overlays" })
                Assert.That(((RectTransform)root.Find(path)).sizeDelta, Is.EqualTo(Vector2.zero), path);
        }

        [Test]
        public void 루트_프리팹_앵커가_전체_스트레치로_저장되어_있다()
        {
            // 런타임에는 Overlay Canvas가 덮어쓰므로 아무 값이어도 같다. 그러나 프리팹 모드에서는
            // 중첩 Canvas가 되어 저장값이 그대로 쓰인다. 기본값(중앙 고정 100x100)으로 저장돼
            // 있으면 루트도 하위 패널도 전부 100x100으로 눌린다.
            var rect = (RectTransform)Root();
            Assert.That(rect.anchorMin, Is.EqualTo(Vector2.zero));
            Assert.That(rect.anchorMax, Is.EqualTo(Vector2.one));
            Assert.That(rect.offsetMin, Is.EqualTo(Vector2.zero));
            Assert.That(rect.offsetMax, Is.EqualTo(Vector2.zero));
        }

        [Test]
        public void 카드_자식들은_세로로_겹치지_않는다()
        {
            // 실제 사고에서 나온 단언이다. 카드에 버튼을 추가하며 기존 제목과 같은 세로 구간에
            // 앵커를 잡았고, 불투명한 9-slice가 제목을 완전히 덮었다. 컴파일도 되고 기존
            // 테스트도 전부 통과했다. 최종 리뷰 전까지 아무도 몰랐다.
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PanelDir + "SettingsPanel.prefab");
            var card = prefab.transform.Find("Card");
            Assert.That(card, Is.Not.Null);

            var spans = new List<(string name, float min, float max)>();
            for (int i = 0; i < card.childCount; i++)
            {
                var rect = (RectTransform)card.GetChild(i);
                spans.Add((rect.name, rect.anchorMin.y, rect.anchorMax.y));
            }

            for (int i = 0; i < spans.Count; i++)
                for (int j = i + 1; j < spans.Count; j++)
                {
                    bool overlaps = spans[i].min < spans[j].max && spans[j].min < spans[i].max;
                    Assert.That(overlaps, Is.False,
                        spans[i].name + " [" + spans[i].min + ", " + spans[i].max + "] 와 "
                        + spans[j].name + " [" + spans[j].min + ", " + spans[j].max + "] 가 겹칩니다. "
                        + "나중에 그려지는 쪽이 앞의 것을 덮습니다.");
                }
        }

        [Test]
        public void 런타임_스킨_주입이_남아_있지_않다()
        {
            // 주석으로 "쓰지 마세요"만 남기면 6개월 뒤에 다시 생긴다. 부재를 단언한다.
            var type = typeof(UiRootController); // 프로젝트의 루트 UI 컨트롤러 타입
            Assert.That(type.GetMethod("SetSkin"), Is.Null,
                "SetSkin은 프리팹 저작값을 덮어쓰므로 제거되었습니다.");
            foreach (var name in new[] { "ingamePanels", "homeIcon", "settingsIcon" })
                Assert.That(type.GetField(name,
                    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic),
                    Is.Null, name + " 필드가 남아 있습니다.");
        }

        [Test]
        public void 패널_스프라이트가_프리팹에_구워져_있다()
        {
            // Is.Not.SameAs(옛_스프라이트)만 단언하면 null이어도 통과한다. 개수를 센다.
            // 그래야 과소 굽기(옛 값 잔존)와 과대 굽기(아이콘까지 덮음)를 둘 다 잡는다.
            var panel = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Art/UI/panel-cream.png");
            var old = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Art/UI/panel-old.png");
            Assert.That(panel, Is.Not.Null);

            var expected = new Dictionary<string, int>
            {
                { "GameControls", 6 },
                { "ClearPanel", 4 },
                { "SettingsPanel", 6 },
            };

            foreach (var pair in expected)
            {
                string path = PanelDir + pair.Key + ".prefab";
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                Assert.That(prefab, Is.Not.Null, path);
                int count = 0;
                foreach (var image in prefab.GetComponentsInChildren<UnityEngine.UI.Image>(true))
                {
                    Assert.That(image.sprite, Is.Not.SameAs(old),
                        path + " 의 " + image.name + " 에 옛 스프라이트가 남아 있습니다.");
                    if (ReferenceEquals(image.sprite, panel)) count++;
                }
                Assert.That(count, Is.EqualTo(pair.Value),
                    path + " 의 패널 스프라이트 개수가 다릅니다. 과소 굽기이거나 과대 굽기입니다.");
            }
        }

        private static void AssertChildren(Transform parent, params string[] expected)
        {
            Assert.That(parent, Is.Not.Null);
            Assert.That(parent.childCount, Is.EqualTo(expected.Length), parent.name);
            for (int i = 0; i < expected.Length; i++)
                Assert.That(parent.GetChild(i).name, Is.EqualTo(expected[i]), parent.name + "[" + i + "]");
        }
    }
}
