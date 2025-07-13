//=====================================================
// SHADER.FX - Shader Optimizado para Círculos y Formas
// Autor: MIWELO
// Versión: 1.0.0
// Descripción: Shader HLSL optimizado para renderizado de círculos
//=====================================================

//=====================================================
// VARIABLES GLOBALES
//=====================================================
float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;
float4x4 gWorld : WORLD;
float4x4 gView : VIEW;
float4x4 gProjection : PROJECTION;

// Parámetros del tiempo y animación
float gTime : TIME;
float gDeltaTime;

// Parámetros del círculo
float2 gCircleCenter = float2(0.5, 0.5);
float gCircleRadius = 0.5;
float gCircleThickness = 0.02;
float4 gCircleColor = float4(1, 1, 1, 1);
float4 gBackgroundColor = float4(0, 0, 0, 0);

// Parámetros de anti-aliasing
float gAntiAliasing = 1.0;
float gSmoothness = 0.005;

// Parámetros de animación
float gPulseSpeed = 1.0;
float gPulseIntensity = 0.1;
bool gEnablePulse = false;

// Parámetros de gradiente
float4 gGradientColorStart = float4(1, 1, 1, 1);
float4 gGradientColorEnd = float4(0.5, 0.5, 0.5, 1);
bool gEnableGradient = false;

// Parámetros de progreso (para barras circulares)
float gProgress = 1.0;
float gStartAngle = 0.0;
float gEndAngle = 6.28318; // 2 * PI

// Textura principal
texture gTexture;
sampler gTextureSampler = sampler_state
{
    Texture = <gTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

//=====================================================
// ESTRUCTURAS DE DATOS
//=====================================================

// Vertex Shader Input
struct VSInput
{
    float3 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
};

// Vertex Shader Output / Pixel Shader Input
struct PSInput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
    float2 WorldPos : TEXCOORD1;
};

//=====================================================
// FUNCIONES AUXILIARES
//=====================================================

// Función para calcular distancia a un círculo
float CircleDistance(float2 pos, float2 center, float radius)
{
    return length(pos - center) - radius;
}

// Función de suavizado para anti-aliasing
float Smoothstep(float edge0, float edge1, float x)
{
    float t = saturate((x - edge0) / (edge1 - edge0));
    return t * t * (3.0 - 2.0 * t);
}

// Función para convertir ángulo a posición en círculo
float2 AngleToPosition(float angle, float2 center, float radius)
{
    return center + float2(cos(angle), sin(angle)) * radius;
}

// Función para calcular ángulo desde el centro
float PositionToAngle(float2 pos, float2 center)
{
    float2 dir = normalize(pos - center);
    return atan2(dir.y, dir.x);
}

// Función de interpolación para gradientes
float4 LerpColor(float4 colorA, float4 colorB, float t)
{
    return colorA + (colorB - colorA) * t;
}

//=====================================================
// VERTEX SHADER
//=====================================================

PSInput CircleVS(VSInput input)
{
    PSInput output;
    
    // Transformar posición a espacio de pantalla
    output.Position = mul(float4(input.Position, 1.0), gWorldViewProjection);
    
    // Pasar coordenadas de textura
    output.TexCoord = input.TexCoord;
    
    // Pasar color del vértice
    output.Color = input.Color;
    
    // Calcular posición mundial para cálculos en pixel shader
    output.WorldPos = input.TexCoord;
    
    return output;
}

//=====================================================
// PIXEL SHADERS
//=====================================================

// Pixel Shader para círculo simple
float4 CirclePS(PSInput input) : COLOR0
{
    float2 pos = input.TexCoord;
    float2 center = gCircleCenter;
    
    // Aplicar pulso si está habilitado
    float radius = gCircleRadius;
    if (gEnablePulse)
    {
        float pulse = sin(gTime * gPulseSpeed) * gPulseIntensity;
        radius += pulse;
    }
    
    // Calcular distancia al círculo
    float distance = CircleDistance(pos, center, radius);
    
    // Aplicar anti-aliasing
    float alpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, distance);
    
    // Aplicar gradiente si está habilitado
    float4 finalColor = gCircleColor;
    if (gEnableGradient)
    {
        float gradientFactor = length(pos - center) / radius;
        finalColor = LerpColor(gGradientColorStart, gGradientColorEnd, gradientFactor);
    }
    
    // Combinar con color del vértice
    finalColor *= input.Color;
    finalColor.a *= alpha;
    
    return finalColor;
}

// Pixel Shader para círculo con borde
float4 CircleBorderPS(PSInput input) : COLOR0
{
    float2 pos = input.TexCoord;
    float2 center = gCircleCenter;
    
    // Calcular distancias para borde interior y exterior
    float outerRadius = gCircleRadius;
    float innerRadius = gCircleRadius - gCircleThickness;
    
    float outerDistance = CircleDistance(pos, center, outerRadius);
    float innerDistance = CircleDistance(pos, center, innerRadius);
    
    // Calcular alpha para el borde
    float outerAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, outerDistance);
    float innerAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, innerDistance);
    
    float borderAlpha = outerAlpha - innerAlpha;
    
    float4 finalColor = gCircleColor * input.Color;
    finalColor.a *= borderAlpha;
    
    return finalColor;
}

