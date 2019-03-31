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

/*
Dataflow is like this:

1.) Renderprogram(CPU) -> Vertex(Data)
Renderprogram sends an Buffer of vertexs (e.g. from an 3D model to draw) to GPU
 
2.) Vertex(Data) -> myVertexShader(GPU) -> RasterizerData(Data)
VertexShader is an GPU program written by programmer.
Input are the vertexs (array of 3D points (with coordinates) and additional Data that defines the programmer like color).
 
3.) RasterizerData(Data) -> Rasterizer(GPU) -> RasterizerData(Data)
The Rasterizer is fixed in GPU and can not changed by programmer. It interpolates the inputdata.

4.) RasterizerData(Data) -> myFragmentShader(GPU) -> float4(Data that is displayed in the MetalView on screen)
FragmentShader is an GPU program written by programmer.
All Pixeldata that comes interpolated from Rasterizer can be changed before its output to screen.
 
*/

struct RasterizerData {
    float4 position [[position]];
    float4 color;
    float2 textCoord;
};

vertex RasterizerData myVertexShader(device Vertex* vertexArray    [[ buffer(0) ]],
                                     unsigned int vid              [[ vertex_id ]])
{
    RasterizerData out;
    out.position = float4(vertexArray[vid].position,1);
    out.color = vertexArray[vid].color;
    out.textCoord = vertexArray[vid].textCoord;
    return out;
}

fragment float4 myFragmentShader(RasterizerData interpolated [[stage_in]],
                                 sampler sampler2d           [[sampler(0)]],
                                 texture2d<float> texture   [[texture(0)]])
{
    float4 color = texture.sample(sampler2d, interpolated.textCoord);
    return color;
}

