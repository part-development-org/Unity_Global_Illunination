using UnityEngine;

[ExecuteInEditMode]
public class GI_Textures : MonoBehaviour
{
    [SerializeField]
	private Shader curShader;

    [SerializeField]
    private string number;

    [SerializeField]
    private int textureWidth = 256;

    [SerializeField]
    private int textureHeight = 256;

    private Stage stage;
    private Camera cam;
    private Material material;
    private RenderTexture textureNormalDepth;
    private RenderTexture textureWorldColor;
    private RenderTexture texturePosition;
    private Vector2 curRes;

    private enum Stage { NormalDepth, WorldColor, Position }

    private void Awake()
    {
        cam = GetComponent<Camera>();      

        material = new Material(curShader) { hideFlags = HideFlags.HideAndDontSave };

       

        stage = Stage.NormalDepth;
    }

    private void OnDestroy()
    {
        textureNormalDepth.Release();
        textureWorldColor.Release();
        texturePosition.Release();
    }

    private void OnRenderImage(RenderTexture sourceTexture, RenderTexture dest)
    {
        if (textureNormalDepth == null || curRes.x != textureWidth || curRes.y != textureHeight)
        {
            textureNormalDepth = new RenderTexture(textureWidth, textureHeight, 24, RenderTextureFormat.ARGBFloat)
            {
                autoGenerateMips = false,
                useMipMap = false,
                filterMode = FilterMode.Trilinear,
            };
            curRes.x = textureWidth;
            curRes.y = textureHeight;
        }
       

        if (cam.depthTextureMode != DepthTextureMode.DepthNormals)
            cam.depthTextureMode = DepthTextureMode.DepthNormals;

        material.SetMatrix("_GIc2w", cam.cameraToWorldMatrix);
        Shader.SetGlobalMatrix("_c2w" + number, cam.cameraToWorldMatrix);
        Shader.SetGlobalMatrix("_w2c" + number, cam.worldToCameraMatrix);
        Shader.SetGlobalVector("_camDir" + number, new Vector4(cam.transform.position.x, cam.transform.position.y, cam.transform.position.z, cam.farClipPlane));
        Graphics.Blit(sourceTexture, textureNormalDepth, material);
        Shader.SetGlobalTexture("_NormalDepth" + number, textureNormalDepth);

    }
}