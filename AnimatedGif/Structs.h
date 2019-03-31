//
//  Structs.h
//  AnimatedGif
//
//  Created by Marco Köhler on 29.03.19.
//  Copyright © 2019 Marco Köhler. All rights reserved.
//

#ifndef Structs_h
#define Structs_h

#include <simd/simd.h>

// This header is needed so that the shader-code for the GPU and the objective-c-code for the cpu can use the same user defined data types

struct Vertex {
    vector_float3 position;
    vector_float4 color;
    vector_float2 textCoord;
};

#endif /* Structs_h */
