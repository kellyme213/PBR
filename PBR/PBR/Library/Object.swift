//
//  Object.swift
//  PBR
//
//  Created by Michael Kelly on 5/26/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

import Foundation

struct Object
{
    var vertices: [Vertex]!
    var materialDescriptor: MaterialDescriptor!
}



struct MaterialDescriptor
{
    var baseColor: String!
    var metallic: String!
    var roughness: String!
    var normal: String!
    var materialIndex: Int!
    
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
