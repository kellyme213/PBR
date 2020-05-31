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


//TODO: modify fillBuffer and createBuffer so that buffers can be created with options
//other than storageModeShared.

//fillBuffer fills a buffer with data
//if the buffer has not been created yet, the buffer is created before filling.
//if size is not specified, then the buffer will only be able to contain the data contained
//in the data array. If size is specified, the buffer will be allocated to that size, which
//can be larger than the size of the data array.
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

//create a render pass descriptor with a depth attachment
func createRenderPassDescriptor(device: MTLDevice, texture: MTLTexture) -> MTLRenderPassDescriptor
{
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
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

//this function reads in an obj file from the asset bundle and
//generates vertices and normal vectors for rendering
//currently, the function only supports triangle faces. Vertices are read in from model space
//and converted to world space in this function. Only scaling and translation transformations
//are currently supported.
func readObj(file: String, material: MaterialDescriptor, scaleFactor: Float = 1.0, worldPosition: simd_float3 = simd_float3(repeating: 0.0)) -> Object
{
    let bundle = Bundle.main
    let path = bundle.path(forResource: file, ofType: nil)!
    let fileContents = try! String.init(contentsOfFile: path, encoding: .utf8)
    
    var partialVertices: [Vertex] = []
    var vertices: [Vertex] = []
    var uvs: [simd_float2] = []
    
    let lines = fileContents.split(separator: "\n")
    
    for line in lines
    {
        let splitLine = line.split(separator: " ")
        if (splitLine.count > 0)
        {
            if (splitLine[0] == "v")
            {
                var v = Vertex()
                v.position = simd_float4(Float(splitLine[1])!,
                                          Float(splitLine[2])!,
                                          Float(splitLine[3])!,
                                          1.0)
                v.materialIndex = Int32(material.materialIndex)
                partialVertices.append(v)
            }
            else if (splitLine[0] == "vt")
            {
                uvs.append(simd_float2(Float(splitLine[1])!,
                                        Float(splitLine[2])!))
            }
            else if (splitLine[0] == "f")
            {
                //TODO: support faces with more than 3 vertices
                
                //extract the vertex and uv indexes
                let facePoint0 = splitLine[1].split(separator: "/")
                let facePoint1 = splitLine[2].split(separator: "/")
                let facePoint2 = splitLine[3].split(separator: "/")

                let vIndex0 = Int(facePoint0[0])! - 1
                let vIndex1 = Int(facePoint1[0])! - 1
                let vIndex2 = Int(facePoint2[0])! - 1
                
                let uvIndex0 = Int(facePoint0[1])! - 1
                let uvIndex1 = Int(facePoint1[1])! - 1
                let uvIndex2 = Int(facePoint2[1])! - 1
                
                //generate 3 new vertices and set their uv coordinates
                var v0 = Vertex()
                v0.position = partialVertices[vIndex0].position
                v0.materialIndex = partialVertices[vIndex0].materialIndex
                
                var v1 = Vertex()
                v1.position = partialVertices[vIndex1].position
                v1.materialIndex = partialVertices[vIndex1].materialIndex
                
                var v2 = Vertex()
                v2.position = partialVertices[vIndex2].position
                v2.materialIndex = partialVertices[vIndex2].materialIndex
                
                v0.uv = uvs[uvIndex0]
                v1.uv = uvs[uvIndex1]
                v2.uv = uvs[uvIndex2]
                
                
                //calculate normal and tangent vectors for normal mapping
                //http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/
                
                let dv1 = v1.position.xyz - v0.position.xyz
                let dv2 = v2.position.xyz - v0.position.xyz

                let duv1 = v1.uv - v0.uv
                let duv2 = v2.uv - v0.uv

                let r = 1.0 / (duv1.x * duv2.y - duv1.y * duv2.x)
                let tangent = normalize(r * (dv1 * duv2.y - dv2 * duv1.y))
                let bitangent = normalize(r * (dv2 * duv1.x - dv1 * duv2.x))
                let normal = normalize(cross(tangent, bitangent))
                
                v0.normal = normal
                v1.normal = normal
                v2.normal = normal

                v0.tangent = tangent
                v1.tangent = tangent
                v2.tangent = tangent
                
                //add the new vertices for this face to the vertex list
                vertices.append(v0)
                vertices.append(v1)
                vertices.append(v2)                
            }
        }
    }
    
    //TODO: support rotation transformations
    //transform vertices from model space to world space
    for x in 0 ..< vertices.count
    {
        vertices[x].position *= scaleFactor
        vertices[x].position += simd_float4(worldPosition, 0.0)
        vertices[x].position.w = 1.0
    }
    
    var obj = Object()
    obj.vertices = vertices
    obj.materialDescriptor = material
    
    return obj
}

//This function takes a list of texture names, loads the textures, and stores
//them in a single texture, which is a metal texture2d_array.
//As an example, all of the baseColor textures for all materials in a scene
//will be stored in a single texture array. Then, in the fragment/compute shader,
//the desired texture slice will be sampled.

//while this implementation will become problematic on scenes with a large number of materials,
//I am assuming that my test scenes will contain a small number of materials and that
//all textures will be generated at startup since this is meant to be a ray tracer and not
//a real time engine.
func packTextures(device: MTLDevice, textureNameList: [String]) -> MTLTexture
{
    let commandQueue = device.makeCommandQueue()!
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    
    let t = MTLTextureDescriptor()
    t.textureType = .type2DArray
    t.arrayLength = textureNameList.count
    t.width = 1024
    t.height = 1024
    t.usage = .shaderRead
    t.pixelFormat = .rgba8Unorm_srgb
    let packedTexture = device.makeTexture(descriptor: t)!

    
    let loader = MTKTextureLoader.init(device: device)
    
    var x = 0
    for textureName in textureNameList
    {
        if textureName == ""
        {
            x += 1
            continue
        }
        
        //create temporary texture and copy it over to the corresponing slice.
        let tempTex = try! loader.newTexture(name: textureName, scaleFactor: 1.0, bundle: Bundle.main, options: nil)
        
        blitEncoder.copy(from: tempTex,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         to: packedTexture,
                         destinationSlice: x,
                         destinationLevel: 0,
                         sliceCount: 1,
                         levelCount: 1)
        x += 1
    }
    
    blitEncoder.endEncoding()
    commandBuffer.commit()
    
    return packedTexture
}

