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

//https://stackoverflow.com/questions/58665313/how-define-a-metal-shader-with-dynamic-buffer-declaration
//apparently packed_float3 doesn't exist in simd but packed_float3
//is needed for MPS rays
#ifndef __METAL_VERSION__
/// 96-bit 3 component float vector type
typedef struct __attribute__ ((packed)) packed_float3 {
    float x;
    float y;
    float z;
} packed_float3;
#endif

#define RAY_MASK_PRIMARY   3
#define RAY_MASK_SHADOW    1
#define RAY_MASK_SECONDARY 1

#define MATERIAL_BASE_COLOR 0
#define MATERIAL_METALLIC 1
#define MATERIAL_ROUGHNESS 2
#define MATERIAL_NORMAL 3

struct Vertex
{
    //vertex needs to stay as the first value of the struct since vertex structs are
    //used in the ray tracing intersectors and as a result position must be first
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

struct AreaLight
{
    simd_float3 position;
    simd_float3 direction;
    simd_float3 irradiance;
    float lightRadius;
    simd_float2 extent;
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
    int numAreaLights;
    int numAreaLightSamples;
};

struct Ray
{
    packed_float3 origin;
    uint mask;
    packed_float3 direction;
    float maxDistance;
    simd_float3 color;
};

struct Intersection {
    float distance;
    int primitiveIndex;
    simd_float2 coordinates;
};

struct ShadeRaysUniforms
{
    int width;
    int height;
    simd_float3 cameraPosition;
    simd_float3 cameraForward;
    simd_float3 cameraRight;
    simd_float3 cameraUp;
    float imagePlaneWidth;
    float imagePlaneHeight;
};


#endif /* ShaderStructs_h */
