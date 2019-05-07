Shader "Hidden/DebugGI"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

	Pass
		{ Name "CombineGI"
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#pragma target 3.0
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"

			////
			sampler2D _AO, _AOnormalDepth;
			sampler2D_float _CameraDepthTexture;
			sampler2D _CameraDepthNormalsTexture;
			sampler2D _CameraGBufferTexture0, _CameraGBufferTexture2;
			sampler2D _MainTex;
			float _GIpower,_UVOffset, _ProbeField, _SkyIndirect;
			float2 _SunLightIntensity;
			sampler2D _InterierMask_0, _InterierMask_1; 
			float4x4 _c2wMainCam;

			uniform float4x4 _FrustumCornersWS;
			float4 _CameraWS, _SunLightColor;

			sampler2D _worldColor00, _worldColor01, _worldColor02, _worldColor03, _worldColor04;
			sampler2D _NormalDepth00, _NormalDepth01, _NormalDepth02, _NormalDepth03, _NormalDepth04;
			sampler2D _Position00, _Position01, _Position02, _Position03, _Position04;
			float4 _camDir00, _camDir01, _camDir02, _camDir03, _camDir04;
			float4x4 _c2w00, _c2w01, _c2w02, _c2w03, _c2w04;
			float4x4 _w2c00, _w2c01, _w2c02, _w2c03, _w2c04;

			UNITY_DECLARE_TEX2DARRAY(_volGIcol);
			UNITY_DECLARE_TEX2DARRAY(_InteriorGIcol); 

			struct appdata{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 interpolatedRay : TEXCOORD1;
			};

			v2f vert (appdata v){
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				int frustumIndex = v.uv.x + (2 * o.uv.y);
				o.interpolatedRay = _FrustumCornersWS[frustumIndex];
				o.interpolatedRay.w = frustumIndex;

				return o;
			}

			half compare(float4 n1, float4 n2) {
				float N1dotN2 = smoothstep(0, 0.8,dot(n1.xyz, n2.xyz)) + 0.0001;
				float D1D2 = 1 - smoothstep(0, n1.a / 8, abs(n1.a - n2.a)) + 0.0001;
				return D1D2 * N1dotN2;
			}

			//Функция рассчёта координат точки в пространстве семплируемой текстуры
			float4 GIcamPosition (float4x4 _w2c, float3 position, float4 _camDir){
				float4 pos;
				pos.xyz = (_camDir.xyz - position.xyz);
				pos.a = length(pos.xyz);
				pos.xyz = mul(_w2c, normalize(pos.xyz));
				pos.x = -pos.x;
				pos.y = -pos.y;
				pos.xyz *= pos.a;
				return pos;
			}

			//Функция проекции точки на UV семплируемой текстуры
			float2 GIcamUV (float3 wsPos, float4x4 _w2c) {
				float3 newUV = (mul(_w2c, float4(wsPos.x, wsPos.y, wsPos.z, 0)) / (_ProbeField * 0.5)) * 0.5 + 0.5;
				return newUV.xy;
			}

			fixed4 fragAO (v2f i) : SV_Target{

				float2 uv = i.uv;
				float4 c = 0;
				float3 nrm;
				float depth;
				DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture, uv), depth, nrm);
				nrm = mul(_c2wMainCam, nrm);

				float4 wsDir = (depth + 0.0001) * i.interpolatedRay;
				float4 position = float4(_WorldSpaceCameraPos, 0) + wsDir;
				position.y += 10;

			    //////////////////////////////
				///////  InterierMask  ///////
				//////////////////////////////
				float2 wUV = (position.xz - 0.5) / _ProbeField + 0.5;
				float4 im = tex2D(_InterierMask_0, wUV);
//				im.x = step(im.a + 2.1 + im.x * 5, position.y); 
//				im.x = step(0.001, im.x);
//
				position.xyz += nrm * 0.5;
				wUV = (position.xz - 0.5) / _ProbeField + 0.5;
				float4 imH = tex2D(_InterierMask_1, wUV); 
				imH.x = smoothstep(0.4,0.6,imH.x);
				im.x = clamp(im.x + imH.x, 0,1);
//
				///////////////////////////////
				/////Calculate probe field/////
				///////////////////////////////
				float layer = floor(position.y);

				float4 GI = UNITY_SAMPLE_TEX2DARRAY(_volGIcol, float3(wUV, layer));
				float4 indoorGI = 	UNITY_SAMPLE_TEX2DARRAY(_InteriorGIcol, float3(wUV, layer));
				float dirCor = layer + 0.5 - position.y;
				layer = layer - normalize(dirCor);
				GI = (GI * (1 - abs(dirCor))  +  UNITY_SAMPLE_TEX2DARRAY(_volGIcol, float3(wUV, layer)) * abs(dirCor));
				indoorGI 	= (indoorGI * (1 - abs(dirCor))  +  UNITY_SAMPLE_TEX2DARRAY(_InteriorGIcol, float3(wUV, layer)) * abs(dirCor));

//				half3 SunGI = lerp(indoorGI.rgb, GI.rgb, imH.x) * _GIpower;
//				half3 SkyGI = lerp(indoorGI.a, GI.a, imH.x);

   				c.xyz = lerp(GI.a, pow(GI.rgb, 0.6 + _SunLightIntensity.y * 0.4) * _SunLightColor.w * _SunLightColor.xyz * _SunLightIntensity.x, _SkyIndirect);
//   				c.xyz = SunGI;

				float3 position00 = GIcamPosition(_w2c00, position.xyz, _camDir00).xyz;
				float3 position01 = GIcamPosition(_w2c01, position.xyz, _camDir01).xyz;
				float3 position02 = GIcamPosition(_w2c02, position.xyz, _camDir02).xyz;
				float3 position03 = GIcamPosition(_w2c03, position.xyz, _camDir03).xyz;
				float3 position04 = GIcamPosition(_w2c04, position.xyz, _camDir04).xyz;

				float2 newUV_00 = GIcamUV(position, _w2c00).xy;
                float2 newUV_01 = GIcamUV(position, _w2c01).xy;
                float2 newUV_02 = GIcamUV(position, _w2c02).xy;
                float2 newUV_03 = GIcamUV(position, _w2c03).xy;
                float2 newUV_04 = GIcamUV(position, _w2c04).xy;

				float4 newNrmDepth_00 = tex2D(_NormalDepth00, newUV_00);
               	float4 newNrmDepth_01 = tex2D(_NormalDepth01, newUV_01);
               	float4 newNrmDepth_02 = tex2D(_NormalDepth02, newUV_02);
               	float4 newNrmDepth_03 = tex2D(_NormalDepth03, newUV_03);
               	float4 newNrmDepth_04 = tex2D(_NormalDepth04, newUV_04);	

           		float3 color_00 = tex2D(_worldColor00, newUV_00).xyz;
               	float3 color_01 = tex2D(_worldColor01, newUV_01).xyz;
               	float3 color_02 = tex2D(_worldColor02, newUV_02).xyz;
               	float3 color_03 = tex2D(_worldColor03, newUV_03).xyz;
               	float3 color_04 = tex2D(_worldColor04, newUV_04).xyz;

//				c.xyz = mul(_w2c00, newNrmDepth_00.xyz).xyz * float3(1,1,-1);

				return c;
			}

		ENDCG
	}

}
}
