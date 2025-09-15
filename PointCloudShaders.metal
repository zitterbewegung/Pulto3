#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 pos [[attribute(0)]]; // unit quad vertex positions (-0.5..0.5)
};

struct InstanceData {
    float3 worldPos;
    float  size;
    float4 color;
};

struct Uniforms {
    float4x4 viewProj;
    float3 cameraRight;
    float3 cameraUp;
};

struct VSOut {
    float4 position [[position]];
    float4 color;
};

vertex VSOut pointVertex(
    VertexIn               in                 [[stage_in]],
    constant InstanceData* instances          [[buffer(1)]],
    constant Uniforms&     uniforms           [[buffer(2)]],
    uint                   instanceId         [[instance_id]])
{
    VSOut out;

    InstanceData inst = instances[instanceId];

    // Expand unit quad around instance world position using camera-facing billboard
    float2 v = in.pos * inst.size; // scale by point size
    float3 right = uniforms.cameraRight;
    float3 up    = uniforms.cameraUp;

    float3 world = inst.worldPos + right * v.x + up * v.y;
    out.position = uniforms.viewProj * float4(world, 1.0);
    out.color = inst.color;
    return out;
}

fragment float4 pointFragment(VSOut in [[stage_in]]) {
    return in.color;
}
