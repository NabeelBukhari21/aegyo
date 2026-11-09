#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// A water ripple that travels out from `origin` and distorts whatever is under it.
[[ stitchable ]] half4 Ripple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
                              float amplitude, float frequency, float decay, float speed) {
    float distance = length(position - origin);
    float delay = distance / speed;
    time -= delay;
    time = max(0.0, time);
    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);
    float2 n = normalize(position - origin + 0.0001);
    float2 newPosition = position + rippleAmount * n;
    half4 color = layer.sample(newPosition);
    color.rgb += half3(0.25 * (rippleAmount / amplitude) * color.a);
    return color;
}

/// Soft film grain + vignette for a premium dark canvas.
[[ stitchable ]] half4 Grain(float2 position, half4 color, float time, float2 size) {
    float n = fract(sin(dot(position + time * 37.0, float2(12.9898, 78.233))) * 43758.5453);
    float2 uv = position / size - 0.5;
    float v = 1.0 - smoothstep(0.35, 0.85, length(uv * float2(0.9, 1.0)));
    half3 c = color.rgb * half(0.75 + 0.25 * v) + half3((n - 0.5) * 0.035);
    return half4(c, color.a);
}
