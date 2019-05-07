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
        internal class CameraState
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

        }

        private readonly CameraState[] cameraStates = new CameraState[]
        {
            new CameraState(new Vector3(0, 200, 0), new Vector3(90, 0, 0), 128),
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

        private Queue<Action<RenderTexture, RenderTexture>> renderActions = new Queue<Action<RenderTexture, RenderTexture>>();

        public Camera camera { get { return GetComponent<Camera>(); } }

        public bool NotBakeNow { get { return renderActions.Count == 0; } }

        /// <summary>
        /// Use it for bake GI
        /// </summary>
        public void Bake()
        {
            camera.enabled = true;

            renderActions.Enqueue(RenderGITextures);
            renderActions.Enqueue(Render3DTextures);
            renderActions.Enqueue(Release);

            while(!NotBakeNow)
            { 
                camera.Render();
                renderActions.Dequeue();
            }
        }

        private void Update()
        {
            
        }

        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            Debug.Log("Test");

            if (!NotBakeNow)          
                renderActions.Peek().Invoke(source, destination);           
        }

        #region Render Actions Methods 
        private void RenderGITextures(RenderTexture source, RenderTexture destination)
        {
            Debug.Log("Render GI Textures...");

            foreach(var camState in cameraStates)
            {
                camera.orthographicSize = camState.orthoSize;
                camera.transform.position = camState.position;
                camera.transform.rotation = camState.rotation;

                Shader.SetGlobalTexture("Texture_" + camState.selfNumber, source);
            }
        }

        private void Render3DTextures(RenderTexture source, RenderTexture destination)
        {
            Debug.Log("Render 3D Textures...");
        }

        private void Release(RenderTexture source, RenderTexture destination)
        {
            Debug.Log("GI are backed!");
            camera.enabled = false;
        }

        #endregion

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
            camera.hideFlags = HideFlags.HideInInspector;
            camera.allowHDR = false;
            camera.allowMSAA = false;
            camera.renderingPath = RenderingPath.VertexLit;
            camera.orthographic = true;
            camera.nearClipPlane = 0;
            camera.farClipPlane = 400;
            camera.orthographicSize = 128;
        }
    }
#endif
}