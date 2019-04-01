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
    vector_float2 textCoord;
};

typedef struct
{
    matrix_float4x4 projection; // 16 Bytes * 4 = 64 Bytes
    vector_float4 scale;        // 16 Bytes
    char padding_so_this_struct_is_256_bytes_wide[176];
    // NVIDIA's GPUs require the uniform buffer to be a multiple of 256 bytes,
    // whereas Apple's and Intel's GPUs apparently don't care about the size
} uniforms_t;

// the function to calculate the projection matrix within the CPU code make it possible to convert within vertex shader of GPU
// vertexes with an screen coordinates(0,0,width,height) into vertexes with the Metal Normalized Coordinates (-1,0,1)
// as GPU needs it for furter computing
matrix_float4x4 matrix_ortho(float left, float right, float bottom, float top, float nearZ, float farZ)
{
    return (matrix_float4x4) { {
        { 2 / (right - left), 0, 0, 0 },
        { 0, 2 / (top - bottom), 0, 0 },
        { 0, 0, 1 / (farZ - nearZ), 0 },
        { (left + right) / (left - right), (top + bottom) / (bottom - top), nearZ / (nearZ - farZ), 1}
    } };
}

#endif /* Structs_h */
