// unity-ui-architecture 참조 코드. 네임스페이스·경로·메뉴 이름을 프로젝트에 맞춰 바꾼다.
// 두는 곳: 에디터 전용 어셈블리(Assets/.../Editor/).
//
// 하는 일 두 가지 (메뉴도 두 개다):
//  1. UI 프리팹 편집 환경 준비 — 루트 Canvas와 "같은 값"의 Canvas를 가진 씬을 만들고
//     EditorSettings의 m_PrefabUIEnvironment로 지정한다. 그래야 프리팹을 열었을 때
//     런타임과 같은 크기로 보인다.
//  2. 게임 뷰 기준 해상도 프리셋 추가 — 1080x1920 고정 프리셋을 드롭다운에 넣는다.

using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace Game.UI.Editor
{
    public static class UiPrefabEnvironmentMenu
    {
        // --- 프로젝트에 맞춰 고칠 값 ---
        public const string ScenePath = "Assets/Scenes/UiPrefabEnvironment.unity";
        private const float ReferenceWidth = 1080f;
        private const float ReferenceHeight = 1920f;
        private const string PresetName = "Portrait 9:16";
        // --------------------------------

        [MenuItem("Game/프리뷰/UI 프리팹 편집 환경 준비")]
        public static void Prepare()
        {
            EnsureScene();
            AssignToEditorSettings();
            Debug.Log("UI 프리팹 편집 환경을 준비했습니다: " + ScenePath);
        }

        public static void EnsureScene()
        {
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) != null) return;

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            try
            {
                var canvasRoot = new GameObject("UI Environment Canvas",
                    typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
                SceneManager.MoveGameObjectToScene(canvasRoot, scene);
                canvasRoot.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;

                // 루트 Canvas와 같은 값이어야 한다. 중첩 Canvas는 자기 CanvasScaler를 무시하고
                // 부모의 scaleFactor를 상속하므로, 값이 다르면 루트 프리팹을 열 때와
                // 패널 하나를 단독으로 열 때의 크기가 달라진다.
                var scaler = canvasRoot.GetComponent<CanvasScaler>();
                scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
                scaler.referenceResolution = new Vector2(ReferenceWidth, ReferenceHeight);
                scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
                scaler.matchWidthOrHeight = .5f;

                // 카메라 설정은 프로젝트의 런타임 설정과 맞춘다(배경색·투영·URP 데이터 등).
                var cameraRoot = new GameObject("Main Camera", typeof(Camera));
                SceneManager.MoveGameObjectToScene(cameraRoot, scene);
                cameraRoot.tag = "MainCamera";

                if (!EditorSceneManager.SaveScene(scene, ScenePath))
                    throw new InvalidOperationException("UI 환경 씬을 저장할 수 없습니다: " + ScenePath);
            }
            finally
            {
                if (scene.IsValid() && scene.isLoaded) EditorSceneManager.CloseScene(scene, true);
            }
        }

        public static void AssignToEditorSettings()
        {
            var sceneAsset = AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath);
            if (sceneAsset == null) throw new InvalidOperationException("UI 환경 씬이 없습니다: " + ScenePath);
            // ProjectSettings.asset이 아니라 EditorSettings.asset이다.
            var settings = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/EditorSettings.asset")[0]);
            var property = settings.FindProperty("m_PrefabUIEnvironment");
            if (property == null) throw new InvalidOperationException("m_PrefabUIEnvironment 속성을 찾을 수 없습니다.");
            property.objectReferenceValue = sceneAsset;
            settings.ApplyModifiedProperties();
            AssetDatabase.SaveAssets();
        }

        /// <summary>
        /// 게임 뷰에 기준 해상도 고정 프리셋을 추가한다. GameViewSizes는 internal API라
        /// Unity 버전에 따라 리플렉션이 깨질 수 있다. 실패해도 예외를 던지지 않고 수동 추가
        /// 절차를 경고 로그로 안내한다 — 작업을 막을 만큼 중요한 기능이 아니다.
        /// </summary>
        [MenuItem("Game/프리뷰/게임 뷰 기준 해상도 맞추기")]
        public static void AddPortraitGameViewSize()
        {
            int width = (int)ReferenceWidth;
            int height = (int)ReferenceHeight;
            try
            {
                var sizesType = typeof(UnityEditor.Editor).Assembly.GetType("UnityEditor.GameViewSizes");
                var singletonType = typeof(UnityEditor.Editor).Assembly
                    .GetType("UnityEditor.ScriptableSingleton`1").MakeGenericType(sizesType);
                var instance = singletonType.GetProperty("instance").GetValue(null);

                // 빌드 타겟 그룹(Standalone/Android/WebGL 등)에 추가해야 드롭다운에 보인다.
                // Standalone으로 고정하지 않고 현재 그룹을 읽는다.
                int groupTypeValue;
                try
                {
                    groupTypeValue = (int)sizesType.GetProperty("currentGroupType").GetValue(instance);
                }
                catch (Exception groupException)
                {
                    groupTypeValue = (int)GameViewSizeGroupType.Standalone;
                    Debug.LogWarning("currentGroupType을 읽지 못해 Standalone 그룹으로 대체합니다: " +
                        groupException.Message);
                }

                var group = sizesType.GetMethod("GetGroup").Invoke(instance, new object[] { groupTypeValue });
                var groupType = group.GetType();

                foreach (var text in (string[])groupType.GetMethod("GetDisplayTexts").Invoke(group, null))
                {
                    if (text != null && text.StartsWith(PresetName))
                    {
                        Debug.Log("게임 뷰 프리셋이 이미 있습니다: " + text);
                        return;
                    }
                }

                var sizeType = typeof(UnityEditor.Editor).Assembly.GetType("UnityEditor.GameViewSize");
                var sizeTypeEnum = typeof(UnityEditor.Editor).Assembly.GetType("UnityEditor.GameViewSizeType");
                var constructor = sizeType.GetConstructor(new[] { sizeTypeEnum, typeof(int), typeof(int), typeof(string) });
                var size = constructor.Invoke(new object[]
                {
                    Enum.Parse(sizeTypeEnum, "FixedResolution"), width, height, PresetName
                });
                groupType.GetMethod("AddCustomSize").Invoke(group, new[] { size });
                Debug.Log("게임 뷰 프리셋을 추가했습니다: " + PresetName +
                    " (" + width + "x" + height + "). 드롭다운에서 선택하세요.");
            }
            catch (Exception exception)
            {
                Debug.LogWarning("게임 뷰 프리셋을 자동으로 추가하지 못했습니다: " + exception.Message +
                    "\n게임 뷰 해상도 드롭다운 > + 를 눌러 Type=Fixed Resolution, Width=" + width +
                    ", Height=" + height + ", Label=" + PresetName + " 으로 직접 추가하세요.");
            }
        }
    }
}
