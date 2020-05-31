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
    var scenePointLights: [PointLight] = []
    var sceneAreaLights: [AreaLight] = []
    var sceneVertexBuffer: MTLBuffer!
    var device: MTLDevice
    var sceneBaseColorTextures: MTLTexture!
    var sceneRoughnessTextures: MTLTexture!
    var sceneMetallicTextures: MTLTexture!
    var sceneNormalTextures: MTLTexture!
    var scenePointLightBuffer: MTLBuffer!
    var sceneAreaLightBuffer: MTLBuffer!

    
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
        let l = PointLight(position: position,
                           irradiance: irradiance,
                           lightRadius: lightRadius)
        scenePointLights.append(l)
    }
    
    func addAreaLight(position: simd_float3, direction: simd_float3, irradiance: simd_float3, lightRadius: Float, extent: simd_float2)
    {
        let l = AreaLight(position: position,
                          direction: direction,
                          irradiance: irradiance,
                          lightRadius: lightRadius,
                          extent: extent)
        sceneAreaLights.append(l)
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
        
        if (scenePointLights.count != 0)
        {
            fillBuffer(device: device, buffer: &scenePointLightBuffer, data: scenePointLights)
        }
        else //no lights
        {
            //make an empty buffer with spot for 1 light so that the buffer is not null
            //when attempting to bind it
            fillBuffer(device: device, buffer: &scenePointLightBuffer, data: [], size: MemoryLayout<PointLight>.stride)
        }
        
        if (sceneAreaLights.count != 0)
        {
            fillBuffer(device: device, buffer: &sceneAreaLightBuffer, data: sceneAreaLights)
        }
        else //no lights
        {
            //make an empty buffer with spot for 1 light so that the buffer is not null
            //when attempting to bind it
            fillBuffer(device: device, buffer: &sceneAreaLightBuffer, data: [], size: MemoryLayout<AreaLight>.stride)
        }
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
