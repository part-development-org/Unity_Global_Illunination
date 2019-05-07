using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
[AddComponentMenu("Image Effects/Rendering/Deferred AO")]
public class GI_renderTest : MonoBehaviour
{
    #region Public Properties        

    #endregion

    #region Private Resources

    RenderTexture _halfRes, _denoise;
    Material _material;

    [SerializeField, HideInInspector]
    private Shader _shader;

    [SerializeField, HideInInspector]
    Texture2D _noise;

    Vector2 screenResCur;
    int curRes = 0;
    int samplesCount = 1;

    bool CheckDeferredShading()
    {
        var path = GetComponent<Camera>().actualRenderingPath;
        return path == RenderingPath.DeferredShading;
    }

    #endregion

    #region MonoBehaviour Functions

    private void Update()
    {
       
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {

        if (!CheckDeferredShading())
        {
            Graphics.Blit(source, destination);
            return;
        }

        if (_material == null)
        {
            _material = new Material(_shader);
            _material.hideFlags = HideFlags.DontSave;
        }

        if (screenResCur.x != Camera.current.scaledPixelWidth || screenResCur.y != Camera.current.scaledPixelHeight)
        {

            _halfRes = new RenderTexture(Camera.current.scaledPixelWidth, Camera.current.scaledPixelHeight, 0, RenderTextureFormat.ARGBFloat)
            {
                filterMode = FilterMode.Bilinear
            };

            _denoise = new RenderTexture(Camera.current.scaledPixelWidth, Camera.current.scaledPixelHeight, 0, RenderTextureFormat.ARGBFloat)
            {
                filterMode = FilterMode.Bilinear
            };

            screenResCur.x = Camera.current.scaledPixelWidth;
            screenResCur.y = Camera.current.scaledPixelHeight;
        }
        
        Graphics.Blit(source, _halfRes, _material, 0);        

        //Upscaling    
        _material.SetTexture("_HalfRes", _halfRes);
        Graphics.Blit(source, destination, _material, 1);
    }

    #endregion
}
