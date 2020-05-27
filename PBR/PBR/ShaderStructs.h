//
//  ShaderStructs.h
//  PBR
//
//  Created by Michael Kelly on 5/19/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

#ifndef ShaderStructs_h
#define ShaderStructs_h
#include <simd/simd.h>


struct Vertex
{
    simd_float4 position;
    simd_float3 normal;
    simd_float2 uv;
    int materialIndex;
};


struct PointLight
{
    simd_float3 position;
    simd_float3 radiance;
};

struct DirectionalLight
{
    simd_float3 direction;
    simd_float3 radiance;
};

struct SceneUniforms
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 viewMatrix;
};

#endif /* ShaderStructs_h */
