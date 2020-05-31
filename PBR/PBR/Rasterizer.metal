//
//  Rasterizer.metal
//  PBR
//
//  Created by Michael Kelly on 5/19/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

#include <metal_stdlib>
#import "ShaderStructs.h"
#include "brdf.h"
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
    float metalness = metallicTexture.sample(s, in.uv, in.id).r;
    float roughness = roughnessTexture.sample(s, in.uv, in.id).r;
    
    //sqrt is needed when computing textureNormal because i havent been
    //able to import my normal map as a linear rgb only as srgb and i guess
    //the sqrt is a way to convert between the two???
    //it looks close enough and I am tired of dealing with texture formats so it will
    //remain a known bug that i do not intend to fix anytime soon.
    //I think it has something to do with gamma correction
    //https://www.gamasutra.com/blogs/RobertBasler/20131122/205462/Three_Normal_Mapping_Techniques_Explained_For_the_Mathematically_Uninclined.php?print=1
    //mentions something similar to this issue in the Gamma and Normal Maps section
    
    //generate the TBN matrix so that the textureNormal can be transformed
    //from tangent space to world space.
    //http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/
    float3 textureNormal = sqrt(normalize(normalTexture.sample(s, in.uv, in.id).xyz)); //see above
    float3 bitangent = cross(in.normal, in.tangent);
    float3x3 tbn = float3x3(in.tangent, bitangent, in.normal);
    float3 n = normalize(tbn * (2.0 * textureNormal - 1.0));
    
    //total radiance leaving the surface
    float3 Lo = float3(0.0, 0.0, 0.0);
        
    for (int x = 0; x < uniforms.numPointLights; x++)
    {
        PointLight light = lights[x];
        float3 dirToLight = light.position - in.worldSpacePosition;
        float distToLight = length(dirToLight);
        
        //direction towards the light
        float3 wi = normalize(dirToLight);
        
        float falloff = calculateFalloff(light.lightRadius, distToLight);
        
        //incoming radiance along wi
        float3 Li = light.irradiance * falloff; //might want to divide by 4pi
        
        //direction towards the camera/out of the surface
        float3 wo = normalize(uniforms.worldSpaceCameraPosition - in.worldSpacePosition);
        
        //half vector
        float3 h = normalize(wi + wo);
        
        //various cosine/dot product terms used in BRDFs and the rendering equation
        float cosI = max(dot(n, wi), 0.0);
        float cosO = max(dot(n, wo), 0.0);
        float cosH = max(dot(n, h), 0.0);
        float cosD = abs(cosH - cosO);

        float3 fr = disneyBRDF(cosI, cosO, cosH, cosD, baseColor, roughness, metalness);
        
        //contribution of this light to the rendering equation.
        //The integral of the rendering equation is approximated by the for loop iterating
        //over all of the lights.
        Lo += fr * Li * cosI;
    }
    
    return float4(Lo, 1.0);
}





