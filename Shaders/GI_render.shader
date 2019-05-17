Shader "Hidden/GI_Render"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//Sky Occlusion ( 0 )
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
				int _resolution;

				UNITY_DECLARE_TEX2DARRAY(_skyAOtex);
				//sampler3D _skyAOtex;

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
			//
				float2 uv = i.uv;
				float4 occ = 0;
				// Sample a view-space depth.
				float depth_o = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth_o = LinearEyeDepth(depth_o);
				// Sample noise texture
				float4 noise = tex2D(_Noise, uv / (4 * _resolution) * _ScreenParams.xy);
				noise.xyz = noise.xyz * 2 - 1;
				// Sample Normal
				float3 norm_o = tex2D(_CameraGBufferTexture2, i.uv).xyz;
				occ.xyz = norm_o;
				norm_o = norm_o * 2 - 1;

				// Reconstruct the view-space position.
				float3x3 proj = (float3x3)unity_CameraProjection;
				float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
				float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
				float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth_o;	

				// Get world-space position
				float3 pos_w = mul((float3x3)unity_CameraToWorld, pos_o) + _WorldSpaceCameraPos;
				pos_w += (tex2D(_CameraGBufferTexture2, i.uv).xyz * 2 - 1) * 0.01;
				pos_w += (norm_o * 0.5 + (noise.xyz *= (dot(norm_o, noise.xyz) >= 0) * 2 - 1));
				pos_w -= 0.5;
				
				norm_o = mul((float3x3)unity_WorldToCamera, norm_o);
				pos_o += norm_o * 0.05;	

				occ.a = UNITY_SAMPLE_TEX2DARRAY(_skyAOtex, float3((pos_w.xz) / 256 - 0.5, pos_w.y + 10.501)).a;
				occ.a = pow(occ.a, 1 + (1 - occ.a) * 4.1415926);				
				
				int samplesCount = 4;
				const float3 samplesDir [4] ={
					0.183013,	0.683013,	0.707107,	-0.665775,	-0.66334,	0.341648,
					0.849679,	-0.471688,	-0.235702,	-0.366917,	0.452015,	-0.813053,		
				};

				int raySteps = 2;
				const float stepsLength [2] ={
					 0.5, 1,
				};

				float ao = 0;
				float bias = 0.03 * depth_o;			
				
				for (int s = 0; s < samplesCount; s++)				
				{
					//Random vector and ray length
					float3 delta = mul(unity_WorldToCamera, reflect(samplesDir[s], noise.xyz));
					delta *= (dot(norm_o, delta) >= 0) * 2 - 1;
					
					float3 pos_s0 = pos_o + delta;

					// Re-project the sampling point.
					float3 pos_sc = mul(proj, pos_s0);
					float2 uv_s = (pos_sc.xy / pos_s0.z + 1) * 0.5;

					for (int r = 0; r < raySteps; r++)
					{
						float dist = stepsLength[r];
						dist = max(0.3, dist * noise.w);
						
						float3 pos_s0 = pos_o + delta * dist;
							
						// Re-project the sampling point.
						float3 pos_sc = mul(proj, pos_s0);
						float2 uv_s = (pos_sc.xy / pos_s0.z + 1) * 0.5;

						float depth_s = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_s));

						float check = pos_s0.z - depth_s;

						if( check > 0 && check < dist * 2)
						{
							float3 v_s2 = float3((uv_s * 2 - 1 - p13_31) / p11_22, 1) * depth_s - pos_o;
							float a1 = smoothstep(0.9, 1, dot(normalize(v_s2), norm_o));
							float d1 =  min(1, length(v_s2) / 2);

							ao += 1 - a1 * d1;							
							r += 20;
						}
					}
				}

				ao = max(0.001, 1 - ao / samplesCount);	
				occ.a *= pow(ao, 1.33);
				
				return occ;
			}

			ENDCG
		}

		//Ambient Occlusion ( 1 )
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
			//
				float2 uv = i.uv;
				float4 occ = 0;
				// Sample a view-space depth.
				float depth_o = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth_o = LinearEyeDepth(depth_o);				
				// Sample Normal
				float3 norm_o = tex2D(_CameraGBufferTexture2, i.uv).xyz;
				occ.xyz = norm_o;
				norm_o = norm_o * 2 - 1;
				norm_o = mul((float3x3)unity_WorldToCamera, norm_o);

				// Sample noise texture
				float4 noise = tex2D(_Noise, uv / 4 * _ScreenParams.xy);
				noise.xyz = noise.xyz * 2 - 1;

				// Reconstruct the view-space position.
				float3x3 proj = (float3x3)unity_CameraProjection;
				float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
				float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
				float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth_o;
				pos_o += norm_o * 0.01 * (1 + depth_o);
				
				int samplesCount = 6;
				const float3 samplesDir [6] ={
					0, 1, 0,	0,-1, 0,
					1, 0, 0,	0, 0,-1,
					0, 0, 1,	-1,0, 0,
				};

				float bias = 0.03 * depth_o;

				float _scale = 0.7;

				//High Quality				
				for (int s = 0; s < samplesCount; s++)
				{
					//Random vector and ray length
					float3 delta = mul(unity_WorldToCamera, reflect(samplesDir[s], noise.xyz));					
					//float3 delta = spherical_kernel(uv, s);
					//delta = normalize(norm_o + delta);
					delta *= (dot(norm_o, delta) >= 0) * 2 - 1;
						
					float3 pos_s0 = pos_o + delta * _scale * noise.w;
							
					// Re-project the sampling point.
					float3 pos_sc = mul(proj, pos_s0);
					float2 uv_s = (pos_sc.xy / pos_s0.z + 1) * 0.5;

					float depth_s = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_s));

					float3 v_s2 = float3((uv_s * 2 - 1 - p13_31) / p11_22, 1) * depth_s - pos_o;

					float a1 = max(dot(v_s2, norm_o) - 0.002 * depth_o, 0.0);
					float a2 = dot(v_s2, v_s2) + 0.0001;
					//float d1 = 1 - smoothstep(0, _scale, abs(depth_o - depth_s));
					occ.a += a1 / a2 ;	
				}
				 
				occ.a = max(0.001, 1 - occ.a / samplesCount);	
				
				return occ;
			}

			ENDCG
		}

		//Blur ( 2 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragBlur
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"

			//Input data
				sampler2D_float _CameraDepthTexture;
				sampler2D _MainTex;
				uniform half4 _MainTex_TexelSize;
				float2 _DenoiseAngle;
				float _blurSharpness;

			struct appdata	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 uv1 : TEXCOORD1;
				float4 uv2 : TEXCOORD2;
			};

			v2f vert (appdata v)	
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				float2 d1 = 1 * _DenoiseAngle * _MainTex_TexelSize.xy;
				float2 d2 = 2 * _DenoiseAngle * _MainTex_TexelSize.xy;
				o.uv1 = float4(o.uv + d1, o.uv - d1);
				o.uv2 = float4(o.uv + d2, o.uv - d2);
				return o;
			}

			inline float compare(float4 n1, float4 n2, half thresh, float blurSharpness)
			{
				float c = smoothstep(0, 1, dot(n1.xyz, n2.xyz));
				c *= saturate(1.0 - abs(n1.w - n2.w) / thresh);				
				return c;
			}

			inline float4 getNormal(float3 n, half2 uv)
			{
				float4 nd = 0;
				nd.xyz = n;
				nd.w = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
				nd.w = LinearEyeDepth(nd.w);

				return nd;
			}

			fixed4 fragBlur (v2f i) : SV_Target
			{			
				float4 ao0 = tex2D(_MainTex, i.uv);
				float4 ao1 = tex2D(_MainTex, i.uv1.zw);
				float4 ao2 = tex2D(_MainTex, i.uv1.xy);
				float4 ao3 = tex2D(_MainTex, i.uv2.zw);
				float4 ao4 = tex2D(_MainTex, i.uv2.xy);

				ao0.xyz = ao0.xyz * 2 - 1;
				ao1.xyz = ao1.xyz * 2 - 1;
				ao2.xyz = ao2.xyz * 2 - 1;
				ao3.xyz = ao3.xyz * 2 - 1;
				ao4.xyz = ao4.xyz * 2 - 1;

				float4 n0 = getNormal(ao0.xyz, i.uv);

				// Reconstruct the view-space position.
					float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
					float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
					float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * n0.w;
					float3 viewDir = normalize(mul((float3x3)unity_CameraToWorld, pos_o));

				//Blur
					float angle = max(0, dot(-viewDir, n0.xyz));
					angle = pow(angle, 2.2);
					float thresh = lerp(0.05, 0.005, angle) * n0.w;

				float w0 = 0.2270270270 + 0.001;
				float w1 = compare(n0, getNormal(ao1.xyz, i.uv1.zw), thresh, _blurSharpness) * 0.3162162162 + 0.001;
				float w2 = compare(n0, getNormal(ao2.xyz, i.uv1.xy), thresh, _blurSharpness) * 0.3162162162 + 0.001;
				float w3 = compare(n0, getNormal(ao3.xyz, i.uv2.zw), thresh, _blurSharpness) * 0.0702702703 + 0.001;
				float w4 = compare(n0, getNormal(ao4.xyz, i.uv2.xy), thresh, _blurSharpness) * 0.0702702703 + 0.001;
				float accumWeight = w0 + w1 + w2 + w3 + w4;

				ao0.a *= w0;
				ao0.a += ao1.a * w1;
				ao0.a += ao2.a * w2;
				ao0.a += ao3.a * w3;
				ao0.a += ao4.a * w4;

				return float4(ao0.xyz * 0.5 + 0.5, ao0.a / accumWeight);
			}
			ENDCG
		}

		//Combine  ( 3 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"

			sampler2D _MainTex, _HalfRes;
			uniform half4 _MainTex_TexelSize;
			sampler2D _CameraGBufferTexture0;
			sampler2D _CameraGBufferTexture2;
			sampler2D_float _CameraDepthTexture;
			int _resolution;

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
				float4 c = tex2D(_MainTex, i.uv);
				float4 ao0 = tex2D(_HalfRes, i.uv);				

				float4 a = tex2D(_CameraGBufferTexture0, i.uv);
				a *= float4(0.49, 0.73, 0.99, 1) * 0.5;		
				a = ao0.a;
				c = a;
				//c = tex2D(_HalfNormalDepth, i.uv);
				//c = ao0.a;
				return c;
			}

			ENDCG
		}

		//Normal And Depth  ( 4 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"

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
				
				float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
				float3 norm = tex2D(_CameraGBufferTexture2, i.uv).xyz;

				return float4(norm, depth);
			}

			ENDCG
		}

		//Combine AO and SkyAO  ( 5 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#define UNITY_GBUFFER_INCLUDED
			#include "UnityCG.cginc"

			sampler2D _smallAO, _MainTex;

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
				float4 smallAO = tex2D(_smallAO, i.uv);
				smallAO.a *= tex2D(_MainTex, i.uv).a;
				return smallAO;
			}

			ENDCG
		}

		
	}
}
