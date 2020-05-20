//
//  UtilityFunctions.swift
//  GPUCloth
//
//  Created by Michael Kelly on 9/9/19.
//  Copyright © 2019 Michael Kelly. All rights reserved.
//

import Foundation
import simd
import Metal
import MetalKit
import MetalPerformanceShaders

let rayStride = 48;
let intersectionStride = MemoryLayout<MPSIntersectionDistancePrimitiveIndexCoordinates>.stride
let patchSize: Float = 0.02

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
    
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func look_at_matrix(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float> = SIMD3<Float>(0, 1, 0)) -> matrix_float4x4
{
    let t = matrix4x4_translation(-eye.x, -eye.y, -eye.z)
    
    let f = normalize(eye - target)
    let l = normalize(cross(up, f))
    let u = normalize(cross(f, l))
    let rot = matrix_float4x4.init(columns: (SIMD4<Float>(l, 0.0),
                                             SIMD4<Float>(u, 0.0),
                                             SIMD4<Float>(f, 0.0),
                                             SIMD4<Float>(0.0, 0.0, 0.0, 1.0))).transpose
    return (rot * t)
}



extension SIMD4
{
    var xyz: SIMD3<Float>
    {
        return SIMD3<Float>(self.x as! Float, self.y as! Float, self.z as! Float)
    }
}




func fillBuffer<T>(device: MTLDevice, buffer: inout MTLBuffer?, data: [T], size: Int = 0)
{
    if (buffer == nil)
    {
        buffer = createBuffer(device: device, data: data, size: size)
    }
    else
    {
        var bufferSize: Int = size
        
        if (size == 0)
        {
            bufferSize = MemoryLayout<T>.stride * data.count
        }
        
        memcpy(buffer!.contents(), data, bufferSize)
    }
}

func createBuffer<T>(device: MTLDevice, data: [T], size: Int = 0) -> MTLBuffer!
{
    var bufferSize: Int = size
    
    if (size == 0)
    {
        bufferSize = MemoryLayout<T>.stride * data.count
    }
    
    if (data.count == 0)
    {
        return device.makeBuffer(length: bufferSize, options: .storageModeShared)
    }
    
    return device.makeBuffer(bytes: data, length: bufferSize, options: .storageModeShared)!
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




func createRandomTexture(device: MTLDevice, width: Int, height: Int, usage: MTLTextureUsage = .shaderRead) -> MTLTexture
{
    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.width = width
    textureDescriptor.height = height
    textureDescriptor.pixelFormat = .bgra8Unorm
    textureDescriptor.usage = usage
    textureDescriptor.storageMode = .managed
    
    var randomValues: [SIMD4<Float>] = []
    
    for _ in 0 ..< width * height
    {
        randomValues.append(SIMD4<Float>(Float(drand48()), Float(drand48()), Float(drand48()), Float(drand48())))
    }
    
    let texture = device.makeTexture(descriptor: textureDescriptor)!
    
    texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: &randomValues, bytesPerRow: MemoryLayout<SIMD4<Float>>.stride * width)
    
    return texture
    
    
}

func angleBetween(a: SIMD3<Float>, b: SIMD3<Float>) -> Float
{
    let crossP = cross(a, b)
    let dotP = dot(normalize(a), normalize(b))
    var angleBetween = 180 * (acos(dotP) / 3.14)
    if (dot(crossP, SIMD3<Float>(0.01, 0.01, 0.99)) < 0.0)
    {
        angleBetween = 360 - angleBetween
    }
    
    return angleBetween
}

func createRenderPassDescriptor(device: MTLDevice, texture: MTLTexture) -> MTLRenderPassDescriptor
{
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.usage = .renderTarget
    textureDescriptor.height = texture.height
    textureDescriptor.width = texture.width
    textureDescriptor.pixelFormat = .depth32Float
    textureDescriptor.storageMode = .private
    renderPassDescriptor.depthAttachment.texture = device.makeTexture(descriptor: textureDescriptor)
    
    return renderPassDescriptor
}

func createRenderPipelineDescriptor(device: MTLDevice, vertexShader: String, fragmentShader: String) -> MTLRenderPipelineDescriptor
{
    let defaultLibrary = device.makeDefaultLibrary()!
    let vShader = defaultLibrary.makeFunction(name: vertexShader)!
    let fShader = defaultLibrary.makeFunction(name: fragmentShader)!
    
    let rpd = MTLRenderPipelineDescriptor()
    rpd.colorAttachments[0].pixelFormat = .bgra8Unorm
    rpd.vertexFunction = vShader
    rpd.fragmentFunction = fShader
    rpd.depthAttachmentPixelFormat = .depth32Float
    
    return rpd
}
