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


//https://developer.apple.com/videos/play/wwdc2019/613/
//In Apple's WWDC 2019 talk 'Ray Tracing with Metal' at time 19:10, Apple
//recommends storing rays in block linear order to improve cache coherency
//for the ray intersector. The recommended block size is 8 by 8 rays.
//This function converts the thread position to the corresponding block linear
//order index. The talk gives a visualization of the differences between row linear
//and block linear ordering.
//blockWidth is the width of a square block, with 8 as the recommended size.
//screenWidth is the width of the screen/buffer that the rays are stored in.
inline unsigned int blockLinearIndex(uint2 tid, int blockWidth, int screenWidth)
{
    int x = tid.x;
    int y = tid.y;
    int n = blockWidth;
    int w = screenWidth;
    return ((x % n) * n) +
            (y % n) +
            (n * n * (x / n)) +
            (w * n * (y / n));
}


template<typename T>
inline T interpolateValue(T T0, T T1, T T2, float3 uvw) {
    return uvw.x * T0 + uvw.y * T1 + uvw.z * T2;
}

kernel void generateCameraRays
(
    device Ray* rays [[buffer(0)]],
 device ShadeRaysUniforms& uniforms [[buffer(1)]],
 constant uint2& offset [[buffer(2)]],
  constant uint& w [[buffer(3)]],
 texture2d<float, access::write> outTexture [[texture(0)]],
           uint2 threadId [[thread_position_in_grid]]
)
{
    uint2 tid = threadId + offset;
    
    if (tid.x < uniforms.screenWidth && tid.y < uniforms.screenHeight)
    {

        
        
        //unsigned int rayIdx = tid.y * uniforms.screenWidth + tid.x;
        unsigned int rayIdx = blockLinearIndex(threadId, 8, w);
        device Ray & ray = rays[rayIdx];
        float2 pixel = (float2)tid;
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


kernel void shadeRays
(
    device Ray* rays [[buffer(0)]],
    device Intersection* intersections [[buffer(1)]],
    device Vertex*       vertices      [[buffer(2)]],
    device ShadeRaysUniforms& uniforms [[buffer(3)]],
 constant uint2& offset [[buffer(4)]],
 constant uint& w [[buffer(5)]],
 const texture2d_array<float, access::sample> baseColorTexture [[texture(MATERIAL_BASE_COLOR)]],
 const texture2d_array<float, access::sample> metallicTexture  [[texture(MATERIAL_METALLIC)]],
 const texture2d_array<float, access::sample> roughnessTexture [[texture(MATERIAL_ROUGHNESS)]],
 const texture2d_array<float, access::sample> normalTexture    [[texture(MATERIAL_NORMAL)]],
 texture2d<float, access::write> outTexture [[texture(4)]],
    uint2 threadId [[thread_position_in_grid]]
)
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    uint2 tid = threadId + offset;

    //outTexture.write(float4(1.0, 1.0, 1.0, 1.0), tid);
    
    if (tid.x < uniforms.screenWidth && tid.y < uniforms.screenHeight)
    {
        //unsigned int rayIdx = tid.y * uniforms.screenWidth + tid.x;
        unsigned int rayIdx = blockLinearIndex(threadId, 8, w);

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




