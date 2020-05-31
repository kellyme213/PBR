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


#define MATERIAL_BASE_COLOR 0
#define MATERIAL_METALLIC 1
#define MATERIAL_ROUGHNESS 2
#define MATERIAL_NORMAL 3

struct Vertex
{
    simd_float4 position;
    simd_float3 normal;
    simd_float3 tangent;
    simd_float2 uv;
    int materialIndex;
};


struct PointLight
{
    simd_float3 position;
    simd_float3 irradiance;
    float lightRadius;
};

struct DirectionalLight
{
    simd_float3 direction;
    simd_float3 irradiance;
    float lightRadius;
};

struct SceneUniforms
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 viewMatrix;
};

struct RasterizeFragmentUniforms
{
    simd_float3 worldSpaceCameraPosition;
    int numPointLights;
};

#endif /* ShaderStructs_h */
