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
            new CameraState(new Vector3(0, 141.5f, 141.5f), new Vector3(135, 0, 0), 128),
            new CameraState(new Vector3(0, 141.5f, -141.5f), new Vector3(45, 0, 0), 128),
            new CameraState(new Vector3(141.5f, 141.5f, 0), new Vector3(45, -90, -90), 128),
            new CameraState(new Vector3(-141.5f, 141.5f, 0), new Vector3(45, 90, 90), 128),
            new CameraState(new Vector3(100, 141.5f, -100), new Vector3(135, 135, 0), 180),
            new CameraState(new Vector3(-100, 141.5f, 100), new Vector3(45, 135, 0), 180),
            new CameraState(new Vector3(-100, 141.5f, -100), new Vector3(45, 45, -90), 180),
            new CameraState(new Vector3(100, 141.5f, 100), new Vector3(45, 225, 90), 180),
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

        private const string shaderName = "Hidden/GI_render";

        [NonSerialized]
        private Material material;

        /// <summary>
        /// Use it for bake GI
        /// </summary>
        public void Bake()
        {
            renderActions = new Queue<Action<RenderTexture>>();
            camera.enabled = true;
            SetCameraState(CameraState.defaultState);

            material = new Material(Shader.Find(shaderName)); 

            CameraState.enumerator.Reset();
            CameraState.enumerator.MoveNext();

            foreach(var state in CameraState.cameraStates)
                renderActions.Enqueue(RenderGITexture);
            renderActions.Enqueue(Render3DTextures);
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
            var state = CameraState.enumerator.Current as CameraState;

            Debug.Log("Render GI Textures for " + state.selfNumber.ToString() + "...");

            var textureNormalDepth = new RenderTexture(source.width, source.height, 24, RenderTextureFormat.ARGBFloat)
            {
                filterMode = FilterMode.Trilinear,
            };

            material.SetMatrix("_GIc2w", camera.cameraToWorldMatrix);
            Shader.SetGlobalMatrix("_c2w" + state.selfNumber.ToString(), camera.cameraToWorldMatrix);
            Shader.SetGlobalMatrix("_w2c" + state.selfNumber.ToString(), camera.worldToCameraMatrix);
            Shader.SetGlobalVector("_camDir" + state.selfNumber.ToString(), new Vector4(camera.transform.position.x, camera.transform.position.y, camera.transform.position.z, camera.farClipPlane));
            Graphics.Blit(source, textureNormalDepth, material, 1);
            Shader.SetGlobalTexture("_NormalDepth" + state.selfNumber.ToString(), textureNormalDepth);

            textureNormalDepth.Release();

            SetCameraState(state);
            CameraState.enumerator.MoveNext();
        }

        private void Render3DTextures(RenderTexture source)
        {
            const int texure3DDepth = 60;

            Debug.Log("Render 3D Textures...");

            var tmpTexture = new RenderTexture(source.width, source.height, 24, RenderTextureFormat.ARGB32)
            {
                filterMode = FilterMode.Trilinear,
            };

            var texture3D = new Texture3D(256, 256, texure3DDepth, UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_SRGB, UnityEngine.Experimental.Rendering.TextureCreationFlags.None);

            for (var i = 0; i < texure3DDepth; i++)
            {
                Shader.SetGlobalInt("_ProbeHeight", i);
                Graphics.Blit(source, tmpTexture, material, 0);
                Graphics.CopyTexture(tmpTexture, 0, texture3D, i);
            }

            Shader.SetGlobalTexture("_volGIcol", texture3D);

            tmpTexture.Release();
        }

        private void Release(RenderTexture source)
        {
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
    }

#if UNITY_EDITOR
    [CustomEditor(typeof(ProbeRender))]
    internal class ProbeRenderInspector : Editor
    {
        private ProbeRender window;

        private void OnEnable()
        {
            window = target as ProbeRender;

            SetCameraSettings(window.camera);
        }

        public override void OnInspectorGUI()
        {
            GUILayout.BeginVertical(EditorStyles.helpBox);
            {
                window.camera.cullingMask = EditorGUILayout.MaskField("Culling Mask", window.camera.cullingMask, UnityEditorInternal.InternalEditorUtility.layers);

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
        }
    }
#endif
}