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
    var commandBuffer: MTLCommandBuffer!

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
        
        
        let width = Int(renderView.currentDrawable!.texture.width)
        let height = Int(renderView.currentDrawable!.texture.height)
        let fovRadians = (Float(movementController.fieldOfView) * Float.pi) / 180.0
        let aspectRatio = Float(width) / Float(height)
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
        shadeUniforms.width = Int32(width)
        shadeUniforms.height = Int32(height)
        shadeUniforms.imagePlaneWidth = imagePlaneWidth
        shadeUniforms.imagePlaneHeight = imagePlaneHeight
        fillBuffer(device: device, buffer: &shadeRaysUniformBuffer, data: [shadeUniforms])

    }
    
    func updateRayBufferSize(width: Int, height: Int)
    {
        print(width, height)
        let rayStride = MemoryLayout<Ray>.stride
        cameraRayBuffer = nil
        fillBuffer(device: device,
                   buffer: &cameraRayBuffer,
                   data: [],
                   size: rayStride * width * height)
        
        let intersectionStride = MemoryLayout<Intersection>.stride
        cameraIntersectionBuffer = nil
        fillBuffer(device: device,
                   buffer: &cameraIntersectionBuffer,
                   data: [],
                   size: intersectionStride * width * height)
    }
    
    func renderLoop()
    {
        commandBuffer = commandQueue.makeCommandBuffer()!
        if (renderMode == RENDER_MODE_RASTERIZE)
        {
            rasterizeRenderLoop()
        }
        else if (renderMode == RENDER_MODE_RAY_TRACE)
        {
            rayTraceRenderLoop()
        }
    }

    
    func rayTraceRenderLoop()
    {
        var commandEncoder = commandBuffer.makeComputeCommandEncoder()!

        let width = Int(renderView.currentDrawable!.texture.width)
        let height = Int(renderView.currentDrawable!.texture.height)


        
        let size = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroups = MTLSize(width: (width + 7) / 8, height: (height + 7) / 8, depth: 1)
        
        
        commandEncoder.setComputePipelineState(generateCameraRaysPipelineState)

        commandEncoder.setBuffer(cameraRayBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(shadeRaysUniformBuffer, offset: 0, index: 1)


        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: size)
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
        commandEncoder.setTexture(scene.sceneBaseColorTextures, index: 0)
        commandEncoder.setTexture(renderView.currentDrawable!.texture, index: 4)
        
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: size)
        commandEncoder.endEncoding()
                
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
