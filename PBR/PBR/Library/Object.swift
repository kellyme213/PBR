//
//  Object.swift
//  PBR
//
//  Created by Michael Kelly on 5/26/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

import Foundation

//contains vertex and material data for an object in a scene
//vertices are stored in world space, and are transformed from
//model space to world space when instantiated.
struct Object
{
    var vertices: [Vertex]!
    var materialDescriptor: MaterialDescriptor!
}


//Holds the names of various material textures
//These textures are stored in the Asset bundle
struct MaterialDescriptor
{
    var baseColor: String!
    var metallic: String!
    var roughness: String!
    var normal: String!
    var materialIndex: Int!
    
    //helper function to map indexes/numbers to a texture name
    //which makes the code to load and pack the textures much cleaner
    func getTextureString(i: Int32) -> String!
    {
        if (i == Int(MATERIAL_BASE_COLOR))
        {
            return baseColor
        }
        if (i == Int(MATERIAL_METALLIC))
        {
            return metallic
        }
        if (i == Int(MATERIAL_ROUGHNESS))
        {
            return roughness
        }
        if (i == Int(MATERIAL_NORMAL))
        {
            return normal
        }
        
        return ""
    }
}
