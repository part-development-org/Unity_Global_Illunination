using UnityEngine;

[ExecuteInEditMode]
public class GI_Debug : MonoBehaviour
{
    [SerializeField]
    private Shader curShader;

    [SerializeField]
	private bool skyIndirect;

    private Camera cam;

    private void Start()
    {
        cam = GetComponent<Camera>();
        cam.depthTextureMode = DepthTextureMode.DepthNormals;
    }

    private void OnRenderImage(RenderTexture sourceTexture, RenderTexture destTexture)
    {
		//For World Position Reconcstruction
		var frustumCorners = new Vector3[4];
		cam.CalculateFrustumCorners(new Rect(0, 0, 1, 1), cam.farClipPlane, cam.stereoActiveEye, frustumCorners);
		var bottomLeft = cam.transform.TransformVector(frustumCorners[0]);
		var topLeft = cam.transform.TransformVector(frustumCorners[1]);
		var topRight = cam.transform.TransformVector(frustumCorners[2]);
		var bottomRight = cam.transform.TransformVector(frustumCorners[3]);

		var frustumCornersArray = Matrix4x4.identity;
		frustumCornersArray.SetRow(0, bottomLeft);
		frustumCornersArray.SetRow(1, bottomRight);
		frustumCornersArray.SetRow(2, topLeft);
		frustumCornersArray.SetRow(3, topRight);

        var material = new Material(curShader) { hideFlags = HideFlags.HideAndDontSave };
        material.SetMatrix("_w2cMainCam", cam.worldToCameraMatrix);
        material.SetMatrix("_c2wMainCam", cam.cameraToWorldMatrix);
        material.SetFloat("_SkyIndirect", skyIndirect ? 1.0f : 0.0f);
        material.SetVector ("_CameraWS", cam.transform.position);
		material.SetMatrix("_FrustumCornersWS", frustumCornersArray);

		Graphics.Blit (sourceTexture, destTexture, material); 
	}
}