// Pixel Shader para barra de progreso circular
float4 CircleProgressPS(PSInput input) : COLOR0
{
    float2 pos = input.TexCoord;
    float2 center = gCircleCenter;
    
    // Calcular ángulo actual
    float currentAngle = PositionToAngle(pos, center);
    
    // Normalizar ángulo a rango [0, 2π]
    if (currentAngle < 0) currentAngle += 6.28318;
    
    // Calcular ángulo final basado en progreso
    float progressAngle = gStartAngle + (gEndAngle - gStartAngle) * gProgress;
    
    // Verificar si el pixel está dentro del rango de progreso
    bool inProgress = false;
    if (gStartAngle <= gEndAngle)
    {
        inProgress = (currentAngle >= gStartAngle && currentAngle <= progressAngle);
    }
    else
    {
        inProgress = (currentAngle >= gStartAngle || currentAngle <= progressAngle);
    }
    
    // Calcular distancia al círculo
    float distance = CircleDistance(pos, center, gCircleRadius);
    float alpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, distance);
    
    // Solo mostrar si está en el rango de progreso
    if (!inProgress) alpha = 0.0;
    
    float4 finalColor = gCircleColor * input.Color;
    finalColor.a *= alpha;
    
    return finalColor;
}

// Pixel Shader para arco
float4 ArcPS(PSInput input) : COLOR0
{
    float2 pos = input.TexCoord;
    float2 center = gCircleCenter;
    
    // Calcular ángulo actual
    float currentAngle = PositionToAngle(pos, center);
    if (currentAngle < 0) currentAngle += 6.28318;
    
    // Verificar si está en el rango del arco
    bool inArc = false;
    if (gStartAngle <= gEndAngle)
    {
        inArc = (currentAngle >= gStartAngle && currentAngle <= gEndAngle);
    }
    else
    {
        inArc = (currentAngle >= gStartAngle || currentAngle <= gEndAngle);
    }
    
    // Calcular distancias para el grosor del arco
    float outerRadius = gCircleRadius + gCircleThickness * 0.5;
    float innerRadius = gCircleRadius - gCircleThickness * 0.5;
    
    float outerDistance = CircleDistance(pos, center, outerRadius);
    float innerDistance = CircleDistance(pos, center, innerRadius);
    
    float outerAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, outerDistance);
    float innerAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, innerDistance);
    
    float arcAlpha = outerAlpha - innerAlpha;
    
    // Solo mostrar si está en el arco
    if (!inArc) arcAlpha = 0.0;
    
    float4 finalColor = gCircleColor * input.Color;
    finalColor.a *= arcAlpha;
    
    return finalColor;
}

// Pixel Shader para medidor (gauge)
float4 GaugePS(PSInput input) : COLOR0
{
    float2 pos = input.TexCoord;
    float2 center = gCircleCenter;
    
    // Calcular múltiples arcos para marcas del medidor
    float currentAngle = PositionToAngle(pos, center);
    if (currentAngle < 0) currentAngle += 6.28318;
    
    // Normalizar al rango del medidor
    float normalizedAngle = (currentAngle - gStartAngle) / (gEndAngle - gStartAngle);
    
    // Crear marcas cada 10% del medidor
    float markSpacing = 0.1;
    float markWidth = 0.02;
    
    float markPosition = fmod(normalizedAngle, markSpacing);
    bool isMark = (markPosition < markWidth) || (markPosition > markSpacing - markWidth);
    
    // Calcular distancias para diferentes radios
    float outerRadius = gCircleRadius;
    float middleRadius = gCircleRadius * 0.9;
    float innerRadius = gCircleRadius * 0.8;
    
    float outerDistance = CircleDistance(pos, center, outerRadius);
    float middleDistance = CircleDistance(pos, center, middleRadius);
    float innerDistance = CircleDistance(pos, center, innerRadius);
    
    float outerAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, outerDistance);
    float middleAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, middleDistance);
    float innerAlpha = 1.0 - Smoothstep(-gSmoothness, gSmoothness, innerDistance);
    
    // Borde exterior
    float borderAlpha = outerAlpha - middleAlpha;
    
    // Marcas interiores
    float markAlpha = isMark ? (middleAlpha - innerAlpha) : 0.0;
    
    float totalAlpha = borderAlpha + markAlpha;
    
    float4 finalColor = gCircleColor * input.Color;
    finalColor.a *= totalAlpha;
    
    return finalColor;
}

//=====================================================
// TÉCNICAS
//=====================================================

// Técnica para círculo simple
technique CircleTechnique
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 CircleVS();
        PixelShader = compile ps_2_0 CirclePS();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        
        ZEnable = false;
        ZWriteEnable = false;
        
        CullMode = None;
    }
}

// Técnica para círculo con borde
technique CircleBorderTechnique
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 CircleVS();
        PixelShader = compile ps_2_0 CircleBorderPS();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        
        ZEnable = false;
        ZWriteEnable = false;
        
        CullMode = None;
    }
}

// Técnica para barra de progreso circular
technique CircleProgressTechnique
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 CircleVS();
        PixelShader = compile ps_2_0 CircleProgressPS();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        
        ZEnable = false;
        ZWriteEnable = false;
        
        CullMode = None;
    }
}

// Técnica para arcos
technique ArcTechnique
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 CircleVS();
        PixelShader = compile ps_2_0 ArcPS();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        
        ZEnable = false;
        ZWriteEnable = false;
        
        CullMode = None;
    }
}

// Técnica para medidores
technique GaugeTechnique
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 CircleVS();
        PixelShader = compile ps_2_0 GaugePS();
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        
        ZEnable = false;
        ZWriteEnable = false;
        
        CullMode = None;
    }
}

//=====================================================
// FALLBACK TECHNIQUE (para hardware más antiguo)
//=====================================================
technique FallbackTechnique
{
    pass Pass1
    {
        // Usar pipeline fijo para compatibilidad
        Lighting = false;
        
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        
        ZEnable = false;
        ZWriteEnable = false;
        
        CullMode = None;
        
        // Color simple sin shaders
        ColorOp[0] = SelectArg1;
        ColorArg1[0] = Diffuse;
        
        AlphaOp[0] = SelectArg1;
        AlphaArg1[0] = Diffuse;
    }
}