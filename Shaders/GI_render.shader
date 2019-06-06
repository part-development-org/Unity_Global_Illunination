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

			#pragma multi_compile _SKY_QUALITY_0 _SKY_QUALITY_1 _SKY_QUALITY_2 _SKY_QUALITY_3

			sampler2D _MainTex;
			uniform half4 _MainTex_TexelSize;
			sampler2D_float _CameraDepthTexture;
			sampler2D _CameraGBufferTexture2;
			sampler2D _Noise;
			int _resolution;
			UNITY_DECLARE_TEX2DARRAY(_skyAOtex);

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
				occ.a = pow(occ.a, (2 - occ.a) * 1.5);

				//Calculate SSAO
				#ifdef _SKY_QUALITY_0
					int samplesCount = 4;
					const float3 samplesDir [4] ={
					0.183013,	0.683013,	0.707107,	-0.665775,	-0.66334,	0.341648,
					0.849679,	-0.471688,	-0.235702,	-0.366917,	0.452015,	-0.813053,		
					};					
				#elif _SKY_QUALITY_1
					int samplesCount = 8;
					const float3 samplesDir [8] ={
					-0.577345,	0.577345,	0.577345,	-0.577345,	0.577345,	-0.577345,
					0.577345,	0.577345,	0.577345,	0.577345,	0.577345,	-0.577345,
		
					-0.577345,	-0.577345,	0.577345,	-0.577345,	-0.577345,	-0.577345,
					0.577345,	-0.577345,	0.577345,	0.577345,	-0.577345,	-0.577345,	
					};				
				#elif _SKY_QUALITY_2
					int samplesCount = 12;
					const float3 samplesDir [12] ={
					-0.3245,	-0.176679,	0.929223,	-0.036439,	0.785415,	0.617874,
					-0.909475,	0.346596,	0.22956,	-0.7262,	-0.6804,	0.098294,
		
					0.260107,	-0.876301,	0.40548,	0.686412,	0.029623,	0.726609,
					0.909475,	-0.346596,	-0.22956,	0.7262,		0.6804,		-0.098294,
		
					-0.260107,	0.876301,	-0.40548,	-0.686412,	-0.029623,	-0.726609,
					0.036439,	-0.785415,	-0.617874,	0.3245,		0.176679,	-0.929224,
					};					
				#elif _SKY_QUALITY_3
					int samplesCount = 16;
					const float3 samplesDir [16] ={
					0.0,		0.0,		-1.0,		-0.816499,	-0.471399,	0.33331,
					0.816494,	-0.471397,	0.333309,	0.0,		0.942809,	0.333309,
		
					-0.425535,	0.245683,	0.870939,	-0.427875,	0.737994,	-0.521793,
					0.853056,	0.001554,	-0.521791,	-0.425182,	-0.739547,	-0.521791,
		
					0.0,		-0.491364,	0.870936,	0.853071,	0.492521,	0.172244,
					0.0,		-0.985039,	0.172247,	-0.853059,	0.0,		-0.521793,
		
					0.425533,	0.245682,	0.870936,	0.425183,	-0.739548,	-0.521792,
					-0.853074,	0.492523,	0.172245,	0.427874,	0.737993,	-0.521792,
					};						
				#endif
				
				int raySteps = 3;
				const float stepsLength [3] ={
					0.11, 0.33, 1.0,
				};

				float ao = 0;
				float bias = 0.03 * depth_o;		
				float rayStart = 0.005 * depth_o;	
				float Ldivide = 1 + samplesCount;
				float scale = pow(1 + depth_o, 0.45);
				
				for (int s = 0; s < samplesCount; s++)				
				{
					//Random vector and ray length
					float3 delta = mul(unity_WorldToCamera, reflect(samplesDir[s], noise.xyz));
					delta *= (dot(norm_o, delta) >= 0) * 2 - 1;
					float l = (1 + s) / (Ldivide);

					for (int r = 0; r < raySteps; r++)
					{
						float dist = stepsLength[r] * scale * noise.w + rayStart;
						
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
				occ.a *= ao;				
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
				#pragma multi_compile _SSAO_MODE_0 _SSAO_MODE_1 _SSAO_MODE_2
				#pragma multi_compile _SSAO_QUALITY_0 _SSAO_QUALITY_1 _SSAO_QUALITY_2
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
				float _scale = 0.5;

				// Sample Normal
				float3 norm_o = tex2D(_CameraGBufferTexture2, i.uv).xyz;
				occ.xyz = norm_o;				
								
				#ifdef _SSAO_MODE_0

					occ.a = 1;

				#elif _SSAO_MODE_1
					
					norm_o = norm_o * 2 - 1;
					norm_o = mul((float3x3)unity_WorldToCamera, norm_o);

					// Sample noise texture
					float4 noise = tex2D(_Noise, uv / 4 * _ScreenParams.xy);
					noise.xyz = noise.xyz * 2 - 1;

					// Sample a view-space depth.
					float depth_o = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
					depth_o = LinearEyeDepth(depth_o);		
					
					// Reconstruct the view-space position.
					float3x3 proj = (float3x3)unity_CameraProjection;
					float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
					float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
					float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth_o;
					pos_o += norm_o * 0.003 * (1 + depth_o);

					#ifdef _SSAO_QUALITY_0
						int samplesCount = 2;
					#elif _SSAO_QUALITY_1
						int samplesCount = 4;
					#elif _SSAO_QUALITY_2
						int samplesCount = 6;
					#endif

					_scale *= pow(1 + depth_o, 0.45);

					const float3 samplesDir [6] ={
						0, 1, 0,	0,-1, 0,
						1, 0, 0,	0, 0,-1,
						0, 0, 1,	-1,0, 0,
					};

					noise.w *= noise.w;
	
					for (int s = 0; s < samplesCount; s++)
					{
						//Random vector and ray length
						float3 delta = mul(unity_WorldToCamera, reflect(samplesDir[s], noise.xyz));
						delta *= (dot(norm_o, delta) >= 0) * 2 - 1;
						
						float3 pos_s0 = pos_o + delta * _scale * noise.w;
							
						// Re-project the sampling point.
						float3 pos_sc = mul(proj, pos_s0);
						float2 uv_s = (pos_sc.xy / pos_s0.z + 1) * 0.5;

						float depth_s = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_s));

						float3 v_s2 = float3((uv_s * 2 - 1 - p13_31) / p11_22, 1) * depth_s - pos_o;

						float a1 = max(dot(normalize(v_s2), norm_o) - 0.002 * depth_o, 0.0);
						float a2 = dot(v_s2, v_s2) + 0.0001;
						float d1 = 1 - smoothstep(0, _scale, abs(depth_o - depth_s));
						occ.a += a1 * d1;
					}				 
					occ.a /= samplesCount;	
					occ.a = pow(1 -occ.a, 4);

				#elif _SSAO_MODE_2

					norm_o = norm_o * 2 - 1;
					norm_o = mul((float3x3)unity_WorldToCamera, norm_o);

					// Sample noise texture
					float4 noise = tex2D(_Noise, uv / 4 * _ScreenParams.xy);
					noise.xyz = noise.xyz * 2 - 1;

					// Sample a view-space depth.
					float depth_o = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
					depth_o = LinearEyeDepth(depth_o);

					// Reconstruct the view-space position.
					float3x3 proj = (float3x3)unity_CameraProjection;
					float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
					float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
					float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth_o + norm_o * 0.001 * (1 + depth_o);

					//Calculate SSAO				
					#ifdef _SSAO_QUALITY_0
						int samplesCount = 4;
						const float3 samplesDir [4] ={
						0.183013,	0.683013,	0.707107,	-0.665775,	-0.66334,	0.341648,
						0.849679,	-0.471688,	-0.235702,	-0.366917,	0.452015,	-0.813053,		
						};
					#elif _SSAO_QUALITY_1
						int samplesCount = 8;
						const float3 samplesDir [8] ={
						-0.012542,	0.104001,	0.995837,	0.766418,	0.578011,	0.284906,
						0.082719,	-0.900191,	0.430673,	-0.861678,	0.426181,	0.280258,
		
						-0.766418,	-0.578011,	-0.284905,	0.861678,	-0.426181,	-0.280259,
						0.012541,	-0.104001,	-0.995837,	-0.082719,	0.900191,	-0.430673,
						};
					#elif _SSAO_QUALITY_2
						int samplesCount = 12;
						const float3 samplesDir [12] ={
						-0.3245,	-0.176679,	0.929223,	-0.036439,	0.785415,	0.617874,
						-0.909475,	0.346596,	0.22956,	-0.7262,	-0.6804,	0.098294,
		
						0.260107,	-0.876301,	0.40548,	0.686412,	0.029623,	0.726609,
						0.909475,	-0.346596,	-0.22956,	0.7262,		0.6804,		-0.098294,
		
						-0.260107,	0.876301,	-0.40548,	-0.686412,	-0.029623,	-0.726609,
						0.036439,	-0.785415,	-0.617874,	0.3245,		0.176679,	-0.929224,
						};		
					#endif
				
					int raySteps = 3;
					const float stepsLength [3] ={
						0.1, 0.3, 1.0,
					};
				
					float bias = 0.03 * depth_o;
					float rayStart = 0.001 * depth_o;	
					_scale *= pow(1 + depth_o, 0.45);

					//High Quality				
					for (int s = 0; s < samplesCount; s++)				
					{
						//Random vector and ray length
						float3 delta = mul(unity_WorldToCamera, reflect(normalize(samplesDir[s] + norm_o), noise.xyz));
						delta = faceforward(delta, -norm_o, delta);

						for (int r = 0; r < raySteps; r++)
						{
							float dist = stepsLength[r] * _scale * noise.w + rayStart;
						
							float3 pos_s0 = pos_o + delta * dist;
							
							// Re-project the sampling point.
							float3 pos_sc = mul(proj, pos_s0);
							float2 uv_s = (pos_sc.xy / pos_s0.z + 1) * 0.5;

							float depth_s = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_s));

							float check = pos_s0.z - depth_s;

							if( check > 0 && check - bias < dist / 2)
							{
								float3 v_s2 = float3((uv_s * 2 - 1 - p13_31) / p11_22, 1) * depth_s - pos_o;
								float a1 = smoothstep(0.9, 1, dot(normalize(v_s2), norm_o));
								float d1 =  min(1, length(v_s2) / _scale);

								occ.a += 1 - a1 * d1;							
								break;
							}
						}
					}
					occ.a = max(0.001, 1 - occ.a / samplesCount);
				#endif


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
					float thresh = lerp(0.05, 0.005, angle) * n0.w * _resolution * _resolution;

				float w0 = 0.2270270270 + 0.001;
				float w1 = compare(n0, getNormal(ao1.xyz, i.uv1.zw), thresh, _blurSharpness) * 0.3162162162;
				float w2 = compare(n0, getNormal(ao2.xyz, i.uv1.xy), thresh, _blurSharpness) * 0.3162162162;
				float w3 = compare(n0, getNormal(ao3.xyz, i.uv2.zw), thresh, _blurSharpness) * 0.0702702703;
				float w4 = compare(n0, getNormal(ao4.xyz, i.uv2.xy), thresh, _blurSharpness) * 0.0702702703;
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
            #include "UnityStandardBRDF.cginc"

			sampler2D _MainTex, _HalfRes, _skyBoxDiffuseTexture, _skyBoxReflectTexture;
			uniform half4 _MainTex_TexelSize;
			sampler2D _CameraGBufferTexture0;
			sampler2D _CameraGBufferTexture1;
			sampler2D _CameraGBufferTexture2;
			sampler2D_float _CameraDepthTexture;

			UNITY_DECLARE_TEX2DARRAY(_skyAOtex);

			#pragma multi_compile _DEBUG_SKYLIGHT_True _DEBUG_SKYLIGHT_False
			#pragma multi_compile _USE_MATERIAL_AO_True _USE_MATERIAL_AO_False

			float4 _SunColor, _SkyColor;
			float _BounceIntensity;

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

			float3 fresnel_factor(float3 f0, float product)
			{
				return lerp(f0, 1, pow(1.01 - product, 5.0));
			}

			fixed4 fragAO (v2f i) : SV_Target
			{
				//Scene data
				float4 c = tex2D(_MainTex, i.uv);
				float4 sceneAlbedo = tex2D(_CameraGBufferTexture0, i.uv);
				float4 sceneSpecular = tex2D(_CameraGBufferTexture1, i.uv);
				float oneMinGlossy = (1 - sceneSpecular.a);
				float3 worldNormal = tex2D(_CameraGBufferTexture2, i.uv) * 2 - 1;

				//View dir and screen position
				float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
				float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
				float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));		
				float3 viewDir = normalize(mul(unity_CameraToWorld, float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth));

				//Sky AO texture
				float4 ao = tex2D(_HalfRes, i.uv) ;

				#ifdef _USE_MATERIAL_AO_True
					ao *= sceneAlbedo.a;
				#endif
				
				//Sky Specular 
				half nv = abs(dot(worldNormal, viewDir));  
				float3 oneMinusReflectivity = 1 - sceneSpecular.rgb;
				half grazingTerm = saturate(sceneSpecular.a + (1-oneMinusReflectivity));
				float3 specularColor = fresnel_factor(sceneSpecular.rgb, dot(-viewDir, worldNormal));
				specularColor = FresnelLerp(sceneSpecular.rgb, grazingTerm, nv);

				float3 reflectVector = reflect(viewDir, worldNormal);
				float reflectSkyOcclusion = smoothstep(-oneMinGlossy - 0.25, 1, dot(reflectVector, float3(0,1,0)));
				reflectSkyOcclusion *= pow(ao.a, 2 - ao.a);
				float2 skyCubeReflectUV = reflectVector.xz * 0.5 + 0.5;
				float3 skyCubeReflect = specularColor * tex2Dlod(_skyBoxReflectTexture, float4(skyCubeReflectUV, 0, oneMinGlossy * 6)).rgb * reflectSkyOcclusion;

				//Sky Diffuse cubemap miplevel
				float3 skyDiffuseNormal = normalize(lerp(float3(0,1,0), worldNormal, ao.a));
				float2 skyCubeDiffuseUV = skyDiffuseNormal.xz * 0.5 + 0.5;
				float3 skyColor = tex2D(_skyBoxDiffuseTexture, skyCubeDiffuseUV).rgb * ao.a;
				float3 fakeSunGI = _SunColor * pow(ao.a, 2 - ao.a) * 0.1 * _BounceIntensity * max(0, (dot((-worldNormal + float3(0,1,0)), _WorldSpaceLightPos0.xyz) + 0.5) / 1.5);

				c.rgb += (skyColor + fakeSunGI) * sceneAlbedo * (1 - specularColor); //Diffuse Light
				c.rgb += skyCubeReflect; //Specular Light

				#ifdef _DEBUG_SKYLIGHT_True
					/*
					// Reconstruct the view-space position.
					float3 pos_o = float3((i.uv * 2 - 1 - p13_31) / p11_22, 1) * depth;	

					// Get world-space position
					float3 pos_w = mul((float3x3)unity_CameraToWorld, pos_o) + _WorldSpaceCameraPos;

					float layer = floor(pos_w.y);

					ao.a = UNITY_SAMPLE_TEX2DARRAY(_skyAOtex, float3((pos_w.xz) / 256 - 0.5, layer + 10.501)).a;
					float dirCor = layer + 0.5 -  pos_w.y;
					layer = layer - normalize(dirCor);
					ao.a = (ao.a * (1 - abs(dirCor))  +  UNITY_SAMPLE_TEX2DARRAY(_skyAOtex, float3((pos_w.xz) / 256 - 0.5, layer + 10.501)).a * abs(dirCor));

					ao.a = pow(ao.a, 1 + (1 - ao.a) * 4.1415926);
					*/

					c.rgb = ao.a;
				#endif

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
				smallAO.a *= pow(tex2D(_MainTex, i.uv).a, 1.5);
				return smallAO;
			}

			ENDCG
		}

		
	}
}
