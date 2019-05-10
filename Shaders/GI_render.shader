Shader "Hidden/GI_render"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//Ambient Occlusion ( 0 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"

			//Input data
				sampler2D _MainTex;
				uniform half4 _MainTex_TexelSize;
				sampler2D_float _CameraDepthTexture;
				sampler2D _CameraGBufferTexture2;
				sampler2D _Noise;
			
				sampler2D _NormalDepth_00, _NormalDepth_01, _NormalDepth_02, _NormalDepth_03, _NormalDepth_04, _NormalDepth_05, _NormalDepth_06, _NormalDepth_07, _NormalDepth_08;
				float4x4 _c2w_00, _c2w_01, _c2w_02, _c2w_03, _c2w_04, _c2w_05, _c2w_06, _c2w_07, _c2w_08;
				float4x4 _w2c_00, _w2c_01, _w2c_02, _w2c_03, _w2c_04, _w2c_05, _w2c_06, _w2c_07, _w2c_08;
				float4 _camDir_00, _camDir_01, _camDir_02, _camDir_03, _camDir_04, _camDir_05, _camDir_06, _camDir_07, _camDir_08;

			struct appdata	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)	
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			float nrand(float2 uv, float dx, float dy)
			{
				uv += float2(dx, dy);
				return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
			}

			float3 spherical_kernel(float2 uv, float index)
			{
				// Uniformaly distributed points
				// http://mathworld.wolfram.com/SpherePointPicking.html
				float u = nrand(uv, 0, index) * 2 - 1;
				float theta = nrand(uv, 1, index) * UNITY_PI * 2;
				float u2 = sqrt(1 - u * u);
				float3 v = float3(u2 * cos(theta), u2 * sin(theta), u);
				return v;
			}

			fixed4 fragAO (v2f i) : SV_Target
			{

				float2 uv = i.uv;

				// Reconstruct the view-space position.
				float depth_o = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth_o = LinearEyeDepth(depth_o);

				float3x3 proj = (float3x3)unity_CameraProjection;
				float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
				float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
				float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth_o;
				float3 pos_w = mul((float3x3)unity_CameraToWorld, pos_o) + _WorldSpaceCameraPos;

				float3 pos_c_00 = mul(_w2c_00, pos_w - _camDir_00);				
				float3 pos_c_01 = mul(_w2c_01, pos_w - _camDir_01);
				float3 pos_c_02 = mul(_w2c_02, pos_w - _camDir_02);
				float3 pos_c_03 = mul(_w2c_03, pos_w - _camDir_03);
				float3 pos_c_04 = mul(_w2c_04, pos_w - _camDir_04);
				float3 pos_c_05 = mul(_w2c_05, pos_w - _camDir_05);
				float3 pos_c_06 = mul(_w2c_06, pos_w - _camDir_06);
				float3 pos_c_07 = mul(_w2c_07, pos_w - _camDir_07);
				float3 pos_c_08 = mul(_w2c_08, pos_w - _camDir_08);
				pos_c_00.z *= -1;
				pos_c_01.z *= -1;
				pos_c_02.z *= -1;
				pos_c_03.z *= -1;
				pos_c_04.z *= -1;
				pos_c_05.z *= -1;
				pos_c_06.z *= -1;
				pos_c_07.z *= -1;
				pos_c_08.z *= -1;	

				//Calculate SSAO
				float4 occ = 0;
				float bias = 0;
				float offset = 0.0;

				float _samplesCount = 8;
				int raySteps = 8;
				float rndTable [8] ={
					0.5, 1, 2, 4, 8, 16, 32, 64
				};

				for (int s = 0; s < _samplesCount; s++){	

					//Random vector and ray length
					float3 delta = spherical_kernel(uv, s);				

					float3 delta00 = mul(_w2c_00, delta);
					float3 delta01 = mul(_w2c_01, delta);
					float3 delta02 = mul(_w2c_02, delta);
					float3 delta03 = mul(_w2c_03, delta);
					float3 delta04 = mul(_w2c_04, delta);
					float3 delta05 = mul(_w2c_05, delta);
					float3 delta06 = mul(_w2c_06, delta);
					float3 delta07 = mul(_w2c_07, delta);
					float3 delta08 = mul(_w2c_08, delta);

					////////////////
					/////Cam_00/////
					////////////////
					for (int r = 0; r < raySteps; r++){												
						
						float lengthRay = rndTable[r];

						float3 pos_s_00 = pos_c_00 + delta00 * lengthRay;
						float3 pos_s_01 = pos_c_01 + delta01 * lengthRay;	
						float3 pos_s_02 = pos_c_02 + delta02 * lengthRay;	
						float3 pos_s_03 = pos_c_03 + delta03 * lengthRay;	
						float3 pos_s_04 = pos_c_04 + delta04 * lengthRay;	
						float3 pos_s_05 = pos_c_05 + delta05 * lengthRay;	
						float3 pos_s_06 = pos_c_06 + delta06 * lengthRay;	
						float3 pos_s_07 = pos_c_07 + delta07 * lengthRay;	
						float3 pos_s_08 = pos_c_08 + delta08 * lengthRay;	

						float2 uv_s_00 = (pos_s_00.xy / 256) + 0.5;
						float2 uv_s_01 = (pos_s_01.xy / 256) + 0.5;
						float2 uv_s_02 = (pos_s_02.xy / 256) + 0.5;
						float2 uv_s_03 = (pos_s_03.xy / 256) + 0.5;
						float2 uv_s_04 = (pos_s_04.xy / 256) + 0.5;
						float2 uv_s_05 = (pos_s_05.xy / 256) + 0.5;
						float2 uv_s_06 = (pos_s_06.xy / 256) + 0.5;
						float2 uv_s_07 = (pos_s_07.xy / 256) + 0.5;
						float2 uv_s_08 = (pos_s_08.xy / 256) + 0.5;

						float4 normDepth00 = tex2D(_NormalDepth_00, uv_s_00);
						float4 normDepth01 = tex2D(_NormalDepth_01, uv_s_01);
						float4 normDepth02 = tex2D(_NormalDepth_02, uv_s_02);
						float4 normDepth03 = tex2D(_NormalDepth_03, uv_s_03);
						float4 normDepth04 = tex2D(_NormalDepth_04, uv_s_04);
						float4 normDepth05 = tex2D(_NormalDepth_05, uv_s_05);
						float4 normDepth06 = tex2D(_NormalDepth_06, uv_s_06);
						float4 normDepth07 = tex2D(_NormalDepth_07, uv_s_07);
						float4 normDepth08 = tex2D(_NormalDepth_08, uv_s_08);
						
						float check_00 = (pos_s_00.z - normDepth00.a);
						float check_01 = (pos_s_01.z - normDepth01.a);
						float check_02 = (pos_s_02.z - normDepth02.a);
						float check_03 = (pos_s_03.z - normDepth03.a);
						float check_04 = (pos_s_04.z - normDepth04.a);
						float check_05 = (pos_s_05.z - normDepth05.a);
						float check_06 = (pos_s_06.z - normDepth06.a);
						float check_07 = (pos_s_07.z - normDepth07.a);
						float check_08 = (pos_s_08.z - normDepth08.a);

						if (	check_00 > bias 
							|| check_01 > bias
							|| check_02 > bias
							|| check_03 > bias 
							|| check_04 > bias
							|| check_05 > bias
							|| check_06 > bias
							|| check_07 > bias 
							|| check_08 > bias
							)
						{
							float3 pos_s = float3(pos_s_00.xy, normDepth00.a);
							float3 v_s2 = pos_s - pos_c_00;
							float d1 = smoothstep(0, 64, length(v_s2));
							float a2 = check_00 + offset  < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_00, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_01.xy, normDepth01.a);
							v_s2 = pos_s - pos_c_01;
							d1 = smoothstep(0, 64, length(v_s2));
							a2 = check_01 + offset  < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_01, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_02.xy, normDepth02.a);
							v_s2 = pos_s - pos_c_02;
							d1 = smoothstep(0, 64,length(v_s2));							
							a2 = check_02 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_02, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_03.xy, normDepth03.a);
							v_s2 = pos_s - pos_c_03;
							d1 = smoothstep(0, 64, length(v_s2));							
							a2 = check_03 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_03, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_04.xy, normDepth04.a);
							v_s2 = pos_s - pos_c_04;
							d1 = smoothstep(0, 64, length(v_s2));
							a2 = check_04 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_04, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_05.xy, normDepth05.a);
							v_s2 = pos_s - pos_c_05;
							d1 = smoothstep(0, 64, length(v_s2));
							a2 = check_05 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_05, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_06.xy, normDepth06.a);
							v_s2 = pos_s - pos_c_06;
							d1 = smoothstep(0, 64,length(v_s2));
							a2 = check_06 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_06, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_07.xy, normDepth07.a);
							v_s2 = pos_s - pos_c_07;
							d1 = smoothstep(0, 64, length(v_s2));
							a2 = check_07 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_07, normalize(v_s2)) * d1;

							pos_s = float3(pos_s_08.xy, normDepth08.a);
							v_s2 = pos_s - pos_c_08;
							d1 = smoothstep(0, 64, length(v_s2));
							a2 = check_08 + offset < lengthRay;
							occ.a += a2;
							occ.xyz += mul(_c2w_08, normalize(v_s2)) * d1;


							r = 10;
						}
					}
				}				

				occ.a /= (_samplesCount * 9);
				occ.a = max(0, min(1, occ.a));

				float3 norm_o = tex2D(_CameraGBufferTexture2, i.uv).xyz * 2 - 1;

				occ.xyz = normalize(-occ.xyz + norm_o) * 0.5 + 0.5;
				//occ.xyz = norm_o * 0.5 + 0.5;

				//occ.xyz = pos_c_01 / 10;

				return occ;
			}

			ENDCG
		}

		//Upscaling  ( 1 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragUPSCALE
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"

			//Input data
				#pragma multi_compile _DEBUG_None _DEBUG_Lighting _DEBUG_AO _DEBUG_Bounce
				#pragma multi_compile _BOUNCE_True _BOUNCE_False

				sampler2D _MainTex;
				sampler2D_float _CameraDepthTexture;
				sampler2D _CameraGBufferTexture0, _CameraGBufferTexture1, _CameraGBufferTexture2;
				sampler2D _HalfRes;
				float _lightContribution;
				float3 _FogParams;

			struct appdata	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)	
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			half ComputeFog(float z)
			{
				half fog = 0.0;
			#if FOG_LINEAR
				fog = (_FogParams.z - z) / (_FogParams.z - _FogParams.y);
			#elif FOG_EXP
				fog = exp2(-_FogParams.x * z);
			#else // FOG_EXP2
				fog = _FogParams.x * z;
				fog = exp2(-fog * fog);
			#endif
				return saturate(fog);
			}

			fixed4 fragUPSCALE (v2f i) : SV_Target
			{
			 
				float2 uv = i.uv;

				float4 scene = tex2D(_MainTex, uv);
				float4 sceneAlbedo = tex2D(_CameraGBufferTexture0, uv);
				float4 sceneColor = tex2D(_CameraGBufferTexture1, i.uv) + sceneAlbedo;
				float4 sceneLight = scene / sceneColor;
				sceneLight.a = 0.2126 * sceneLight.r + 0.7152 * sceneLight.g + 0.0722 * sceneLight.b;
				half shadowmask = smoothstep(0.05, _lightContribution, sceneLight.a);
				float4 ao = tex2D(_HalfRes, uv);
				ao.xyz = ao * 2 - 1;
				ao.a = (ao.a + 0.1) / 1.1;

				float depth_o = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
				depth_o = LinearEyeDepth(depth_o);
				float skyClamp = step(999, depth_o);
				
				float3 norm_o = tex2D(_CameraGBufferTexture2, i.uv).xyz * 2 - 1;

				float4 combine = scene;							
				
				combine.rgb = (dot(ao.xyz, float3(0,1,0)) * 0.5 + 0.5);
				combine.rgb = ao.a;

				//combine.rgb = ao.xyz * 0.5 + 0.5;

				return combine;
			}

			ENDCG
		}

		//DownSampled Normal And Depth  ( 3 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"

			sampler2D_float _CameraDepthTexture;
			sampler2D _CameraGBufferTexture2;

			struct appdata	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)	
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 fragAO (v2f i) : SV_Target
			{
				
				// Sample a linear depth on the depth buffer.
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth = LinearEyeDepth(depth);

				// Sample a view-space normal vector on the g-buffer.
				float3 norm = tex2D(_CameraGBufferTexture2, i.uv).xyz;
				norm = mul((float3x3)unity_WorldToCamera, norm * 2 - 1) * 0.5 + 0.5;
				
				return float4(norm, depth);
			}

			ENDCG
		}

		//SceneColor  ( 4 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO

			sampler2D _MainTex;

			struct appdata	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)	
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 fragAO (v2f i) : SV_Target
			{
				
				return tex2D(_MainTex, i.uv);
			}

			ENDCG
		}
	}
}
