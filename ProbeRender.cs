using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace TheProxor.GI
{

    [RequireComponent(typeof(Camera)), ExecuteInEditMode]
    public class ProbeRender : MonoBehaviour
    {
        public static ProbeRender instance;

        internal class CameraState : IEnumerable
        {
            private static int counter;
            public Vector3 position { get; private set; }
            public Quaternion rotation { get; private set; }
            public float orthoSize { get; private set; }

            public int selfNumber { get; private set; }


            public CameraState(Vector3 position, Vector3 rotation, float orthoSize)
            {
                this.position = position;
                this.rotation = Quaternion.Euler(rotation);
                this.orthoSize = orthoSize;

                this.selfNumber = counter;
                counter++;
            }

            public CameraState(Vector3 position, Quaternion rotation, float orthoSize)
            {
                this.position = position;
                this.rotation = rotation;
                this.orthoSize = orthoSize;

                this.selfNumber = counter;
                counter++;
            }


            internal static readonly IEnumerable<CameraState> cameraStates = new CameraState[]
            {
            new CameraState(new Vector3(0, 200.0f, 0), new Vector3(90, 0, 0), 128),
            new CameraState(new Vector3(0, 141.5f, 141.5f), new Vector3(135, 0, 0), 128),
            new CameraState(new Vector3(0, 141.5f, -141.5f), new Vector3(45, 0, 0), 128),
            new CameraState(new Vector3(141.5f, 141.5f, 0), new Vector3(45, -90, -90), 128),
            new CameraState(new Vector3(-141.5f, 141.5f, 0), new Vector3(45, 90, 90), 128),
            new CameraState(Vector3.zero, Quaternion.identity, 128)
            };

            internal static IEnumerator enumerator = cameraStates.GetEnumerator();
            internal static readonly CameraState defaultState = new CameraState(new Vector3(0, 200, 0), new Vector3(90, 0, 0), 128);
            public IEnumerator GetEnumerator()
            {
                return enumerator;
            }
        }

        private Queue<Action<RenderTexture>> renderActions = new Queue<Action<RenderTexture>>();

        public Camera camera { get { return GetComponent<Camera>(); } }

        public bool NotBakeNow { get { return renderActions == null || renderActions.Count == 0; } }

        private const string shaderName = "Hidden/GI_ProbeRender";

        [NonSerialized]
        private Material material;

        private RenderTexture textureNormalDepth, cubemapTexture;

        public int cubemapCullingMask = 0;

        /// <summary>
        /// Use it for bake GI
        /// </summary>
        public void Bake()
        {
            UpdateCubemap();

            renderActions = new Queue<Action<RenderTexture>>();
            camera.enabled = true;
            SetCameraState(CameraState.defaultState);

            material = new Material(Shader.Find(shaderName)); 

            CameraState.enumerator.Reset();
            CameraState.enumerator.MoveNext();

            foreach(var state in CameraState.cameraStates)
                renderActions.Enqueue(RenderGITexture);
            renderActions.Enqueue(Render3DTextures);
            renderActions.Enqueue(BakeCubemapToSingleImage);
            renderActions.Enqueue(Release);

            while(!NotBakeNow)
            { 
                camera.Render();
                renderActions.Dequeue();
            }
          
        }

        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (!NotBakeNow)          
                renderActions.Peek().Invoke(source);           
        }

        #region Render Actions Methods 
        private void RenderGITexture(RenderTexture source)
        {
            textureNormalDepth = new RenderTexture(64, 64, 24, RenderTextureFormat.ARGBFloat)
            {
                filterMode = FilterMode.Point,
            };

            var state = CameraState.enumerator.Current as CameraState;

            Debug.Log("Render GI Textures for " + state.selfNumber.ToString() + "...");

          
            material.SetMatrix("_GIc2w", camera.cameraToWorldMatrix);
            material.SetMatrix("_c2w_0" + state.selfNumber.ToString(), camera.cameraToWorldMatrix);
            material.SetMatrix("_w2c_0" + state.selfNumber.ToString(), camera.worldToCameraMatrix);
            material.SetVector("_camDir_0" + state.selfNumber.ToString(), new Vector4(camera.transform.position.x, camera.transform.position.y, camera.transform.position.z, camera.farClipPlane));
            material.SetFloat("_camSize_0" + state.selfNumber.ToString(), state.orthoSize * 2); 
            Graphics.Blit(source, textureNormalDepth, material, 0);
            material.SetTexture("_NormalDepth_0" + state.selfNumber.ToString(), textureNormalDepth);

            SetCameraState(state);
            CameraState.enumerator.MoveNext();
        }

        private void Render3DTextures(RenderTexture source)
        {
            const int texure3DDepth = 60;

            Debug.Log("Render 3D Textures...");

            var tmpTexture = new RenderTexture(source.width, source.height, 24, RenderTextureFormat.ARGB32)
            {
                filterMode = FilterMode.Bilinear,
            };

            var texture3D = new Texture2DArray(256, 256, texure3DDepth, TextureFormat.RGBA32, false)
            //var texture3D = new Texture3D(256, 256, texure3DDepth, UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_SRGB, UnityEngine.Experimental.Rendering.TextureCreationFlags.None)            
            {
                filterMode = FilterMode.Bilinear
            };

            for (var i = 0; i < texure3DDepth; i++)
            {
                material.SetInt("_ProbeHeight", i);
                Graphics.Blit(source, tmpTexture, material, 1);
                Graphics.CopyTexture(tmpTexture, 0, texture3D, i);
            }

            Shader.SetGlobalTexture("_skyAOtex", texture3D);

            tmpTexture.Release();
        }


        Camera cam;
        RenderTexture renderTexture;
        RenderTexture skyBoxDiffuseTexture, skyBoxReflectionTexture;
        private void UpdateCubemap()
        {
            Camera cam;

            camera.transform.position = new Vector3(0, 60, 0);

            GameObject obj = new GameObject("CubemapCamera", typeof(Camera));
            obj.hideFlags = HideFlags.HideAndDontSave;
            obj.transform.position = transform.position;
            obj.transform.rotation = Quaternion.identity;
            cam = obj.GetComponent<Camera>();
            cam.farClipPlane = 100; // don't render very far into cubemap
            cam.enabled = false;


            renderTexture = new RenderTexture(256, 256, 16);
            renderTexture.dimension = UnityEngine.Rendering.TextureDimension.Cube;
            renderTexture.hideFlags = HideFlags.HideAndDontSave;
            renderTexture.useMipMap = true;
            renderTexture.autoGenerateMips = true;

            Shader.SetGlobalTexture("_SkyCube", renderTexture);

            cam.transform.position = transform.position;
            cam.RenderToCubemap(renderTexture, 63);

            DestroyImmediate(cam);

            camera.transform.position = Vector3.zero;
        }

        private void BakeCubemapToSingleImage(RenderTexture source)
        {
            if (skyBoxDiffuseTexture != null)
                skyBoxDiffuseTexture.Release();

            if (skyBoxReflectionTexture != null)
                skyBoxReflectionTexture.Release();

            skyBoxDiffuseTexture = new RenderTexture(64, 64, 0)
            {
                wrapModeU = TextureWrapMode.Repeat,
                wrapModeV = TextureWrapMode.Clamp,
                useMipMap = true,
                autoGenerateMips = true,
            };

            skyBoxReflectionTexture = new RenderTexture(64, 64, 0)
            {
                wrapModeU = TextureWrapMode.Repeat,
                wrapModeV = TextureWrapMode.Clamp,
                useMipMap = true,
                autoGenerateMips = true,
            };

            Graphics.Blit(source, skyBoxDiffuseTexture, material, 2);
            Shader.SetGlobalTexture("_skyBoxDiffuseTexture", skyBoxDiffuseTexture);
            Graphics.Blit(source, skyBoxReflectionTexture, material, 3);
            Shader.SetGlobalTexture("_skyBoxReflectTexture", skyBoxReflectionTexture);
        }

        private void Release(RenderTexture source)
        {
            if (textureNormalDepth != null)
                textureNormalDepth.Release();

            Debug.Log("GI are backed!");
            camera.enabled = false;
        }

        #endregion

        private void SetCameraState(CameraState state)
        {
            camera.orthographicSize = state.orthoSize;
            camera.transform.position = state.position;
            camera.transform.rotation = state.rotation;
        }

        private void OnDisable()
        {
            DestroyImmediate(renderTexture);
        }
    }

