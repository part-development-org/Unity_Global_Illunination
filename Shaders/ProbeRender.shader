Shader "Hidden/ProbeRender"
{
	Properties
	{
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		////////////////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////////////////
		Pass
		{ Name "GI color Outdoor"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#pragma target 3.0
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"
			#include "AutoLight.cginc"
			#pragma target 4.0

			//Текстуры
			sampler2D _CameraDepthTexture;
			float4 _CameraDepthTexture_ST;
			sampler2D _CameraDepthNormalsTexture;

			sampler2D _worldColor00, _worldColor01, _worldColor02, _worldColor03, _worldColor04;
			sampler2D _NormalDepth00, _NormalDepth01, _NormalDepth02, _NormalDepth03, _NormalDepth04;
			sampler2D _Position00, _Position01, _Position02, _Position03, _Position04;
			float4 _camDir00, _camDir01, _camDir02, _camDir03, _camDir04;
			float4x4 _c2w00, _c2w01, _c2w02, _c2w03, _c2w04;
			float4x4 _w2c00, _w2c01, _w2c02, _w2c03, _w2c04;
			float4 _eventPosition;

			UNITY_DECLARE_TEX2DARRAY(_volGIcol);

			//Переменные
			float _ProbeField, _ProbeHeigth;

			struct appdata	{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)	{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;										
				return o;
			}

			//Функция проекции точки на UV семплируемой текстуры
			float2 GIcamUV (float3 wsPos, float4x4 _w2c) {
				float3 newUV = (mul(_w2c, float4(wsPos.x, wsPos.y, wsPos.z, 0)) / (_ProbeField * 0.5)) * 0.5 + 0.5;
				return newUV.xy;
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
			 
			fixed4 fragAO (v2f i) : SV_Target{
				
				//Screen UV
				half2 uv = i.uv;

				//Position World
				float2 uv2w = (uv * 2 - 1) * _ProbeField / 2;
				float3 position = float3(uv2w.x, -9.5 + _ProbeHeigth, uv2w.y);

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

                float mask = step(_eventPosition.w, length(_eventPosition.xyz - position));

				//Random UV for Sampling
				const float2 reandUV[61] = {
					0,0,
					-1,1,	-1,-1,	1,1,	1,-1,	
					-1,0,	0, 1,	1,0,	0,-1,
					-2,0,	0, 2,	2,0,	0,-2,
					-2,2,	-2,-2,	2,2,	2,-2,
					-3,1,	-3,-1,	3,1,	3,-1,
					-1,3,	-1,-3,	1,3,	1,-3,
					-3.5,2,	-3.5,-2,	3.5,2,	3.5,-2,
					-2,3.5,	-2,-3.5,	2,3.5,	2,-3.5,
					-4,0,	0, 4,	4,0,	0,-4,
					-8,0,	0, 8,	8,0,	0,-8,
					-5.6,5.6,	-5.6,-5.6,	5.6,5.6,	5.6,-5.6,
					-7.5,3,	-7.5,-3,	7.5,3,	7.5,-3,
					-3,7.5,	-3,-7.5,	3,7.5,	3,-7.5,
					-16,0,	0, 16,	16,0,	0,-16,
					-11,11,	-11,-11,	11,11,	11,-11,
				};

				half samples = 61;
				float4 sLv = 0;

				if (mask > 0.001){

					sLv = UNITY_SAMPLE_TEX2DARRAY(_volGIcol, float3(uv, _ProbeHeigth));

				} else {

					for(int i = 0; i < samples; i++){ 
						///////////////////////
						/////Sky calculate/////
						///////////////////////
						//RandomVector
						float2 rndTable = reandUV[i] / 256;

						newUV_00 += rndTable;
						newUV_01 += rndTable;
						newUV_02 += rndTable;
						newUV_03 += rndTable;
						newUV_04 += rndTable;

		               	float4 newNrmDepth_00 = tex2D(_NormalDepth00, newUV_00);
		               	float4 newNrmDepth_01 = tex2D(_NormalDepth01, newUV_01);
		               	float4 newNrmDepth_02 = tex2D(_NormalDepth02, newUV_02);
		               	float4 newNrmDepth_03 = tex2D(_NormalDepth03, newUV_03);
		               	float4 newNrmDepth_04 = tex2D(_NormalDepth04, newUV_04);	               

		               	float distanceCheck_00 = smoothstep(0, 1.0, 64 / abs(newNrmDepth_00.a - position00.z));
		               	float distanceCheck_01 = smoothstep(0, 1.0, 64 / abs(newNrmDepth_01.a - position01.z));
		               	float distanceCheck_02 = smoothstep(0, 1.0, 64 / abs(newNrmDepth_02.a - position02.z));
		               	float distanceCheck_03 = smoothstep(0, 1.0, 64 / abs(newNrmDepth_03.a - position03.z));
		               	float distanceCheck_04 = smoothstep(0, 1.0, 64 / abs(newNrmDepth_04.a - position04.z));

						distanceCheck_00 *= (dot(float3(0,1,0), newNrmDepth_00.xyz) * 0.5 + 0.5);
		               	distanceCheck_01 *= (dot(float3(0,1,0), newNrmDepth_01.xyz) * 0.5 + 0.5);
		               	distanceCheck_02 *= (dot(float3(0,1,0), newNrmDepth_02.xyz) * 0.5 + 0.5);
		               	distanceCheck_03 *= (dot(float3(0,1,0), newNrmDepth_03.xyz) * 0.5 + 0.5);
		               	distanceCheck_04 *= (dot(float3(0,1,0), newNrmDepth_04.xyz) * 0.5 + 0.5);

		               	float x_00 = max(0, step(newNrmDepth_00.a, position00.z)) * distanceCheck_00;
		               	float x_01 = max(0, step(newNrmDepth_01.a, position01.z)) * distanceCheck_01;
		               	float x_02 = max(0, step(newNrmDepth_02.a, position02.z)) * distanceCheck_02;
		               	float x_03 = max(0, step(newNrmDepth_03.a, position03.z)) * distanceCheck_03;
		               	float x_04 = max(0, step(newNrmDepth_04.a, position04.z)) * distanceCheck_04;

		               	sLv.a += 1 - (x_00 + x_01  + x_02 + x_03 + x_04) / 5;
		               	 
						///////////////////////
						/////GI  calculate/////
						///////////////////////

		               	float3 newPosition_00 = tex2D(_Position00, newUV_00).xyz - normalize(_camDir00.xyz);
		               	float3 newPosition_01 = tex2D(_Position01, newUV_01).xyz - normalize(_camDir01.xyz);
		               	float3 newPosition_02 = tex2D(_Position02, newUV_02).xyz - normalize(_camDir02.xyz);
		               	float3 newPosition_03 = tex2D(_Position03, newUV_03).xyz - normalize(_camDir03.xyz);
		               	float3 newPosition_04 = tex2D(_Position04, newUV_04).xyz - normalize(_camDir04.xyz);

		               	float3 color_00 = tex2D(_worldColor00, newUV_00).xyz;
		               	float3 color_01 = tex2D(_worldColor01, newUV_01).xyz;
		               	float3 color_02 = tex2D(_worldColor02, newUV_02).xyz;
		               	float3 color_03 = tex2D(_worldColor03, newUV_03).xyz;
		               	float3 color_04 = tex2D(_worldColor04, newUV_04).xyz;

		               	float3 WP2newWP_00 = position - newPosition_00;
		               	float3 WP2newWP_01 = position - newPosition_01;
		               	float3 WP2newWP_02 = position - newPosition_02;
		               	float3 WP2newWP_03 = position - newPosition_03;
		               	float3 WP2newWP_04 = position - newPosition_04;

						float RayLength_00 = length(WP2newWP_00);
						float RayLength_01 = length(WP2newWP_01);
						float RayLength_02 = length(WP2newWP_02);
						float RayLength_03 = length(WP2newWP_03);
						float RayLength_04 = length(WP2newWP_04);

						float3 RayDir_00 = normalize(WP2newWP_00);
						float3 RayDir_01 = normalize(WP2newWP_01);
						float3 RayDir_02 = normalize(WP2newWP_02);
						float3 RayDir_03 = normalize(WP2newWP_03);
						float3 RayDir_04 = normalize(WP2newWP_04);

						//Calculate intensety of ray
						float rayVal_00 = (1 - smoothstep( 0, 32, RayLength_00)) * max(0, dot(RayDir_00, newNrmDepth_00.xyz));
						float rayVal_01 = (1 - smoothstep( 0, 32, RayLength_01)) * max(0, dot(RayDir_01, newNrmDepth_01.xyz));
						float rayVal_02 = (1 - smoothstep( 0, 32, RayLength_02)) * max(0, dot(RayDir_02, newNrmDepth_02.xyz));
						float rayVal_03 = (1 - smoothstep( 0, 32, RayLength_03)) * max(0, dot(RayDir_03, newNrmDepth_03.xyz));
						float rayVal_04 = (1 - smoothstep( 0, 32, RayLength_04)) * max(0, dot(RayDir_04, newNrmDepth_04.xyz));

						float3 newAlbedo = (color_00 * rayVal_00 +
											color_01 * rayVal_01 +
											color_02 * rayVal_02 +
											color_03 * rayVal_03 +
											color_04 * rayVal_04) / 5;

						sLv.xyz += newAlbedo;
					}

					sLv /= samples;
					sLv.xyz = max(0, sLv.xyz) * 1.25; 
					sLv.a = smoothstep(0, 0.8, sLv.a);
					sLv.a = pow(sLv.a, 1.8); 
				}

				return sLv;
			}

			ENDCG
		}

		Pass
		{ Name "GI color Indoor"

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragAO
			#pragma target 3.0
			#include "UnityCG.cginc"
			#include "UnityGBuffer.cginc"
			#include "AutoLight.cginc"
			#pragma target 4.0

			//Текстуры
			sampler2D _CameraDepthTexture;
			float4 _CameraDepthTexture_ST;
			sampler2D _CameraDepthNormalsTexture;
			sampler2D _worldColor, _worldNormal, _worldPosition, _InterierMask_0;
			//Матрицы для камеры
			float4x4 _GIw2c, _c2w;
			//Переменные
			float _ProbeField, _RayLength, _ProbeHeigth; 
			float4 _eventPosition;

			UNITY_DECLARE_TEX2DARRAY(_InteriorGIcol); 

			struct appdata	{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
			};

			struct v2f	{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)	{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;										
				return o;
			}

			////////////////
			//////Depth/////
			////////////////
			float CheckPerspective(float x){
			    return lerp(x, 1.0, unity_OrthoParams.w);
			}
			//Реконструкция экранных координат
			float3 ReconstructViewPos(float2 uv, float depth, float2 p11_22, float2 p13_31){
			    return float3((uv * 2.0 - 1.0 - p13_31) / p11_22 * CheckPerspective(depth), depth);
			}
			//Функция для рассчёта координат точки в пространстве семплируемой текстуры (координатах солнца и камеры для солнца)
			float2 GIcamUV (float3 wsPos) {
				float3 newUV = (mul(_GIw2c, float4(wsPos.x, wsPos.y, wsPos.z, 0)) / (_ProbeField * 0.5)) * 0.5 + 0.5;
				return newUV.xy;
			}

			fixed4 fragAO (v2f i) : SV_Target{
				
				//Screen UV
				half2 uv = i.uv;

				//Position Sky
				float o_depth = _WorldSpaceCameraPos.y - 0.5 - _ProbeHeigth;
				float4x4 proj = (float4x4)unity_CameraProjection;
				const float2 p11_22 = (unity_CameraProjection._11, unity_CameraProjection._22);
				const float2 p13_31 = (unity_CameraProjection._13, unity_CameraProjection._23);
				float3 positionSky = ReconstructViewPos(uv, o_depth, p11_22, p13_31);
				//Position World
				float2 uv2w = (uv * 2 - 1) * _ProbeField / 2;
				float3 position = float3(uv2w.x, 0.5 + _ProbeHeigth, uv2w.y); 

				const float2 getWallBlock[49] = {
					0,0,
					0,0,	0,0,	0,0,	0,0,
					0,0, 	0,0,	0,0,	0,0,

					0,1,	0,2, 	0,3,	0,4,
					0,5,	0,6, 	0,7,	0,8,
					1,5,	2,5, 	3,7,	4,7,
					1,8,	2,6, 	3,8,	4,6,

					0,9, 	0,10, 	0,11, 	0,12,
					17,13,	18,13,	19,15,	20,15,
					21,16,	22,14,	23,16,	24,14,

					0,13, 	0,14, 	0,15, 	0,16,
					29,25, 	30,26, 	31,27, 	32,28,
					33,25, 	34,26, 	35,27, 	36,28,
				};

				//Random UV for Sampling
				const float2 reandUV[49] = {
					0,0,
					-1,-1,	-1,1,	1,-1, 	1,1,		
					-1,0,	0, 1, 	1,0,	0,-1,  

					-2,-2,	-2,2,	2,-2,	2,2,
					-2,0,	0, 2,	2,0,	0,-2,							
					-2,-1,	-2,1,	2,-1,	2,1,	
					-1,-2,	-1,2,	1,-2,	1,2,	

					-3,-3,  -3,3,	3,-3,   3,3,
					-3,-1,	-3,1,	3,-1,	3,1, 
					-1,-3,	-1,3,	1,-3,	1,3,

					-4,0,	0, 4,	4,0,	0,-4,
					-4,-2,	-4,2,	4,-2,	4,2,	
					-2,-4,	-2,4,	2,-4,	2,4,	
				};

				float mask = step(_eventPosition.w, length(_eventPosition.xyz - position));

				float4 sLv = 0;


					float wallSkyBlock[49];
					float wallGIBlock[49];
					half samples = 49;

					for(int i = 0; i < samples; i++){

						float2 gwb = getWallBlock[i];
						
						///////////////////////
						/////Sky calculate/////
						///////////////////////
						float2 rUV = reandUV[i];
						float2 newUVsky = uv + rUV / _ScreenParams.xy;

						float4 interiorMask = tex2D(_InterierMask_0, newUVsky);
						float callingBlock = 1 - step(interiorMask.a + 2.1 + interiorMask.x * 5, position.y);
						interiorMask.xyz = clamp(interiorMask.xyz, 0, 1);
						interiorMask.x = clamp(interiorMask.x * 256, 0, 1);

						float blockSkyLight = (wallSkyBlock[gwb.x] + wallSkyBlock[gwb.y])/2;

						if(i < 1){
							wallSkyBlock[i] = 1;
						} else {
							wallSkyBlock[i] = step(0, 0.5 - interiorMask.z);
						}

						float SkyRayLength = 1 - smoothstep( 0, 5.5, length(rUV));
						float sky = (1 - smoothstep(position.y, position.y + SkyRayLength, interiorMask.a + 1 - (interiorMask.y - interiorMask.z))) * interiorMask.y;
						sky *= SkyRayLength;
						sky *= blockSkyLight;
						sLv.a += sky;

						///////////////////////
						/////GI  calculate/////
						///////////////////////
						float2 newUVgi = GIcamUV(position + float3(rUV.x, 0, rUV.y));

	//					//Get Position And Normal
						float3 newNormal = tex2D(_worldNormal, newUVgi);
						float3 newWorldPosition = tex2D(_worldPosition, newUVgi);

						float2 wUV = (newWorldPosition.xz) / _ProbeField + 0.5;

						float4 interiorMaskGI = tex2D(_InterierMask_0, wUV);
						interiorMaskGI.x = step(newWorldPosition.y, interiorMaskGI.a + 2.1 + interiorMaskGI.x * 5);

						float3 WP2newWP = position - newWorldPosition;
						float RayLength = length(WP2newWP);
						float3 RayDir = normalize(WP2newWP);

						if(i < 1){
							wallGIBlock[i] = 1;
						} else {
							wallGIBlock[i] = step(0, 0.5 - interiorMaskGI.z);
						}

						float blockGILight = (wallGIBlock[gwb.x] + wallGIBlock[gwb.y])/2;

						//Calculate intensety of ray
						float rayVal = 1 - smoothstep( 0, 10, RayLength);
						rayVal *= max(0, dot(RayDir, newNormal)*0.5 + 0.2) * 2;
						//Get color
						float3 newAlbedo = tex2D(_worldColor, newUVgi);
						newAlbedo *= rayVal * blockGILight * interiorMaskGI.x * 3.1415;
						sLv.xyz += newAlbedo;

					}
					sLv /= samples;
					sLv.xyz = max(0,sLv.xyz);
					sLv.a = max(0, (sLv.a * 3 + 0.05) / 1.05); 

				return sLv;
			}

			ENDCG
		}
	}
}
