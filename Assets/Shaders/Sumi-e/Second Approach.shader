Shader "bentoBAUX/Second Approach"
{
    Properties
    {
        // === BASE MATERIAL SETTINGS ===
        [Header(Base Colours)][Space(10)]
        _LightTint("Light Tint", Color) = (1,1,1,1)
        _DarkTint("Dark Tint", Color) = (1,1,1,1)
        _BaseTexture("Base Texture", 2D) = "white" {}
        _Alpha("Alpha", Range(0,1)) = 1

        [Toggle(SWITCH)] _Switch("Swap Colours", float) = 0

        [Header(Texture Coordinates)][Space(10)]
        [Enum(UV, 2, Object, 3, World, 4)] _TextureSpace("Texture Space", Float) = 2


        [Header(Gradient Band Controls)][Space(10)]
        [Enum(Linear, 1, Ease, 2)] _InterpolationType("Interpolation Type", Float) = 1

        _BandCentre("Band Centre", Float) = 0.5
        _BandThickness("Band Thickness", Range(0,1)) = 0.5
        [Toggle(SHOWCENTRELINE)] _ShowCentreLine("Show Centre Line", float) = 0

        [Header(Emissiveness)][Space(10)]
        [Toggle(USEEMISSIVE)] _UseEmissive("Use Emissive", float) = 0
        _LightEmissiveness("Light Tint Emissiveness", float) = 1
        _DarkEmissiveness("Dark Tint Emissiveness", float) = 1



    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "Queue" = "Geometry"
        }


        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            ZWrite On

            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature SWITCH
            #pragma shader_feature USEEMISSIVE
            #pragma shader_feature SHOWCENTRELINE
            #pragma shader_feature INTERPOLATION

            #pragma multi_compile_fog
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
                float2 uv : TEXCOORD6;
            };

            float4 _LightTint;
            float4 _DarkTint;
            float _Alpha;

            float _LightEmissiveness;
            float _DarkEmissiveness;

            int _InterpolationType;

            float _BandCentre;
            float _BandThickness;

            int _TextureSpace;
            float _MixAmount;

            sampler2D _BaseTexture;

            // Function Prototypes
            half3 ProcessNormals(v2f input);


            float ramp_linear(float t, float centre, float halfWidth)
            {
                float a = centre - halfWidth;
                float b = centre + halfWidth;
                float denom = max(1e-5, b - a); // Prevent divide-by-zero
                return saturate((t - a) / denom); // Map Range with Clamp
            }

            float ramp_ease(float t, float centre, float halfWidth)
            {
                float u = ramp_linear(t, centre, halfWidth);
                return u * u * (3.0 - 2.0 * u);
            }

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/ShaderLibrary/Maths/TextureCoordinate.hlsl"

            // Vertex shader: transforms vertex data and prepares inputs for the fragment shader
            v2f vert(appdata input)
            {
                v2f output;

                // Transform object-space position into world space and clip space
                VertexPositionInputs positions = GetVertexPositionInputs(input.vertex);
                output.fragLocalPos = input.vertex; // Store local-space position (useful for procedural effects)
                output.fragWorldPos = positions.positionWS; // Store world-space position (used for lighting, shadows, etc.)
                output.fragHCS = positions.positionCS; // Store homogeneous clip space position (used for screen-space effects)

                // Pass transformed texture coordinates to the fragment shader
                output.uv = input.uv;

                return output;
            }

            half4 frag(v2f input) : SV_Target
            {
                // Derive coordinate system for procedural noise
                // "Texture Coordinate" node in Blender for sampling in Generated, Normal, UV, Object and World space
                float3 texCoord = GetTextureSpace(_TextureSpace, float3(0, 0, 0) /* Not needed here */, input.fragLocalPos, input.fragWorldPos, input.uv);

                // Allow swapping between light and dark tint
                #ifdef SWITCH
                half3 temp = _LightTint.rgb;
                _LightTint.rgb = _DarkTint.rgb;
                _DarkTint.rgb = temp;
                #endif

                float bandHalfWidth = saturate(_BandThickness / 2); // [0, 0.5]

                float t = texCoord.y; // Gradient is based on y value.
                float epsilon = 0.002; // Thickness of centre line.

                #ifdef SHOWCENTRELINE
                if (abs(t - _BandCentre) < epsilon)
                    return half4(1, 0, 0, 1);
                #endif

                // Set interpolation types
                float fac;
                if (_InterpolationType == 1)
                {
                    fac = ramp_linear(t, _BandCentre, bandHalfWidth);
                }
                else if (_InterpolationType == 2)
                {
                    fac = ramp_ease(t, _BandCentre, bandHalfWidth);
                }

                float3 base = tex2D(_BaseTexture, input.uv).rgb;
                half3 finalColour = lerp(_LightTint.rgb, _DarkTint.rgb * base, fac);

                // Allow use of emissiveness
                #ifdef USEEMISSIVE
                    float3 emissive = lerp(_LightTint.rgb * _LightEmissiveness, _DarkTint.rgb * _DarkEmissiveness, fac);
                    finalColour += emissive;
                #endif

                return half4(finalColour, _Alpha);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}