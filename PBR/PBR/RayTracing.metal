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

template<typename T>
inline T interpolateValue(T T0, T T1, T T2, float3 uvw) {
    return uvw.x * T0 + uvw.y * T1 + uvw.z * T2;
}

kernel void generateCameraRays
(
    device Ray* rays [[buffer(0)]],
 device ShadeRaysUniforms& uniforms [[buffer(1)]],
           uint2 tid [[thread_position_in_grid]]
)
{
    if (tid.x < uniforms.width && tid.y < uniforms.height)
    {
        unsigned int rayIdx = tid.y * uniforms.width + tid.x;
        device Ray & ray = rays[rayIdx];
        float2 pixel = (float2)tid;
        float2 uv = (float2)pixel / float2(uniforms.width, uniforms.height);
        uv = uv * 2.0f - 1.0f;
        ray.origin = uniforms.cameraPosition;
        ray.direction = normalize(uniforms.imagePlaneWidth * uv.x * uniforms.cameraRight +
                                  uniforms.imagePlaneHeight * uv.y * uniforms.cameraUp +
                                 uniforms.cameraForward);
        ray.mask = RAY_MASK_PRIMARY;
        ray.maxDistance = INFINITY;
    }
}


kernel void shadeRays
(
    device Ray* rays [[buffer(0)]],
    device Intersection* intersections [[buffer(1)]],
    device Vertex*       vertices      [[buffer(2)]],
    device ShadeRaysUniforms& uniforms [[buffer(3)]],
 const texture2d_array<float, access::sample> baseColorTexture [[texture(MATERIAL_BASE_COLOR)]],
 const texture2d_array<float, access::sample> metallicTexture  [[texture(MATERIAL_METALLIC)]],
 const texture2d_array<float, access::sample> roughnessTexture [[texture(MATERIAL_ROUGHNESS)]],
 const texture2d_array<float, access::sample> normalTexture    [[texture(MATERIAL_NORMAL)]],
 texture2d<float, access::write> outTexture [[texture(4)]],
    uint2 tid [[thread_position_in_grid]]
)
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    //outTexture.write(float4(1.0, 1.0, 1.0, 1.0), tid);
    
    if (tid.x < uniforms.width && tid.y < uniforms.height)
    {
        unsigned int rayIdx = tid.y * uniforms.width + tid.x;
        
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




