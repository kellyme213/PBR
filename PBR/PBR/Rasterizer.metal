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
};

vertex VertexOut vertexShader
(
    const device Vertex*        vertices [[buffer(0)]],
    const device SceneUniforms& uniforms [[buffer(1)]],
                 uint           vid      [[vertex_id]]
)
{
    VertexOut v;
    v.position = uniforms.projectionMatrix * uniforms.viewMatrix * vertices[vid].position;
    return v;
}

fragment float4 fragmentShader
(
    VertexOut in [[stage_in]]
)
{
    return float4(1.0, 0.0, 0.0, 1.0);
}





