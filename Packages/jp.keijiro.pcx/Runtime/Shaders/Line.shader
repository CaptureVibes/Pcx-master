Shader "Point Cloud/Line"
{
    Properties
    {
        _Tint("Tint", Color) = (0.5, 0.5, 0.5, 1)
        _LineLength("Line Length", Float) = 0.1
        _Direction("Direction", Vector) = (0, 1, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 position : POSITION;
                half3 color : COLOR;
            };

            struct Varyings
            {
                float4 position : SV_Position;
                half3 color : COLOR;
                float3 worldPos; // 用于手动处理雾效
            };

            half4 _Tint;
            float4x4 _Transform;
            half _LineLength;
            float4 _Direction;

            // 确保 StructuredBuffer 正确声明
            StructuredBuffer<float4> _PointBuffer; // 声明 PointBuffer

            Varyings Vertex(uint vid : SV_VertexID)
            {
                Varyings o;

                // Fetch point data from buffer
                float4 pt = _PointBuffer[vid / 2]; // 每两个顶点组成一条线，两个顶点从同一个点生成

                // 计算当前顶点是线的起点还是终点
                bool isStart = (vid % 2) == 0;

                float4 pos = mul(_Transform, float4(pt.xyz, 1));

                half3 col = PcxDecodeColor(asuint(pt.w));

                // Adjust for line start and end
                if (isStart)
                {
                    o.position = TransformObjectToHClip(pos); // 线的起点
                }
                else
                {
                    // 线的终点 = 起点 + 偏移
                    float4 endPos = pos + (_Direction * _LineLength);
                    o.position = TransformObjectToHClip(endPos); // 线的终点
                }

                // 设置世界空间位置用于雾效计算
                o.worldPos = mul(unity_ObjectToWorld, pos).xyz;

                // Adjust color based on tint and color space
            #ifdef UNITY_COLORSPACE_GAMMA
                col *= _Tint.rgb * 2;
            #else
                col *= LinearToGammaSpace(_Tint.rgb) * 2;
                col = GammaToLinearSpace(col);
            #endif

                o.color = col;

                return o;
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                half4 c = half4(input.color, _Tint.a);

                // 使用 URP 提供的雾函数
                c.rgb = ApplyFog(input.worldPos, c.rgb);

                return c;
            }

            ENDHLSL
        }
    }
}
