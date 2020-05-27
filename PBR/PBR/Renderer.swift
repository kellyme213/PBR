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
    var renderPipelineState: MTLRenderPipelineState!
    var scene: Scene!
    var textures: [MTLTexture]!

    init?(renderView: RenderView) {
        super.init()
        
        self.renderView = renderView
        initializeRenderer()
    }
    
    func initializeRenderer()
    {
        device = self.renderView.device!
        scene = Scene(device: device)
        scene.addSceneObject(file: "sphere.obj", materialIndex: 0)
        scene.addSceneObject(file: "cube.obj", materialIndex: 1)
        scene.generateAccelerationStructure()
        
        textures = generateTextures(device: device)
        
        commandQueue = device.makeCommandQueue()!
        movementController = Movement(initialScreenSize: renderView.frame.size)
        initializePipelineStates()
        
    }
    
    func initializePipelineStates()
    {
        let d = createRenderPipelineDescriptor(device: device, vertexShader: "vertexShader", fragmentShader: "fragmentShader")
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: d)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        movementController.updateScreenSize(newSize: size)
    }
    
    func draw(in view: MTKView) {
        
        var uniforms = SceneUniforms()
        uniforms.projectionMatrix = movementController.projectionMatrix
        uniforms.viewMatrix = movementController.viewMatrix
        
        fillBuffer(device: device, buffer: &uniformBuffer, data: [uniforms])
        
        renderLoop()
        
    }
    
    func keyDown(with theEvent: NSEvent) {
        movementController.keyDown(keyCode: Int(theEvent.keyCode))
        
    }
    
    func keyUp(with theEvent: NSEvent) {
    }
    
    func mouseUp(with event: NSEvent) {
    }
    
    func mouseDown(with event: NSEvent) {
        movementController.mouseDown(locationInWindow: event.locationInWindow,
                                     frame: event.window!.frame)
    }
    
    func mouseDragged(with event: NSEvent) {
        movementController.mouseDragged(locationInWindow: event.locationInWindow,
                                        frame: event.window!.frame)
    }
    
    func renderLoop()
    {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = createRenderPassDescriptor(device: device, texture: renderView.currentDrawable!.texture)
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        commandEncoder.setRenderPipelineState(renderPipelineState)
        
        commandEncoder.setVertexBuffer(scene.sceneVertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        commandEncoder.setFragmentTextures(textures, range: 0..<2)
        commandEncoder.drawIndexedPrimitives(type: .triangle,
                                             indexCount: scene.sceneIndexBuffer.length / MemoryLayout<UInt32>.stride,
                                             indexType: .uint32,
                                             indexBuffer: scene.sceneIndexBuffer,
                                             indexBufferOffset: 0)

        commandEncoder.endEncoding()
        
        commandBuffer.present(renderView.currentDrawable!)
        commandBuffer.commit()        
    }
}
