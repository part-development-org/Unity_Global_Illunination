using UnityEngine;

[ExecuteInEditMode]
public class GI_ProbeRender : MonoBehaviour
{
    [SerializeField]
    private Shader curShader;

    [SerializeField]
    private int textureWidth = 256;

    [SerializeField]
    private int textureHeight = 256;

    [SerializeField]
    private int textureDepth = 60;

    private Material material;
    private RenderTexture texture;
    private Texture2DArray textureArray;

    private void Awake()
    {
        var cam = GetComponent<Camera>();
        cam.depthTextureMode = DepthTextureMode.DepthNormals;

        material = new Material(curShader)
        {
            hideFlags = HideFlags.HideAndDontSave
        };

        textureArray = new Texture2DArray(textureWidth, textureHeight, textureDepth, TextureFormat.RGBAFloat, false)
        {
            filterMode = FilterMode.Bilinear
        };
        
        texture = new RenderTexture(textureWidth, textureHeight, 0, RenderTextureFormat.ARGBFloat)
        {
            autoGenerateMips = false,
            useMipMap = false,
            filterMode = FilterMode.Bilinear,
        };
    }

    private void OnDestroy()
    {
        texture.Release();
        DestroyImmediate(textureArray);
    }

    private void OnRenderImage(RenderTexture sourceTexture, RenderTexture destTexture)
    {
        Debug.Log("GI_ProbeRender.OnRenderImage");

        for (var i = 0; i < textureDepth; i++)
        {
            Shader.SetGlobalFloat("_ProbeHeigth", i);
            Graphics.Blit(sourceTexture, texture, material, 0);
            Graphics.CopyTexture(texture, 0, textureArray, i);
        }

        Shader.SetGlobalTexture("_volGIcol", textureArray);

        gameObject.SetActive(false);
    }
}