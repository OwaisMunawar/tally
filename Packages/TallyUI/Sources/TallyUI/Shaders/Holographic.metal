#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Cosine palette (after Inigo Quilez): a smooth, endlessly cycling spectrum
// that reads as foil rather than as a rainbow gradient.
static half3 spectrum(float t) {
    return half3(0.5 + 0.5 * cos(6.28318 * (t + float3(0.0, 0.33, 0.67))));
}

// Holographic sheen for account cards, used as a SwiftUI colorEffect.
//
// `sweep` moves a soft diagonal band across the card. It is driven by the
// card's position in its scroll view, so the foil catches the light as the
// user scrolls; with Reduce Motion it is pinned. A fine diffraction grating
// is modulated into the band so it looks printed rather than painted.
//
// Colours arrive premultiplied, so the sheen is scaled by alpha to leave
// transparent corners untouched.
[[ stitchable ]] half4 holographicSheen(float2 position, half4 color, float2 size, float sweep, float intensity) {
    float2 uv = position / max(size, float2(1.0));
    float diagonal = uv.x * 0.85 + uv.y * 0.5;
    float band = exp(-pow((diagonal - sweep) * 2.2, 2.0));
    float grating = 0.5 + 0.5 * sin((uv.x - uv.y * 0.6) * 46.0 + sweep * 9.0);
    half3 foil = spectrum(diagonal * 1.6 - sweep * 0.8);
    half amount = half(intensity * band * (0.8 + 0.2 * grating));
    half3 lit = color.rgb + foil * amount * color.a;
    return half4(min(lit, half3(color.a)), color.a);
}
