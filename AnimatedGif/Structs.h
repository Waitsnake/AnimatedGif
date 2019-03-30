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

// TODO the content of this stuct is still a dummy and will be needed if we need to pass additional data to the GPU shaders
typedef struct
{
    matrix_float4x4 modelview_projection_matrix; // 16*4=64 Byte
    matrix_float4x4 normal_matrix;               // 16*4=64 Byte
    vector_float4 ambient_color;                 // 16 Byte
    vector_float4 diffuse_color;                 // 16 Byte
    char padding_so_this_struct_is_256_bytes_wide[96]; // 64+64+16+16=160 + 96 = 256
    // NVIDIA's GPUs require the uniform buffer to be a multiple of 256 bytes, whereas Apple's and Intel's GPUs apparently don't care about the size -> Metal not supports union, that would make padding much easyer
} uniforms_t;

#endif /* Structs_h */
