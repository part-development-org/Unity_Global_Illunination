Shader "Hidden/GI_ProbeRender"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//Normal And Depth  ( 0 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#include "UnityCG.cginc"

			sampler2D _CameraDepthNormalsTexture;
			float4x4 _GIc2w;

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
				
				float3 nrm;
				float depth;
				DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture, i.uv), depth, nrm);
				return float4(nrm, depth * _ProjectionParams.z);
			}

			ENDCG
		}		

		//Sky Occlusion ( 1 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#include "UnityCG.cginc"

			//Input data
				sampler2D _NormalDepth_00, _NormalDepth_01, _NormalDepth_02, _NormalDepth_03, _NormalDepth_04;
				float4x4 _c2w_00, _c2w_01, _c2w_02, _c2w_03, _c2w_04;
				float4x4 _w2c_00, _w2c_01, _w2c_02, _w2c_03, _w2c_04;
				float4 _camDir_00, _camDir_01, _camDir_02, _camDir_03, _camDir_04;
				float _camSize_00, _camSize_01, _camSize_02, _camSize_03, _camSize_04;
				float _ProbeHeight;

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

				float2 uv = i.uv;
				//Position World
				float2 uv2w = (uv * 2 - 1) * 128;
				float3 pos_w = float3(uv2w.x, _ProbeHeight - 10.501, uv2w.y);

				float3 pos_c_00 = mul(_w2c_00, pos_w - _camDir_00);	
				float3 pos_c_01 = mul(_w2c_01, pos_w - _camDir_01);
				float3 pos_c_02 = mul(_w2c_02, pos_w - _camDir_02);
				float3 pos_c_03 = mul(_w2c_03, pos_w - _camDir_03);
				float3 pos_c_04 = mul(_w2c_04, pos_w - _camDir_04);
				pos_c_00.z *= -1;
				pos_c_01.z *= -1;
				pos_c_02.z *= -1;
				pos_c_03.z *= -1;
				pos_c_04.z *= -1;

				//Calculate SSAO
				const float2 reandUV[61] = {
					0,0,
					-1,1,		-1,-1,		1,1,		1,-1,	
					-1,0,		0, 1,		1,0,		0,-1,
					-2,0,		0, 2,		2,0,		0,-2,
					-2,2,		-2,-2,		2,2,		2,-2,
					-3,1,		-3,-1,		3,1,		3,-1,
					-1,3,		-1,-3,		1,3,		1,-3,
					-3.5,2,		-3.5,-2,	3.5,2,		3.5,-2,
					-2,3.5,		-2,-3.5,	2,3.5,		2,-3.5,
					-4,0,		0, 4,		4,0,		0,-4,
					-8,0,		0, 8,		8,0,		0,-8,
					-5.6,5.6,	-5.6,-5.6,	5.6,5.6,	5.6,-5.6,
					-7.5,3,		-7.5,-3,	7.5,3,		7.5,-3,
					-3,7.5,		-3,-7.5,	3,7.5,		3,-7.5,
					-16,0,		0, 16,		16,0,		0,-16,
					-11,11,		-11,-11,	11,11,		11,-11,
				};

				float4 occ = 0;
				float bias = 0.5;

				half samples = 61;
				
				for(int i = 0; i < samples; i++)
				{ 
					float2 offset = reandUV[i];

					float2 uv_s_00 = ((pos_c_00.xy - 0.5) / _camSize_00) + 0.5;
					float2 uv_s_01 = ((pos_c_01.xy - 0.5) / _camSize_01) + 0.5;
					float2 uv_s_02 = ((pos_c_02.xy - 0.5) / _camSize_02) + 0.5;
					float2 uv_s_03 = ((pos_c_03.xy - 0.5) / _camSize_03) + 0.5;
					float2 uv_s_04 = ((pos_c_04.xy - 0.5) / _camSize_04) + 0.5;

					float4 normDepth00 = tex2D(_NormalDepth_00, uv_s_00 + offset / _camSize_00);					
					float4 normDepth01 = tex2D(_NormalDepth_01, uv_s_01 + offset / _camSize_01);					
					float4 normDepth02 = tex2D(_NormalDepth_02, uv_s_02 + offset / _camSize_02);					
					float4 normDepth03 = tex2D(_NormalDepth_03, uv_s_03 + offset / _camSize_03);					
					float4 normDepth04 = tex2D(_NormalDepth_04, uv_s_04 + offset / _camSize_04);

					float distanceCheck_00 = smoothstep(0, 1.0, 64 / abs(normDepth00.a - pos_c_00.z));
		            float distanceCheck_01 = smoothstep(0, 1.0, 64 / abs(normDepth01.a - pos_c_01.z));
		            float distanceCheck_02 = smoothstep(0, 1.0, 64 / abs(normDepth02.a - pos_c_02.z));
		            float distanceCheck_03 = smoothstep(0, 1.0, 64 / abs(normDepth03.a - pos_c_03.z));
		            float distanceCheck_04 = smoothstep(0, 1.0, 64 / abs(normDepth04.a - pos_c_04.z));
					
					distanceCheck_00 *= (dot(float3(0,1,0), normDepth00.xyz) * 0.5 + 0.5);
		            distanceCheck_01 *= (dot(float3(0,1,0), normDepth01.xyz) * 0.5 + 0.5);
		            distanceCheck_02 *= (dot(float3(0,1,0), normDepth02.xyz) * 0.5 + 0.5);
		            distanceCheck_03 *= (dot(float3(0,1,0), normDepth03.xyz) * 0.5 + 0.5);
		            distanceCheck_04 *= (dot(float3(0,1,0), normDepth04.xyz) * 0.5 + 0.5);

					float ao0 = max(0, step(normDepth00.a + 1.299, pos_c_00.z)) * distanceCheck_00;
		            float ao1 = max(0, step(normDepth01.a + 1.299, pos_c_01.z)) * distanceCheck_01;
		            float ao2 = max(0, step(normDepth02.a + 1.299, pos_c_02.z)) * distanceCheck_02;
		            float ao3 = max(0, step(normDepth03.a + 1.299, pos_c_03.z)) * distanceCheck_03;
		            float ao4 = max(0, step(normDepth04.a + 1.299, pos_c_04.z)) * distanceCheck_04;

					occ.a += 1 - (ao0 + ao1 + ao2 + ao3 + ao4) / 5;	
				}

				occ.a = occ.a / samples;

				return occ;
			}

			ENDCG
		}		

		//Sky CubeMap Diffuse Baker ( 2 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#include "UnityCG.cginc"	

			samplerCUBE _SkyCube;

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

			v2f vert(appdata v)
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
				return normalize(float3(u2 * cos(theta), u2 * sin(theta), u));
			}

			fixed4 fragAO(v2f i) : SV_Target
			{
				float2 uv = i.uv;
				float2 posXZ = uv.xy * 2 - 1;
				float dist = min(0.5, length(posXZ));
				float posY = sqrt(1 - dist * dist);

				float3 pos = float3(posXZ.x, posY, posXZ.y);
				float3 vec = normalize(pos);
				//vec = normalize(pos);

				float4 cube = texCUBE(_SkyCube, vec);
				float samples = 1000;
				float weight = 1;
				
				for(int i = 0; i < samples; i++)
				{
					float3 delta = normalize(spherical_kernel(uv, i) + vec);
					delta *= (dot(vec, delta) >= 0) * 2 - 1;
					float w = max(0, dot(delta, vec));
					weight += w;
					cube += texCUBE(_SkyCube, delta) * w;
				}

				return cube /= weight;	
			}

			ENDCG
		}

		//Sky CubeMap Reflect Baker ( 2 )
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#include "UnityCG.cginc"	

			samplerCUBE _SkyCube;

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

			v2f vert(appdata v)
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
				return normalize(float3(u2 * cos(theta), u2 * sin(theta), u));
			}

			fixed4 fragAO(v2f i) : SV_Target
			{
				float2 uv = i.uv;
				float2 posXZ = uv.xy * 2 - 1;
				float dist = min(1, length(posXZ));
				float posY = sqrt(1 - dist * dist);

				float3 pos = float3(posXZ.x, posY, posXZ.y);
				float3 vec = normalize(pos);

				return texCUBE(_SkyCube, vec);
			}

			ENDCG
		}
	}
}
