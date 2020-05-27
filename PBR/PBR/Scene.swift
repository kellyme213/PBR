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
    var sceneVertexBuffer: MTLBuffer!
    var sceneIndexBuffer: MTLBuffer!
    var device: MTLDevice
    
    init(device: MTLDevice)
    {
        self.device = device
    }
    
    func addSceneObject(file: String, materialIndex: Int)
    {
        sceneObjects.append(readObj(file: file, materialIndex: materialIndex))
    }
    
    func generateSceneBuffers()
    {
        var sceneVertices: [Vertex] = []
        var sceneIndices: [UInt32] = []
        
        
        for object in sceneObjects
        {
            let numVertices = UInt32(sceneVertices.count)
            sceneVertices.append(contentsOf: object.vertices)
            
            for i in object.indices
            {
                sceneIndices.append(i + numVertices)
            }
        }
        
        fillBuffer(device: device, buffer: &sceneVertexBuffer, data: sceneVertices)
        fillBuffer(device: device, buffer: &sceneIndexBuffer, data: sceneIndices)
    }
    
    func generateAccelerationStructure()
    {
        generateSceneBuffers()
        let accelerationStructure = MPSTriangleAccelerationStructure(device: device)
        accelerationStructure.vertexBuffer = sceneVertexBuffer
        accelerationStructure.indexBuffer = sceneIndexBuffer
    }
}
