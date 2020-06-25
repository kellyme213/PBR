//
//  Renderer+SceneLoading.swift
//  PBR
//
//  Created by Michael Kelly on 5/31/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

import Foundation
import MetalKit
import simd

extension Renderer
{
    func loadScene1()
    {
        var boxMD = MaterialDescriptor()
        boxMD.baseColor = "boxBaseColor"
        boxMD.metallic = "boxMetallic"
        boxMD.roughness = "boxRoughness"
        boxMD.normal = "boxNormal"
        boxMD.materialIndex = 0
        
        scene.addSceneObject(file: "box.obj", material: boxMD)
        
        scene.addPointLight(position: simd_float3(0, 1.8, 0.0),
                            radiance: simd_float3(repeating: 10.0),
                            lightRadius: 5.0)

        scene.addPointLight(position: simd_float3(1.6, -1.6, 0.0),
                            radiance: simd_float3(5.0, 3.0, 0.0),
                            lightRadius: 3.0)
        
//        scene.addAreaLight(position: simd_float3(0.0, 1.8, 0.0),
//                           direction: simd_float3(-1.0, -1.0, 0.0),
//                           radiance: simd_float3(10.0, 10.0, 10.0),
//                           lightRadius: 10.0,
//                           extent: simd_float2(0.2, 0.2))
    }
}
