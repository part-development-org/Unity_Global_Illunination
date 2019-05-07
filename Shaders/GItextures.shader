Shader "Custom/GItextures"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		////////////////////////////////////////////////////////
		//	NormalDepth	////////////////////////////////////////
		////////////////////////////////////////////////////////
		Pass
		{	Name "NormalDepth"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"
			#include "AutoLight.cginc"

			////
			sampler2D _CameraDepthNormalsTexture;
			float4x4 _GIc2w;

			struct appdata{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v){
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;			
				return o;
			}

			fixed4 frag (v2f i) : SV_Target	{
				float3 nrm;
				float depth;
				DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture, i.uv), depth, nrm);
				nrm = mul(_GIc2w, float4(nrm, 0)).xyz;
				return float4(nrm, depth * _ProjectionParams.z);
			}
			ENDCG
		}		
	}
}
