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
