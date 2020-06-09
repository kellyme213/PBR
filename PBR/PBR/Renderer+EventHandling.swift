//
//  Renderer+EventHandling.swift
//  PBR
//
//  Created by Michael Kelly on 5/30/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

import Foundation
import MetalKit
import simd


//code related to key and mouse events
extension Renderer
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        movementController.updateScreenSize(newSize: size)
    }
    
    func keyDown(with theEvent: NSEvent) {
        movementController.keyDown(keyCode: Int(theEvent.keyCode))
        if (Int(theEvent.keyCode) == KEY_R)
        {
            if (renderMode == RENDER_MODE_RASTERIZE)
            {
                renderMode = RENDER_MODE_RAY_TRACE
            }
            else if (renderMode == RENDER_MODE_RAY_TRACE)
            {
                renderMode = RENDER_MODE_RASTERIZE
            }
        }
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
}
