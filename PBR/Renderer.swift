//
//  Renderer.swift
//  GPUCloth
//
//  Created by Michael Kelly on 12/21/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

import Foundation
import MetalKit
import simd

let RENDER_MODE_RASTERIZE = 0
let RENDER_MODE_RAY_TRACE = 1

class Renderer: NSObject, MTKViewDelegate {
    
    var renderView: RenderView!
    var device: MTLDevice!
    var movementController: Movement!
    var commandQueue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var fragmentUniformBuffer: MTLBuffer!
    var renderPipelineState: MTLRenderPipelineState!
    var scene: Scene!
    
    var cameraRayBuffer: MTLBuffer!
    var cameraIntersectionBuffer: MTLBuffer!
    var shadeRaysUniformBuffer: MTLBuffer!
    var renderMode = RENDER_MODE_RASTERIZE
    var generateCameraRaysPipelineState: MTLComputePipelineState!
    var shadeRaysPipelineState: MTLComputePipelineState!
    //var commandBuffer: MTLCommandBuffer!

    init?(renderView: RenderView) {
        super.init()
        
        self.renderView = renderView
        initializeRenderer()
    }
    
    func initializeRenderer()
    {
        device = self.renderView.device!
        scene = Scene(device: device)
        
        loadScene1()
        
        scene.generateSceneData()
        commandQueue = device.makeCommandQueue()!
        movementController = Movement(initialScreenSize: renderView.frame.size)
        initializePipelineStates()
    }
    
    func initializePipelineStates()
    {
        let d = createRenderPipelineDescriptor(device: device, vertexShader: "vertexShader", fragmentShader: "fragmentShader")
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: d)
        
        generateCameraRaysPipelineState = makeComputePipelineState(device: device,
                                                                   function: "generateCameraRays")
        
