//
//  Shaders.metal
//  AnimatedGif
//
//  Created by Marco Köhler on 29.03.19.
//  Copyright © 2019 Marco Köhler. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "Structs.h"

using namespace metal;

// this Metal file defines the code for the shader that run on the GPU

// TODO this are still dummy shaders from the Apple WWDC presentation

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut myVertexShader(device Vertex* vertexArray    [[ buffer(0) ]],
                                unsigned int vid              [[ vertex_id ]])
{
    VertexOut out;
    out.position = vertexArray[vid].position;
    out.color = vertexArray[vid].color;
    return out;
}


fragment float4 myFragmentShader(VertexOut interpolated [[stage_in]])
{
    return interpolated.color;
}


fragment half4 basic_fragment()
{
    return half4(1.0);
}

vertex float4 basic_vertex(const device packed_float3* vertex_array [[ buffer(0) ]],
                           unsigned int vid [[ vertex_id ]])
{
    return float4(vertex_array[vid], 1.0);
}
