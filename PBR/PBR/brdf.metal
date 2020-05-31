//
//  brdf.metal
//  PBR
//
//  Created by Michael Kelly on 5/30/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

//implementations of BRDF functions
#include <metal_stdlib>
using namespace metal;
#include "brdf.h"


//https://google.github.io/filament/Filament.html
//Listing 5
float3 fresnelSchlick(float cosTheta, float3 F0, float F90)
{
    return F0 + (float3(F90) - F0) * pow(1.0 - cosTheta, 5.0);
}

//https://google.github.io/filament/Filament.html
//Listing 6
float3 F_fresnelSchlick(float cosTheta, float3 F0)
{
    float f = pow(1.0 - cosTheta, 5.0);
    return f + F0 * (1.0 - f);
}

//https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
//Equation 3 page 3
float D_ndfGGX(float cosH, float roughness)
{
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;
    
    float d = (cosH * cosH) * (alpha2 - 1.0) + 1.0;
    return alpha2 / (M_PI_F * d * d);
}

//https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
//Equation 4 page 3
float G1(float cosTheta, float k)
{
    return (cosTheta) / ((cosTheta * (1.0 - k)) + k);
}

//https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
//Equation 4 page 3
float G_smithGGX(float cosI, float cosO, float roughness)
{
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return G1(cosI, k) * G1(cosO, k);
}

//https://disney-animation.s3.amazonaws.com/library/s2012_pbs_disney_brdf_notes_v2.pdf
//section 5.3, top of page 14
float3 disneyDiffuseBRDF(float cosI, float cosO, float cosH, float cosD, float3 baseColor, float roughness)
{
    float fd90 = 0.5 + 2.0 * cosD * cosD * roughness;
        
    return (baseColor / M_PI_F) *
            fresnelSchlick(cosI, 1.0, fd90) *
            fresnelSchlick(cosO, 1.0, fd90);
}

//https://github.com/Nadrin/PBR/blob/master/data/shaders/glsl/pbr_fs.glsl
//F0 derivation below also from the same source
constant float3 FDielectric = float3(0.04);

float3 disneySpecularBRDF(float cosI, float cosO, float cosH, float cosD, float3 baseColor, float roughness, float metalness)
{
    //https://github.com/Nadrin/PBR/blob/master/data/shaders/glsl/pbr_fs.glsl
    //F0 derivation from this code.
    float3 F0 = mix(FDielectric, baseColor, metalness);
    
    float3 F = F_fresnelSchlick(cosD, F0);
    float D = D_ndfGGX(cosH, roughness);
    float G = G_smithGGX(cosI, cosO, roughness);
    
    //Cook-Torrance Specular BRDF
    return (F * G * D) / max(0.001, 4.0 * cosI * cosO);
}

float3 disneyBRDF(float cosI, float cosO, float cosH, float cosD, float3 baseColor, float roughness, float metalness)
{
    
    return disneyDiffuseBRDF(cosI, cosO, cosH, cosD, baseColor, roughness) +
            disneySpecularBRDF(cosI, cosO, cosH, cosD, baseColor, roughness, metalness);
}

//https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
//Equation 9 page 12
float calculateFalloff(float lightRadius, float distanceToLight)
{
    float n = saturate(1.0 - pow(distanceToLight / lightRadius, 4.0));
    float d = pow(distanceToLight, 2.0) + 1.0;
    return (n * n) / d;
}



