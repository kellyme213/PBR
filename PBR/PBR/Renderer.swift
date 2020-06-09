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
    var rayTracingUniformBuffer: MTLBuffer!
    var renderMode = RENDER_MODE_RASTERIZE
    var generateCameraRaysPipelineState: MTLComputePipelineState!
    var shadeRaysPipelineState: MTLComputePipelineState!
    var accumulateIntersectionsPipelineState: MTLComputePipelineState!

    var randomTexture: MTLTexture!
    
    let partialRayDepth = 2
    var cameraRayIntersectionBuffer: MTLBuffer!
    var lightRayIntersectionBuffer: MTLBuffer!
    
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
        initializeBuffers()
    }
    
    func initializePipelineStates()
    {
        let d = createRenderPipelineDescriptor(device: device, vertexShader: "vertexShader", fragmentShader: "fragmentShader")
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: d)
        
        generateCameraRaysPipelineState = makeComputePipelineState(device: device,
                                                                   function: "generateCameraRays")
        
        shadeRaysPipelineState = makeComputePipelineState(device: device,
                                                          function: "shadeRays")
        
        accumulateIntersectionsPipelineState = makeComputePipelineState(device: device,
                                                                        function: "accumulateIntersections")
        
        
    }
    
    func initializeBuffers()
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
        
        randomTexture = createRandomTexture(device: device, width: 256, height: 256)
        
        let pathIntersectionStride = MemoryLayout<PathIntersectionData>.stride
        cameraRayIntersectionBuffer = nil
        fillBuffer(device: device,
                   buffer: &cameraRayIntersectionBuffer,
                   data: [],
                   size: pathIntersectionStride * partialRayDepth * 64 * 64)
        
        lightRayIntersectionBuffer = nil
        fillBuffer(device: device,
                   buffer: &lightRayIntersectionBuffer,
                   data: [],
                   size: pathIntersectionStride * partialRayDepth * 64 * 64)
        //print(pathIntersectionStride * partialRayDepth * 64 * 64 / 1024)
        
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
    }
    

    
    func renderLoop()
    {
        
        if (renderMode == RENDER_MODE_RASTERIZE)
        {
            rasterizeRenderLoop()
        }
        else if (renderMode == RENDER_MODE_RAY_TRACE)
        {
            rayTraceRenderLoop()
        }
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
