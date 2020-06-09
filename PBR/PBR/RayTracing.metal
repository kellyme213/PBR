//
//  RayTracing.metal
//  PBR
//
//  Created by Michael Kelly on 5/31/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "brdf.h"
#include "ShaderStructs.h"
#include "utilities.h"


template<typename T>
inline T interpolateValue(T T0, T T1, T T2, float3 uvw) {
    return uvw.x * T0 + uvw.y * T1 + uvw.z * T2;
}

kernel void generateCameraRays
(
    device   Ray*                    rays           [[buffer(0)]],
    constant RayTracingUniforms&     uniforms       [[buffer(1)]],
    texture2d<float, access::write>  outTexture     [[texture(0)]],
    texture2d<float, access::read>   randomTexture  [[texture(1)]],
             uint2                   threadId       [[thread_position_in_grid]]
)
{
    uint2 tid = threadId + uniforms.offset;
    
    if (tid.x < uniforms.screenWidth && tid.y < uniforms.screenHeight)
    {
        unsigned int rayIdx = blockLinearIndex(threadId,
                                               DEFAULT_BLOCK_LINEAR_WIDTH,
                                               uniforms.blockWidth);
        device Ray & ray = rays[rayIdx];
        uint randX = randomTexture.get_width();
        uint randY = randomTexture.get_height();
        float2 rand = (0.5 * randomTexture.read(tid % uint2(randX, randY)).xy - 0.5);
        
        float2 pixel = (float2)tid + rand;
        float2 uv = (float2)pixel / float2(uniforms.screenWidth, uniforms.screenHeight);
        uv = uv * 2.0f - 1.0f;
        ray.origin = uniforms.cameraPosition;
        ray.direction = normalize(uniforms.imagePlaneWidth * uv.x * uniforms.cameraRight +
                                  uniforms.imagePlaneHeight * uv.y * uniforms.cameraUp +
                                  uniforms.cameraForward);
        ray.mask = RAY_MASK_PRIMARY;
        ray.maxDistance = INFINITY;
        
        outTexture.write(float4(0.0, 0.0, 0.0, 1.0), tid);
    }
}


kernel void accumulateIntersections
(
    device Ray* rays [[buffer(0)]],
    device Intersection* intersections [[buffer(1)]],
    device Vertex*       vertices      [[buffer(2)]],
 constant RayTracingUniforms& uniforms [[buffer(3)]],
    device PathIntersectionData* pathIntersections [[buffer(4)]],
    constant int& bounceNum [[buffer(5)]],
 const texture2d_array<float, access::sample> normalTexture    [[texture(0)]],
 const texture2d<float, access::read>   randomTexture  [[texture(1)]],
 uint2 threadId [[thread_position_in_grid]]
)
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    uint2 tid = threadId + uniforms.offset;
    if (tid.x < uniforms.screenWidth && tid.y < uniforms.screenHeight)
    {
        unsigned int rayIdx = blockLinearIndex(threadId,
                                               DEFAULT_BLOCK_LINEAR_WIDTH,
                                               uniforms.blockWidth);

        device Ray& ray = rays[rayIdx];
        device Intersection& intersection = intersections[rayIdx];
        
        int pathIntersectionIndex = 64 * 64 * bounceNum + rayIdx;
        
        if (ray.maxDistance > 0 && intersection.distance > 0)
        {
            int pIndex = intersection.primitiveIndex;
            Vertex v0 = vertices[3 * pIndex + 0];
            Vertex v1 = vertices[3 * pIndex + 1];
            Vertex v2 = vertices[3 * pIndex + 2];
            
            float3 uvw;
            uvw.xy = intersection.coordinates;
            uvw.z = 1.0 - uvw.x - uvw.y;
            
            float2 uv = interpolateValue(v0.uv, v1.uv, v2.uv, uvw);
            
            int id = v0.materialIndex;
            
            float3 textureNormal = sqrt(normalize(normalTexture.sample(s, uv, id).xyz));
            float3 bitangent = cross(v0.normal, v0.tangent);
            float3x3 tbn = float3x3(v0.tangent, bitangent, v0.normal);
            float3 n = normalize(tbn * (2.0 * textureNormal - 1.0));
            
            uint randX = randomTexture.get_width();
            uint randY = randomTexture.get_height();
            float4 rand = (0.5 * randomTexture.read(tid % uint2(randX, randY)) - 0.5);
            
            float randS = rand[bounceNum % 4];
            float randT = rand[(bounceNum + 1) % 4];
            
            float3 randDir = sampleCosineWeightedHemisphere(float2(randS, randT));
            
            pathIntersections[pathIntersectionIndex].pdf = max(0.001, dot(randDir, n));
            pathIntersections[pathIntersectionIndex].intersection = intersection;
            
            float3 intersectionPoint = ray.origin + ray.direction * intersection.distance;
            
            ray.origin = intersectionPoint + 0.001 * n;
            ray.direction = randDir;
        }
        else
        {
            ray.maxDistance = 0;
            intersection.distance = 0;
            pathIntersections[pathIntersectionIndex].pdf = -1;
        }
    }
}

