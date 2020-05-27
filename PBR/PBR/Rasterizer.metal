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
    float2 uv;
    int id;
};

vertex VertexOut vertexShader
(
    const device Vertex*        vertices [[buffer(0)]],
    const device SceneUniforms& uniforms [[buffer(1)]],
    const texture2d_array<float, access::read> tex [[texture(0)]],
                 uint           vid      [[vertex_id]]
)
{
    const Vertex vert = vertices[vid];
    VertexOut v;
    v.position = uniforms.projectionMatrix * uniforms.viewMatrix * vert.position;
    v.uv = vert.uv;
    v.id = vert.materialIndex;
        
    return v;
}

fragment float4 fragmentShader
(
    VertexOut in [[stage_in]],
    array<texture2d<float, access::sample>, 2> tex [[texture(0)]]
)
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    
    return tex[in.id].sample(s, in.uv);
    
    //return float4(1.0, 0.0, 0.0, 1.0);
}





