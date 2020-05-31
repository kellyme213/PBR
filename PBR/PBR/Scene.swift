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

//contains all of the objects, lights, and materials in the scene and puts all of the data
//into buffers to be used in rendering
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
    
    func addPointLight(position: simd_float3, irradiance: simd_float3, lightRadius: Float)
    {
        let p = PointLight(position: position, irradiance: irradiance, lightRadius: lightRadius)
        sceneLights.append(p)
    }
    
    func generateSceneData()
    {
        generateSceneBuffers()
        generateSceneMaterialTextures()
        generateAccelerationStructure()
    }
    
    //combine all object vertices together in a single buffer so
    //that the vertices can be rendered/put into a ray tracing acceleration structure.
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
    
    //gathers the texture names from all of the materials for a
    //specific texture type (baseColor, metallic, normal)
    //so that the textures can be loaded and packed together.
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
    
    //used for ray tracing
    func generateAccelerationStructure()
    {
        let accelerationStructure = MPSTriangleAccelerationStructure(device: device)
        accelerationStructure.vertexBuffer = sceneVertexBuffer
    }
}
