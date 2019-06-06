using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
[AddComponentMenu("Image Effects/Rendering/GI_Render")]
public class GI_Render : MonoBehaviour
{
    #region Public Properties  

    [SerializeField]
    [Range(0,3)]
    public int skyQuality;


    [SerializeField]
    [Range(1, 3)]
    public int skyDownsampling = 1;

    [SerializeField]
    [Range(0, 2)]
    public int SSAOMode;

    [SerializeField]
    [Range(0, 2)]
    public int SSAOQuality;

    [SerializeField]
    private bool _useMaterialsAO = false;

    [SerializeField]
    public Texture2D noise;

    [SerializeField]
    private Shader _shader;

    [SerializeField]
    private bool _enabled = true;

    [SerializeField]
    private bool _debugSkyLight = false;

    #endregion

    #region Private Resources

    RenderTexture _blurX, _blurY, _skyAO, _smallAO;
    Material _material;
    float blurDist = 1.35f;
    Vector2 screenResCur;
    #endregion

    #region MonoBehaviour Functions

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (_enabled)
        {
            RenderSettings.ambientIntensity = 0;

            if (Camera.current.depthTextureMode != DepthTextureMode.DepthNormals)
                Camera.current.depthTextureMode = DepthTextureMode.DepthNormals;

            if (_material == null)
            {
                _material = new Material(_shader);
                _material.hideFlags = HideFlags.DontSave;
            }

            if (screenResCur.x != Camera.current.scaledPixelWidth || screenResCur.y != Camera.current.scaledPixelHeight)
            {

                _skyAO = new RenderTexture(Camera.current.scaledPixelWidth / skyDownsampling, Camera.current.scaledPixelHeight / skyDownsampling, 0, RenderTextureFormat.ARGB32)
                {
                    filterMode = FilterMode.Bilinear
                };

                _blurX = new RenderTexture(Camera.current.scaledPixelWidth, Camera.current.scaledPixelHeight, 0, RenderTextureFormat.ARGB32)
                {
                    filterMode = FilterMode.Bilinear
                };

                _blurY = new RenderTexture(Camera.current.scaledPixelWidth, Camera.current.scaledPixelHeight, 0, RenderTextureFormat.ARGB32)
                {
                    filterMode = FilterMode.Bilinear
                };
                
                _smallAO = new RenderTexture(Camera.current.scaledPixelWidth, Camera.current.scaledPixelHeight, 0, RenderTextureFormat.ARGB32)
                {
                    filterMode = FilterMode.Bilinear
                };

                screenResCur.x = Camera.current.scaledPixelWidth;
                screenResCur.y = Camera.current.scaledPixelHeight;
            }

            _material.SetTexture("_Noise", noise);
            _material.SetInt("_resolution", skyDownsampling);

            _material.shaderKeywords = null;
            _material.EnableKeyword("_SKY_QUALITY_" + skyQuality.ToString());
            _material.EnableKeyword("_SSAO_MODE_" + SSAOMode.ToString());
            _material.EnableKeyword("_SSAO_QUALITY_" + SSAOQuality.ToString());
            _material.EnableKeyword("_DEBUG_SKYLIGHT_" + _debugSkyLight.ToString());
            _material.EnableKeyword("_USE_MATERIAL_AO_" + _useMaterialsAO.ToString());

            Graphics.Blit(source, _skyAO, _material, 0);
            Graphics.Blit(source, _smallAO, _material, 1);
            _material.SetTexture(Shader.PropertyToID("_smallAO"), _smallAO);

            _material.SetFloat("_blurSharpness", 0.65f);

            if(skyDownsampling == 1)
                blurDist = 1.35f;
            else if(skyDownsampling == 2)
                blurDist = 1.15f;
            else if(skyDownsampling == 3)
                blurDist = 1.75f;

            // blur vertical
            _material.SetVector("_DenoiseAngle", new Vector2(0.0f, 1.15f * skyDownsampling));
            Graphics.Blit(_skyAO, _blurY, _material, 2);
            // blur horizontal
            _material.SetVector("_DenoiseAngle", new Vector2(1.15f * skyDownsampling, 0.0f));
            Graphics.Blit(_blurY, _blurX, _material, 2);

            Graphics.Blit(_blurX, _blurY, _material, 5);

            _material.SetFloat("_blurSharpness", 0.925f);
            // blur vertical
            _material.SetVector("_DenoiseAngle", new Vector2(0.0f, 1.35f));
            Graphics.Blit(_blurY, _blurX, _material, 2);
            // blur horizontal
            _material.SetVector("_DenoiseAngle", new Vector2(1.35f, 0.0f));
            Graphics.Blit(_blurX, _blurY, _material, 2);

            //Combine 
            _material.SetColor("_SkyColor", RenderSettings.ambientSkyColor);
            _material.SetColor("_SunColor", RenderSettings.sun.color * RenderSettings.sun.intensity);
            _material.SetFloat("_BounceIntensity", RenderSettings.sun.bounceIntensity);
            _material.SetTexture(Shader.PropertyToID("_HalfRes"), _blurY);


            Graphics.Blit(source, destination, _material, 3);
        }
        else
        {
            RenderSettings.ambientIntensity = 1;
            Graphics.Blit(source, destination);
        }
    }

    #endregion
}