        shadeRaysPipelineState = makeComputePipelineState(device: device,
                                                          function: "shadeRays")
    }
    
    func draw(in view: MTKView) {
        fillUniformBuffers()
        renderLoop()
    }
    
    func fillUniformBuffers()
    {
        var uniforms = SceneUniforms()
        uniforms.projectionMatrix = movementController.projectionMatrix
        uniforms.viewMatrix = movementController.viewMatrix
        fillBuffer(device: device, buffer: &uniformBuffer, data: [uniforms])
        
        var fragmentUniforms = RasterizeFragmentUniforms()
        fragmentUniforms.worldSpaceCameraPosition = movementController.cameraPosition
        fragmentUniforms.numPointLights = Int32(scene.scenePointLights.count)
        fragmentUniforms.numAreaLights = Int32(scene.sceneAreaLights.count)
        fragmentUniforms.numAreaLightSamples = 9;
        fillBuffer(device: device, buffer: &fragmentUniformBuffer, data: [fragmentUniforms])
        
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

        var shadeUniforms = ShadeRaysUniforms()
        shadeUniforms.cameraForward = forward
        shadeUniforms.cameraRight = right
        shadeUniforms.cameraUp = up
        shadeUniforms.cameraPosition = movementController.cameraPosition
        shadeUniforms.imagePlaneWidth = imagePlaneWidth
        shadeUniforms.imagePlaneHeight = imagePlaneHeight
        shadeUniforms.screenWidth = Int32(screenWidth)
        shadeUniforms.screenHeight = Int32(screenHeight)
        fillBuffer(device: device, buffer: &shadeRaysUniformBuffer, data: [shadeUniforms])


    }
    
    func updateRayBufferSize(width: Int, height: Int)
    {
        let rayStride = MemoryLayout<Ray>.stride
        cameraRayBuffer = nil
        fillBuffer(device: device,
                   buffer: &cameraRayBuffer,
                   data: [],
                   size: rayStride * 64 * 64)
        
        let intersectionStride = MemoryLayout<Intersection>.stride
        cameraIntersectionBuffer = nil
        fillBuffer(device: device,
                   buffer: &cameraIntersectionBuffer,
                   data: [],
                   size: intersectionStride * 64 * 64)
    }
    
    func renderLoop()
    {
        //commandBuffer = commandQueue.makeCommandBuffer()!
        if (renderMode == RENDER_MODE_RASTERIZE)
        {
            rasterizeRenderLoop()
        }
        else if (renderMode == RENDER_MODE_RAY_TRACE)
        {
            rayTraceRenderLoop()
        }
    }
    
    
    
    func renderSection(offset: simd_uint2)//, commandBuffer: MTLCommandBuffer)
    {
        //print(offset)
        let commandBuffer = commandQueue.makeCommandBuffer()!

        let screenWidth = Int(renderView.currentDrawable!.texture.width)
        let screenHeight = Int(renderView.currentDrawable!.texture.height)
        
        let width = min(64, abs(screenWidth - Int(offset.x)))
        let height = min(64, abs(screenHeight - Int(offset.y)))
        
        
        if (width == 0 || height == 0)
        {
            return
        }
        
        print(screenWidth, screenHeight, width, height, offset)

        
        //threads are processed in batches of 64 by 64 threads, with 8 by 8 threadgroups
        //with each threadgroup containing 8 by 8 threads
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(width: 8, height: 8, depth: 1)

        
        

        
        //let commandBuffer = commandQueue.makeCommandBuffer()!
        var commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        
        commandEncoder.setComputePipelineState(generateCameraRaysPipelineState)

        commandEncoder.setBuffer(cameraRayBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(shadeRaysUniformBuffer, offset: 0, index: 1)
        var o = offset
        var w = UInt32(width)
        commandEncoder.setBytes(&o, length: MemoryLayout<simd_uint2>.stride, index: 2)
        commandEncoder.setBytes(&w, length: MemoryLayout<uint>.stride, index: 3)

        commandEncoder.setTexture(renderView.currentDrawable!.texture, index: 0)


        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()

        scene.sceneIntersector.encodeIntersection(commandBuffer: commandBuffer,
                                                  intersectionType: .nearest,
                                                  rayBuffer: cameraRayBuffer,
                                                  rayBufferOffset: 0,
                                                  intersectionBuffer: cameraIntersectionBuffer,
                                                  intersectionBufferOffset: 0,
                                                  rayCount: width * height,
                                                  accelerationStructure: scene.sceneAccelerationStructure)

        commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(shadeRaysPipelineState)
        commandEncoder.setBuffer(cameraRayBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(cameraIntersectionBuffer, offset: 0, index: 1)
        commandEncoder.setBuffer(scene.sceneVertexBuffer, offset: 0, index: 2)
        commandEncoder.setBuffer(shadeRaysUniformBuffer, offset: 0, index: 3)
        commandEncoder.setBytes(&o, length: MemoryLayout<simd_uint2>.stride, index: 4)
        commandEncoder.setBytes(&w, length: MemoryLayout<uint>.stride, index: 5)
        commandEncoder.setTexture(scene.sceneBaseColorTextures, index: 0)
        commandEncoder.setTexture(renderView.currentDrawable!.texture, index: 4)
        
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
                
        commandBuffer.commit()

        
    }

    
    func rayTraceRenderLoop()
    {
        let screenWidth = Int(renderView.currentDrawable!.texture.width)
        let screenHeight = Int(renderView.currentDrawable!.texture.height)
        //let commandBuffer = commandQueue.makeCommandBuffer()!

        for y in 0 ..< (screenHeight / 64) + 1
        {
            for x in 0 ..< (screenWidth / 64) + 1
            {

                let offset = simd_uint2(UInt32(64 * x), UInt32(64 * y))
                //print(offset)
                renderSection(offset: offset)//, commandBuffer: commandBuffer)
            }
        }
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.present(renderView.currentDrawable!)
        commandBuffer.commit()
    }
    
    func rasterizeRenderLoop()
    {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = createRenderPassDescriptor(device: device, texture: renderView.currentDrawable!.texture)
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        commandEncoder.setRenderPipelineState(renderPipelineState)
        
        commandEncoder.setVertexBuffer(scene.sceneVertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        commandEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentBuffer(scene.scenePointLightBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentBuffer(scene.sceneAreaLightBuffer, offset: 0, index: 2)

        commandEncoder.setFragmentTexture(scene.sceneBaseColorTextures, index: Int(MATERIAL_BASE_COLOR))
        commandEncoder.setFragmentTexture(scene.sceneRoughnessTextures, index: Int(MATERIAL_ROUGHNESS))
        commandEncoder.setFragmentTexture(scene.sceneMetallicTextures, index: Int(MATERIAL_METALLIC))
        commandEncoder.setFragmentTexture(scene.sceneNormalTextures, index: Int(MATERIAL_NORMAL))

        commandEncoder.drawPrimitives(type: .triangle,
                                      vertexStart: 0,
                                      vertexCount: scene.sceneVertexBuffer.length / MemoryLayout<Vertex>.stride)

        commandEncoder.endEncoding()
        
        commandBuffer.present(renderView.currentDrawable!)
        commandBuffer.commit()        
    }
}
