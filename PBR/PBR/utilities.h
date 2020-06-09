//
//  utilities.h
//  PBR
//
//  Created by Michael Kelly on 6/4/20.
//  Copyright © 2020 Michael Kelly. All rights reserved.
//

#ifndef utilities_h
#define utilities_h



//From Apple's MPSPathTracingSample project
inline float3 sampleCosineWeightedHemisphere(float2 u) {
    float phi = 2.0f * M_PI_F * u.x;
    
    float cos_phi;
    float sin_phi = sincos(phi, cos_phi);
    
    float cos_theta = sqrt(u.y);
    float sin_theta = sqrt(1.0f - cos_theta * cos_theta);
    
    return float3(sin_theta * cos_phi, cos_theta, sin_theta * sin_phi);
}

//From Apple's MPSPathTracingSample project
inline float3 alignHemisphereWithNormal(float3 sample, float3 normal) {
    float3 up = normal;
    float3 right = normalize(cross(normal, float3(0.0072f, 1.0f, 0.0034f)));
    float3 forward = cross(right, up);
    return sample.x * right + sample.y * up + sample.z * forward;
}



//https://developer.apple.com/videos/play/wwdc2019/613/
//In Apple's WWDC 2019 talk 'Ray Tracing with Metal' at time 19:10, Apple
//recommends storing rays in block linear order to improve cache coherency
//for the ray intersector. The recommended block size is 8 by 8 rays.
//This function converts the thread position to the corresponding block linear
//order index. The talk gives a visualization of the differences between row linear
//and block linear ordering.
//blockWidth is the width of a square block, with 8 as the recommended size.
//screenWidth is the width of the screen/buffer that the rays are stored in.
inline unsigned int blockLinearIndex(uint2 tid, int blockWidth, int screenWidth)
{
    int x = tid.x;
    int y = tid.y;
    int n = blockWidth;
    int w = screenWidth;
    return ((x % n) * n) +
            (y % n) +
            (n * n * (x / n)) +
            (w * n * (y / n));
}




#endif /* utilities_h */