kernel void renderPaths
(
    device PathIntersectionData* intersections [[buffer(0)]],
    device Vertex* vertices [[buffer(1)]],
       constant RayTracingUniforms& uniforms [[buffer(2)]],
    const texture2d_array<float, access::sample> baseColorTexture [[texture(MATERIAL_BASE_COLOR)]],
    const texture2d_array<float, access::sample> metallicTexture  [[texture(MATERIAL_METALLIC)]],
    const texture2d_array<float, access::sample> roughnessTexture [[texture(MATERIAL_ROUGHNESS)]],
    const texture2d_array<float, access::sample> normalTexture    [[texture(MATERIAL_NORMAL)]],
    texture2d<float, access::write> outTexture [[texture(4)]],
       uint2 threadId [[thread_position_in_grid]]
)
{
    
}


kernel void shadeRays
(
    device Ray* rays [[buffer(0)]],
    device Intersection* intersections [[buffer(1)]],
    device Vertex*       vertices      [[buffer(2)]],
    constant RayTracingUniforms& uniforms [[buffer(3)]],
    device PointLight* pointLights [[buffer(4)]],
 const texture2d_array<float, access::sample> baseColorTexture [[texture(MATERIAL_BASE_COLOR)]],
 const texture2d_array<float, access::sample> metallicTexture  [[texture(MATERIAL_METALLIC)]],
 const texture2d_array<float, access::sample> roughnessTexture [[texture(MATERIAL_ROUGHNESS)]],
 const texture2d_array<float, access::sample> normalTexture    [[texture(MATERIAL_NORMAL)]],
 texture2d<float, access::write> outTexture [[texture(4)]],
    uint2 threadId [[thread_position_in_grid]]
)
{
    uint2 tid = threadId + uniforms.offset;
    
    if (tid.x < uniforms.screenWidth && tid.y < uniforms.screenHeight)
    {
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        unsigned int rayIdx = blockLinearIndex(threadId,
                                               DEFAULT_BLOCK_LINEAR_WIDTH,
                                               uniforms.blockWidth);

        Ray ray = rays[rayIdx];
        Intersection intersection = intersections[rayIdx];
        
        if (intersection.distance > 0.0)
        {
            int pIndex = intersection.primitiveIndex;
            Vertex v0 = vertices[3 * pIndex + 0];
            Vertex v1 = vertices[3 * pIndex + 1];
            Vertex v2 = vertices[3 * pIndex + 2];
            
            float3 uvw;
            uvw.xy = intersection.coordinates;
            uvw.z = 1.0 - uvw.x - uvw.y;
            
            float2 uv = interpolateValue(v0.uv, v1.uv, v2.uv, uvw);
            
            float4 color = baseColorTexture.sample(s, uv, v0.materialIndex);
            
            outTexture.write(color, tid);
        }
    }
}