#if UNITY_EDITOR
    [CustomEditor(typeof(ProbeRender))]
    internal class ProbeRenderInspector : Editor
    {
        private ProbeRender window;

        private List<string> layersList = new List<string>();

        private void OnEnable()
        {
            window = target as ProbeRender;

            SetCameraSettings(window.camera);
        }

        public override void OnInspectorGUI()
        {
            GUILayout.BeginVertical(EditorStyles.helpBox);
            {
                window.cubemapCullingMask = 0;

                GUILayout.Space(10);

                window.camera.cullingMask = EditorGUILayout.MaskField("Culling Mask", window.camera.cullingMask, layersList.ToArray());

                GUILayout.Space(10);

                if (GUILayout.Button("Bake") && window.NotBakeNow)
                    window.Bake();
            }
            GUILayout.EndVertical();
        }

        private void SetCameraSettings(Camera camera)
        {
            camera.enabled = false;
            camera.depthTextureMode = DepthTextureMode.DepthNormals;
            camera.hideFlags = HideFlags.HideInInspector;
            camera.allowHDR = false;
            camera.allowMSAA = false;
            camera.renderingPath = RenderingPath.VertexLit;
            camera.orthographic = true;
            camera.nearClipPlane = 0;
            camera.farClipPlane = 400;
            camera.orthographicSize = 128;
            camera.aspect = 1;
            camera.pixelRect = new Rect(0, 0, 256, 256);

            for (int i = 0; i <= 31; i++) 
            {
                var layer = LayerMask.LayerToName(i);
                if (!string.IsNullOrEmpty(layer)) 
                    layersList.Add(layer);
            }
        }
    }
#endif
}