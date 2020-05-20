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
    var uniformBuffer: MTLBuffer!
    var renderPipelineState: MTLRenderPipelineState!

    init?(renderView: RenderView) {
        super.init()
        
        self.renderView = renderView
        initializeRenderer()
    }
    
    func initializeRenderer()
    {
        device = self.renderView.device!
        commandQueue = device.makeCommandQueue()!
        movementController = Movement(initialScreenSize: renderView.frame.size)
        
        var v1 = Vertex()
        v1.position = SIMD4<Float>(1.0, 0.0, 0.0, 1.0);
        var v2 = Vertex()
        v2.position = SIMD4<Float>(1.0, 1.0, 0.0, 1.0);
        var v3 = Vertex()
        v3.position = SIMD4<Float>(0.0, 1.0, 0.0, 1.0);
        
        let vertices = [v1, v2, v3]
        
        fillBuffer(device: device, buffer: &vertexBuffer, data: vertices)
        
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
        
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        commandEncoder.endEncoding()
        
        commandBuffer.present(renderView.currentDrawable!)
        commandBuffer.commit()
        
        //commandEncoder
    }
}
