//
//  brdf.h
//  PBR
//
//  Created by Michael Kelly on 5/30/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

//contains the various headers for functions needed to calculate BRDFs
#ifndef brdf_h
#define brdf_h

float3 fresnelSchlick(float cosTheta, float3 F0, float F90);
float3 F_fresnelSchlick(float cosTheta, float3 F0);
float D_ndfGGX(float cosH, float roughness);
float G1(float cosTheta, float k);
float G_smithGGX(float cosI, float cosO, float roughness);
float3 disneyDiffuseBRDF(float cosI, float cosO, float cosH, float cosD, float3 baseColor, float roughness);
float3 disneySpecularBRDF(float cosI, float cosO, float cosH, float cosD, float3 baseColor, float roughness, float metalness);
float3 disneyBRDF(float cosI, float cosO, float cosH, float cosD, float3 baseColor, float roughness, float metalness);
float calculateFalloff(float lightRadius, float distanceToLight);

#endif /* brdf_h */
