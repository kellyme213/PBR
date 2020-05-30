//
//  Rasterizer.metal
//  PBR
//
//  Created by Michael Kelly on 5/19/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

#include <metal_stdlib>
#import "ShaderStructs.h"
using namespace metal;

struct VertexOut
{
    float4 position [[position]];
    float3 worldSpacePosition;
    float2 uv;
    int id;
    float3 normal;
    float3 tangent;
};

vertex VertexOut vertexShader
(
    const device Vertex*        vertices [[buffer(0)]],
    const device SceneUniforms& uniforms [[buffer(1)]],
                 uint           vid      [[vertex_id]]
)
{
    const Vertex vert = vertices[vid];
    VertexOut v;
    v.position = uniforms.projectionMatrix * uniforms.viewMatrix * vert.position;
    v.worldSpacePosition = vert.position.xyz;
    v.uv = vert.uv;
    v.id = vert.materialIndex;
    v.normal = vert.normal;
    v.tangent = vert.tangent;
    
        
    return v;
}

fragment float4 fragmentShader
(
    VertexOut in [[stage_in]],
    const device PointLight* lights [[buffer(0)]],
    const device RasterizeFragmentUniforms& uniforms [[buffer(1)]],
    const texture2d_array<float, access::sample> baseColorTexture [[texture(MATERIAL_BASE_COLOR)]],
    const texture2d_array<float, access::sample> metallicTexture  [[texture(MATERIAL_METALLIC)]],
    const texture2d_array<float, access::sample> roughnessTexture [[texture(MATERIAL_ROUGHNESS)]],
    const texture2d_array<float, access::sample> normalTexture    [[texture(MATERIAL_NORMAL)]]
)
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    
    float3 baseColor = baseColorTexture.sample(s, in.uv, in.id).xyz;
    float metallic = metallicTexture.sample(s, in.uv, in.id).r;
    float roughness = roughnessTexture.sample(s, in.uv, in.id).r;
    float3 tempNormal = normalize(normalTexture.sample(s, in.uv, in.id).xyz);
    
    float3 bitangent = cross(in.normal, in.tangent);
    
    
    float3x3 tbn = transpose(float3x3(in.tangent, bitangent, in.normal));
    
    float3 n = normalize(tbn * (2.0 * tempNormal - 1.0));
    
    //normal mapping does not work at the moment, just using the passed in normal for now...
    n = in.normal;
    
    float3 Lo = float3(0.0, 0.0, 0.0);
    
    for (int x = 0; x < uniforms.numPointLights; x++)
    {
        PointLight light = lights[x];
        float3 dirToLight = light.position - in.worldSpacePosition;
        float distToLight = length(dirToLight);
        float3 wi = normalize(dirToLight);
        
        float falloff = (1.0 / (distToLight * distToLight));
        
        float3 Li = light.radiance * falloff; //might want to divide by 4pi
        
        float3 wo = normalize(uniforms.worldSpaceCameraPosition - in.worldSpacePosition);
        
        
        //diffuse BRDF
        
        float3 fr = baseColor / M_PI_F;
        
        Lo += fr * Li * max(0.0f, dot(wi, n));
    }
    
    
    

    return float4(Lo, 1.0);

    //return float4((n + 1.0) / 2.0, 1.0);
}





