Shader "bentoBAUX/Sumi-E"
{
    Properties
    {
        // === BASE MATERIAL SETTINGS ===
        [Header(Base Colour)][Space(10)]
        _DiffuseColour("Diffuse Colour", Color) = (1,1,1,1)
        _AlbedoTex ("Albedo Texture", 2D) = "white"{}

        [Space(10)]
        [Toggle(USETRANSPARENT)] _UseTransparent("Use Transparent", float) = 0
        _AlphaCutoff("Alpha Cutoff", Range(0, 1)) = 0.5

        [Space(10)]
        _NormalTex ("Normal Map", 2D) = "bump"{}
        _NormalStrength ("Normal Strength", Float) = 1

        [Space(10)]
        [Toggle(USEEMISSIVE)] _Emissive("Emissive", float) = 0
        _EmissiveTex ("Emissive Map", 2D) = "emissive" {}
        [HDR] _EmissiveColour("Emissive Colour", Color) = (1,1,1,1)

        // === BLINN-PHONG LIGHTING ===
        [Header(Blinn Phong Lighting)][Space(10)]
        [Toggle(SPECULAR)] _Specular("Enable Specular Highlight", Float) = 1
        _k ("k Coefficients (Ambient, Diffuse, Specular)", Vector) = (0.5, 0.5, 0.8)
        _SpecularExponent("Specular Exponent", Float) = 80

        // === COLOUR RAMP ===
        [Header(Colour Ramp Tones)][Space(10)]
        [Toggle(USECOLOURRAMP)] _UseColourRamp("Use Colour Ramp", Float) = 1
        _DarkTone ("Dark Tone", Color) = (0.05, 0.05, 0.2, 1)
        _MidDarkTone ("Mid Dark Tone", Color) = (0.1, 0.1, 0.3, 1)
        _MiddleTone ("Middle Tone", Color) = (0.25, 0.3, 0.7, 1)
        _MidLightTone ("Mid Light Tone", Color) = (0.5, 0.6, 0.9, 1)
        _LightTone ("Light Tone", Color) = (0.8, 0.85, 0.95, 1)
        _Highlight ("Highlight", Color) = (1.0, 1.0, 1.0, 1)

        [Header(Colour Ramp Positions)][Space(10)]
        _RampPositions0 ("Positions p0–p2 (xyz)", Vector) = (0.2, 0.4, 0.6)
        _RampPositions1 ("Positions p3–p5 (xyz)", Vector) = (0.8, 0.9, 1.0)

        // === NOISE SETTINGS ===
        [Header(Texture Coordinates)][Space(10)]
        [Enum(Generated, 0, Normal, 1, UV, 2, Object, 3)] _TextureSpace("Texture Space", Float) = 1

        [Header(Voronoi Noise Settings)][Space(10)]
        [Enum(Euclidean, 1, Manhattan, 2, Chebyshev, 3, Minkowski, 4)]
        _DistanceMetric ("Distance Metric", Float) = 1
        _VoronoiScale ("Voronoi Scale", Float) = 2.2
        _VoronoiExponent ("Voronoi Exponent", Float) = 1.0
        _VoronoiSmoothness ("Voronoi Smoothness", Range(0,1)) = 0.5
        _VoronoiRandomness ("Voronoi Randomness", Range(0,1)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue"="Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma shader_feature SPECULAR
            #pragma shader_feature USECOLOURRAMP
            #pragma shader_feature USEEMISSIVE
            #pragma shader_feature USETRANSPARENT
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #define MAX_RAMP_STOPS 64

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD2;
            };

            struct v2f
            {
                float4 fragHCS : SV_POSITION;
                float3 fragWorldPos : TEXCOORD0;
                float3 fragLocalPos : TEXCOORD1;
                float3x3 TBN : TEXCOORD2;
                float3 generatedCoord : TEXCOORD5;
                float2 uv_Albedo : TEXCOORD6;
                float2 uv_Emissive : TEXCOORD7;
            };

            // ============================
            // BASE MATERIAL UNIFORMS
            // ============================
            float4 _DiffuseColour;
            sampler2D _AlbedoTex;
            half4 _AlbedoTex_ST;

            half _AlphaCutoff;

            sampler2D _NormalTex;
            half4 _NormalTex_ST;
            half _NormalStrength;

            sampler2D _EmissiveTex;
            half4 _EmissiveTex_ST;
            half4 _EmissiveColour;

            // ============================
            // BLINN-PHONG LIGHTING UNIFORMS
            // ============================
            float3 _k; // (Ambient, Diffuse, Specular)
            float _SpecularExponent;
            #ifdef SPECULAR
            float _Specular; // Only if [Toggle(SPECULAR)] is active
            #endif


            // ============================
            // COLOUR RAMP UNIFORMS
            // ============================
            half3 _DarkTone;
            half3 _MidDarkTone;
            half3 _MiddleTone;
            half3 _MidLightTone;
            half3 _LightTone;
            half3 _Highlight;

            half4 _RampPositions0; // (p0, p1, p2)
            half4 _RampPositions1; // (p3, p4, p5)

            // ============================
            // TEXTURE COORDINATES SETTINGS
            // ============================
            int _TextureSpace;
            float _MixAmount;

            // ============================
            // NOISE: VORONOI
            // ============================
            float _VoronoiScale;
            float _VoronoiExponent;
            float _VoronoiSmoothness;
            float _VoronoiRandomness;
            int _DistanceMetric;

            // ============================
            // NOISE: FBM
            // ============================
            float _FbmScale;
            float _FbmRoughness;
            float _FbmLacunarity;
            int _FbmDetail;

            // Function Prototypes
            half3 ProcessNormals(v2f input);

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Assets/Shaders/ShaderLibrary/Lighting/BlinnPhong.hlsl"
            #include "Assets/Shaders/ShaderLibrary/Maths/Voronoi.hlsl"
            #include "Assets/Shaders/ShaderLibrary/Maths/TextureCoordinate.hlsl"
            #include "Assets/Shaders/ShaderLibrary/Colour/ColourRamp.hlsl"

            v2f vert(appdata input)
            {
                v2f output;

                VertexPositionInputs positions = GetVertexPositionInputs(input.vertex);
                output.fragLocalPos = input.vertex;
                output.fragWorldPos = positions.positionWS;
                output.fragHCS = positions.positionCS;

                float3 worldNormal = TransformObjectToWorldNormal(input.normal);
                float3 worldTangent = mul((float3x3)unity_ObjectToWorld, input.tangent);
                float3 bitangent = cross(worldNormal, worldTangent);
                float3 worldBitangent = mul((float3x3)unity_ObjectToWorld, bitangent);

                output.TBN = float3x3(worldTangent, worldBitangent, worldNormal);
                output.uv_Albedo = TRANSFORM_TEX(input.uv, _AlbedoTex);
                output.uv_Emissive = TRANSFORM_TEX(input.uv, _AlbedoTex);

                return output;
            }


            half4 frag(v2f input) : SV_Target
            {
                // Base surface colour: texture * material tint.
                half4 c = tex2D(_AlbedoTex, input.uv_Albedo) * _DiffuseColour;

                // Sampling shadow coords in fragment shader to avoid cascading seams.
                float4 shadowCoords = TransformWorldToShadowCoord(input.fragWorldPos);

                // Retrieve the primary directional (or main) light with shadow + distance attenuation.
                Light mainLight = GetMainLight(shadowCoords);
                
                #ifdef USETRANSPARENT
                clip(c.a - _AlphaCutoff);
                #endif
                half3 emissive;
                #ifdef USEEMISSIVE
                emissive = tex2D(_EmissiveTex, input.uv_Emissive) * _EmissiveColour;
                #else
                emissive = 0;
                #endif

                // Unpacking normals from normal map into world space
                half3 n = ProcessNormals(input);

                // Calculating view vector
                float3 v = normalize(_WorldSpaceCameraPos - input.fragWorldPos);

                // Derive coordinate system for procedural noise
                // "Texture Coordinate" node in Blender for sampling in Generated, Normal, UV, Object space
                half3 noiseCoord = GetTextureSpace(_TextureSpace, n, input.fragLocalPos, input.uv_Albedo);

                float dist; // Voronoi cell distance (unused for now, could drive ink pooling).
                float3 col; // Raw Voronoi cell color (not used directly here).
                float3 pos; // Feature point position (used below to perturb lighting).

                // 3D Smooth F1 Voronoi noise
                // Translated into HLSL from: https://github.com/kinakomoti-321/Voronoi_textures/blob/main/VoronoiTexture/Voronoi.glsl
                VoronoiSmoothF1_3D(noiseCoord * _VoronoiScale, _VoronoiSmoothness, _VoronoiExponent, _VoronoiRandomness, _DistanceMetric, dist, col, pos);

                // Stylised Blinn-Phong lighting
                // Using Voronoi feature point (pos) instead of raw normal injects painterly variation.
                half3 lighting = BlinnPhong(pos, v, mainLight, c) * mainLight.shadowAttenuation * mainLight.distanceAttenuation;

                // Do the same for additional lights
                #if defined(_ADDITIONAL_LIGHTS_VERTEX) || defined(_ADDITIONAL_LIGHTS)
                int addCount = GetAdditionalLightsCount();
                for (int i = 0; i < addCount; i++)
                {
                    Light additionalLight = GetAdditionalLight(i, input.fragWorldPos);
                    half att = additionalLight.distanceAttenuation * additionalLight.shadowAttenuation;
                    lighting += BlinnPhong(pos, v, additionalLight, c) * att;
                }
                #endif

                // Remap lighting through a colour ramp to enforce the sumi-e bands.
                half3 finalColour =
                    #ifdef USECOLOURRAMP
                ColourRamp(lighting);
                    #else
                    lighting;
                #endif

                return half4(finalColour + emissive, 1.0);
            }

            half3 ProcessNormals(v2f input)
            {
                half3 normalMap = UnpackNormal(tex2D(_NormalTex, input.uv_Albedo));
                normalMap.xy *= _NormalStrength;
                return normalize(mul(transpose(input.TBN), normalMap));
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}