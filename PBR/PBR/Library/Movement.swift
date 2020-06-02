//
//  Movement.swift
//  GPUCloth
//
//  Created by Michael Kelly on 12/21/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

import Foundation
import simd

//this class handles moving the camera around the scene using the mouse and keyboard and
//generates the view and projection matrices

//  W/S - forwards and backwards
//  A/D - left and right
//  Q/E - up and down
//  mouse click and drag - moves the camera direction based on the arcball rotation model
//  spacebar - resets camera back to default position and direction

class Movement
{
    let defaultCameraPosition: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 5.0)
    let defaultCameraDirection: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, -1.0)
    
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var cameraPosition: SIMD3<Float>
    var cameraDirection: SIMD3<Float>
    var screenSize: CGSize
    
    var fieldOfView: Float = 65.0
    
    init(initialScreenSize: CGSize)
    {
        cameraPosition = defaultCameraPosition
        cameraDirection = defaultCameraDirection
        projectionMatrix = simd_float4x4()
        viewMatrix = simd_float4x4()
        screenSize = initialScreenSize
        generateMatrices()
    }
    
    func generateMatrices()
    {
        updateProjectionMatrix()
        updateViewMatrix()
    }
    
    func updateProjectionMatrix()
    {
        let aspect = Float(screenSize.width) / Float(screenSize.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(fieldOfView), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
    
    func updateViewMatrix()
    {
        viewMatrix = look_at_matrix(eye: cameraPosition, target: cameraPosition + cameraDirection)
    }
    
    func updateScreenSize(newSize: CGSize)
    {
        screenSize = newSize
        updateProjectionMatrix()
    }
    
    var initialCameraDirection = SIMD3<Float>(0, 0, 0)
    var previousCameraDirection = SIMD3<Float>(0, 0, 0)

    func mouseDown(locationInWindow: CGPoint, frame: NSRect)
    {
        var x = -(locationInWindow.x - (frame.width / 2.0))
        var y = -(locationInWindow.y - (frame.height / 2.0))

        x = x / frame.width
        y = y / frame.height

        initialCameraDirection = createArcballCameraDirection(x: Float(x), y: Float(y))
        previousCameraDirection = cameraDirection
    }
    
    func mouseDragged(locationInWindow: CGPoint, frame: NSRect)
    {
        var x = -(locationInWindow.x - (frame.width / 2.0))
        var y = -(locationInWindow.y - (frame.height / 2.0))

        x = x / frame.width
        y = y / frame.height
        
        let newCameraDirection = createArcballCameraDirection(x: Float(x), y: Float(y))
        
        let rotationMatrix = matrix4x4_rotation(radians: -acos(dot(initialCameraDirection, newCameraDirection)), axis: cross(initialCameraDirection, newCameraDirection))
        
        let cam4 = (rotationMatrix * SIMD4<Float>(previousCameraDirection, 0.0))
        
        cameraDirection = normalize(SIMD3<Float>(cam4.x, cam4.y, cam4.z))
        updateViewMatrix()
    }
    
    func keyDown(keyCode: Int)
    {
        let z = normalize(cameraDirection)
        let x = normalize(cross(SIMD3<Float>(0, 1, 0), z))
        let y = normalize(cross(z, x))
        let speed: Float = 0.05
        
        if (keyCode == KEY_W)
        {
            cameraPosition += speed * z;
        }
        else if (keyCode == KEY_S)
        {
            cameraPosition -= speed * z;
        }
        else if (keyCode == KEY_A)
        {
            cameraPosition += speed * x;
        }
        else if (keyCode == KEY_D)
        {
            cameraPosition -= speed * x;
        }
        else if (keyCode == KEY_Q)
        {
            cameraPosition += speed * y;
        }
        else if (keyCode == KEY_E)
        {
            cameraPosition -= speed * y;
        }
        else if (keyCode == KEY_SPACE)
        {
            cameraPosition = defaultCameraPosition
            cameraDirection = defaultCameraDirection
        }
        
        updateViewMatrix()
    }
}

//https://braintrekking.wordpress.com/2012/08/21/tutorial-of-arcball-without-quaternions/
func createArcballCameraDirection(x: Float, y: Float) -> SIMD3<Float>
{
    var newCameraDirection = SIMD3<Float>(0,0,0)
    let d = x * x + y * y
    let ballRadius: Float = 1.0
    
    if (d > ballRadius * ballRadius)
    {
        newCameraDirection = SIMD3<Float>(x, y, 0.0)
    }
    else
    {
        newCameraDirection = SIMD3<Float>(x, y, Float(sqrt(ballRadius * ballRadius - d)))
    }
    
    if (dot(newCameraDirection, newCameraDirection) > 0.001)
    {
        newCameraDirection = normalize(newCameraDirection)
    }
    else
    {
        print("BAD")
    }
    return newCameraDirection
}
