//
//  Renderer+RayTracing.swift
//  PBR
//
//  Created by Michael Kelly on 6/4/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

import Foundation
import MetalKit
import simd

extension Renderer
{    
    func createRayTracingUniformStruct(offset: simd_uint2) -> RayTracingUniforms
    {
        let screenWidth = Int(renderView.currentDrawable!.texture.width)
        let screenHeight = Int(renderView.currentDrawable!.texture.height)
        
        let fovRadians = (Float(movementController.fieldOfView) * Float.pi) / 180.0
        let aspectRatio = Float(screenWidth) / Float(screenHeight)
        let imagePlaneHeight = tanf(fovRadians / 2.0)
        let imagePlaneWidth = aspectRatio * imagePlaneHeight

        //generate camera basis vectors
        let forward = normalize(movementController.cameraDirection)
        let right = normalize(cross(forward, simd_float3(0.001, 1.0, 0.003)))
        let up = normalize(cross(forward, right))

        let width = min(64, abs(screenWidth - Int(offset.x)))
        let height = min(64, abs(screenHeight - Int(offset.y)))
        
        var uniforms = RayTracingUniforms()
        uniforms.cameraForward = forward
        uniforms.cameraRight = right
        uniforms.cameraUp = up
        uniforms.cameraPosition = movementController.cameraPosition
        uniforms.imagePlaneWidth = imagePlaneWidth
        uniforms.imagePlaneHeight = imagePlaneHeight
        uniforms.screenWidth = Int32(screenWidth)
        uniforms.screenHeight = Int32(screenHeight)
        uniforms.offset = offset
        uniforms.blockWidth = Int32(width)
        uniforms.blockHeight = Int32(height)
        
        return uniforms
    }
    

    
    func traceCameraPaths(commandBuffer: MTLCommandBuffer, uniforms: RayTracingUniforms)
    {
        var rayUniforms = uniforms
        var bounceNums: [UInt32] = []
        
        for x in 0 ..< partialRayDepth
        {
            bounceNums.append(UInt32(x))
            scene.sceneIntersector.encodeIntersection(commandBuffer: commandBuffer,
                                                      intersectionType: .nearest,
                                                      rayBuffer: cameraRayBuffer,
                                                      rayBufferOffset: 0,
                                                      intersectionBuffer: cameraIntersectionBuffer,
                                                      intersectionBufferOffset: 0,
                                                      rayCount: 64 * 64,
                                                      accelerationStructure: scene.sceneAccelerationStructure)
            
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            commandEncoder.setComputePipelineState(accumulateIntersectionsPipelineState)
            commandEncoder.setBuffer(cameraRayBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(cameraIntersectionBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(scene.sceneVertexBuffer, offset: 0, index: 2)
            commandEncoder.setBytes(&rayUniforms, length: MemoryLayout<RayTracingUniforms>.stride, index: 3)
            commandEncoder.setBuffer(cameraIntersectionBuffer, offset: 0, index: 4)
            commandEncoder.setBytes(&bounceNums[x], length: MemoryLayout<UInt32>.stride, index: 5)
            
            commandEncoder.setTexture(scene.sceneNormalTextures, index: 0)
            commandEncoder.setTexture(randomTexture, index: 1)
            commandEncoder.endEncoding()
        }
    }
    
    func renderSection(offset: simd_uint2)
    {
        let commandBuffer = commandQueue.makeCommandBuffer()!
       
       
        var rayUniforms = createRayTracingUniformStruct(offset: offset)
       
       

         //threads are processed in batches of 64 by 64 threads, with 8 by 8 threadgroups
         //with each threadgroup containing 8 by 8 threads
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(width: 8, height: 8, depth: 1)
       
       

       
        var commandEncoder = commandBuffer.makeComputeCommandEncoder()!
       
       
       commandEncoder.setComputePipelineState(generateCameraRaysPipelineState)

       commandEncoder.setBuffer(cameraRayBuffer, offset: 0, index: 0)
       commandEncoder.setBytes(&rayUniforms, length: MemoryLayout<RayTracingUniforms>.stride, index: 1)

       commandEncoder.setTexture(renderView.currentDrawable!.texture, index: 0)
       commandEncoder.setTexture(randomTexture, index: 1)

       commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
       commandEncoder.endEncoding()
        
        traceCameraPaths(commandBuffer: commandBuffer, uniforms: rayUniforms)

       scene.sceneIntersector.encodeIntersection(commandBuffer: commandBuffer,
                                                 intersectionType: .nearest,
                                                 rayBuffer: cameraRayBuffer,
                                                 rayBufferOffset: 0,
                                                 intersectionBuffer: cameraIntersectionBuffer,
                                                 intersectionBufferOffset: 0,
                                                 rayCount: 64 * 64,
                                                 accelerationStructure: scene.sceneAccelerationStructure)

       commandEncoder = commandBuffer.makeComputeCommandEncoder()!
       commandEncoder.setComputePipelineState(shadeRaysPipelineState)
       commandEncoder.setBuffer(cameraRayBuffer, offset: 0, index: 0)
       commandEncoder.setBuffer(cameraIntersectionBuffer, offset: 0, index: 1)
       commandEncoder.setBuffer(scene.sceneVertexBuffer, offset: 0, index: 2)
       commandEncoder.setBytes(&rayUniforms, length: MemoryLayout<RayTracingUniforms>.stride, index: 3)
       
       commandEncoder.setTexture(scene.sceneBaseColorTextures, index: 0)
       commandEncoder.setTexture(renderView.currentDrawable!.texture, index: 4)
       
       commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
       commandEncoder.endEncoding()
        
        
        
        
       //commandEncoder = commandBuffer.makeComputeCommandEncoder()!

               
       commandBuffer.commit()

       
    }


    func rayTraceRenderLoop()
    {
       fillRandomTexture(texture: randomTexture)
       let screenWidth = Int(renderView.currentDrawable!.texture.width)
       let screenHeight = Int(renderView.currentDrawable!.texture.height)

       let numX = Int(ceil(Double(screenWidth) / 64.0))
       let numY = Int(ceil(Double(screenHeight) / 64.0))

       for y in 0 ..< numY
       {
           for x in 0 ..< numX
           {

               let offset = simd_uint2(UInt32(64 * x), UInt32(64 * y))
               renderSection(offset: offset)
           }
       }
       
       let commandBuffer = commandQueue.makeCommandBuffer()!
       commandBuffer.present(renderView.currentDrawable!)
       commandBuffer.commit()
    }
}
