using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
[AddComponentMenu("Image Effects/Rendering/GI_Render")]
public class GI_Render : MonoBehaviour
{
    #region Public Properties  

    [SerializeField]
    public Texture2D noise;
    #endregion

    [SerializeField]
    private Shader _shader;

    #region Private Resources

    RenderTexture _blurX, _blurY, _skyAO, _smallAO;
    Material _material;
    Vector2 screenResCur;

    #endregion

    #region MonoBehaviour Functions

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {

        if (Camera.current.depthTextureMode != DepthTextureMode.DepthNormals)
            Camera.current.depthTextureMode = DepthTextureMode.DepthNormals;

        if (_material == null)
        {
            _material = new Material(_shader);
            _material.hideFlags = HideFlags.DontSave;
        }

        int size = 2;

        if (screenResCur.x != Camera.current.scaledPixelWidth || screenResCur.y != Camera.current.scaledPixelHeight)
        {

            _skyAO = new RenderTexture(Camera.current.scaledPixelWidth / 2, Camera.current.scaledPixelHeight / 2, 0, RenderTextureFormat.ARGB32)
            {
                filterMode = FilterMode.Bilinear
            };

            _blurX = new RenderTexture(Camera.current.scaledPixelWidth , Camera.current.scaledPixelHeight , 0, RenderTextureFormat.ARGB32)
            {
                filterMode = FilterMode.Bilinear
            };

            _blurY = new RenderTexture(Camera.current.scaledPixelWidth , Camera.current.scaledPixelHeight , 0, RenderTextureFormat.ARGB32)
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
        _material.SetInt("_resolution", size);

        Graphics.Blit(source, _skyAO, _material, 0);
        Graphics.Blit(source, _smallAO, _material, 1);



        // blur vertical
        _material.SetVector("_DenoiseAngle", new Vector2(0.0f, 2.7f));
        Graphics.Blit(_skyAO, _blurY, _material, 2);
        // blur horizontal
        _material.SetVector("_DenoiseAngle", new Vector2(2.7f, 0.0f));
        Graphics.Blit(_blurY, _blurX, _material, 2);

        // blur vertical
        _material.SetVector("_DenoiseAngle", new Vector2(0.0f, 1.35f));
        Graphics.Blit(_blurX, _blurY, _material, 2);
        // blur horizontal
        _material.SetVector("_DenoiseAngle", new Vector2(1.35f, 0.0f));
        Graphics.Blit(_blurY, _blurX, _material, 2);
        
        //Upscaling    
        _material.SetTexture("_HalfRes", _blurX);       

        // blur vertical
        _material.SetVector("_DenoiseAngle", new Vector2(0.0f, 1.35f));
        Graphics.Blit(_smallAO, _blurY, _material, 2);
        // blur horizontal
        _material.SetVector("_DenoiseAngle", new Vector2(1.35f, 0.0f));
        Graphics.Blit(_blurY, _smallAO, _material, 2);

        // blur vertical
        _material.SetVector("_DenoiseAngle", new Vector2(0.0f, 1.35f));
        Graphics.Blit(_smallAO, _blurY, _material, 2);
        // blur horizontal
        _material.SetVector("_DenoiseAngle", new Vector2(1.35f, 0.0f));
        Graphics.Blit(_blurY, _smallAO, _material, 2);

        _material.SetTexture("_SmallAO", _smallAO);

        Graphics.Blit(source, destination, _material, 3); 
    }

    #endregion
}
