//
//  Scene.swift
//  PBR
//
//  Created by Michael Kelly on 5/26/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

import Foundation
import MetalPerformanceShaders
import Metal

class Scene
{
    var sceneObjects: [Object] = []
    var sceneLights: [PointLight] = []
    var sceneVertexBuffer: MTLBuffer!
    var device: MTLDevice
    var sceneBaseColorTextures: MTLTexture!
    var sceneRoughnessTextures: MTLTexture!
    var sceneMetallicTextures: MTLTexture!
    var sceneNormalTextures: MTLTexture!
    var sceneLightBuffer: MTLBuffer!

    
    init(device: MTLDevice)
    {
        self.device = device
    }
    
    func addSceneObject(file: String,
                        material: MaterialDescriptor,
                        scaleFactor: Float = 1.0,
                        worldPosition: simd_float3 = simd_float3(repeating: 0.0))
    {
        sceneObjects.append(readObj(file: file, material: material, scaleFactor: scaleFactor, worldPosition: worldPosition))
    }
    
    func addPointLight(position: simd_float3, radiance: simd_float3)
    {
        let p = PointLight(position: position, radiance: radiance)
        sceneLights.append(p)
    }
    
    func generateSceneData()
    {
        generateSceneBuffers()
        generateSceneMaterialTextures()
        generateAccelerationStructure()
    }
    
    func generateSceneBuffers()
    {
        var sceneVertices: [Vertex] = []
        
        for object in sceneObjects
        {
            sceneVertices.append(contentsOf: object.vertices)
        }
        
        fillBuffer(device: device, buffer: &sceneVertexBuffer, data: sceneVertices)
        
        fillBuffer(device: device, buffer: &sceneLightBuffer, data: sceneLights)
    }
    
    func getTextureNameListForIndex(i: Int32) -> [String]
    {
        var list: [String] = []
        for object in sceneObjects
        {
            let s = object.materialDescriptor.getTextureString(i: i)
            if (s == nil)
            {
                list.append("")
            }
            else
            {
                list.append(s!)
            }
        }
        return list
    }
    
    func generateSceneMaterialTextures()
    {
        sceneBaseColorTextures = packTextures(device: device,
                                              textureNameList: getTextureNameListForIndex(i: MATERIAL_BASE_COLOR))
        
        sceneMetallicTextures = packTextures(device: device,
                                              textureNameList: getTextureNameListForIndex(i: MATERIAL_METALLIC))
        
        sceneRoughnessTextures = packTextures(device: device,
                                              textureNameList: getTextureNameListForIndex(i: MATERIAL_ROUGHNESS))
        
        sceneNormalTextures = packTextures(device: device,
                                              textureNameList: getTextureNameListForIndex(i: MATERIAL_NORMAL))
    }
    
    func generateAccelerationStructure()
    {
        let accelerationStructure = MPSTriangleAccelerationStructure(device: device)
        accelerationStructure.vertexBuffer = sceneVertexBuffer
    }
}
