import SwiftUI

public extension View {
    /// Adds the foil sheen from `Holographic.metal`. The band position follows the
    /// view's horizontal position in its scroll view, so it shifts as cards move.
    func holographicSheen(intensity: Double = 0.32, isEnabled: Bool = true) -> some View {
        modifier(HolographicSheenModifier(intensity: intensity, isEnabled: isEnabled))
    }
}

private struct HolographicSheenModifier: ViewModifier {
    let intensity: Double
    let isEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.visualEffect { [reduceMotion, intensity, isEnabled] effect, proxy in
            let frame = proxy.frame(in: .scrollView(axis: .horizontal))
            let bounds = proxy.bounds(of: .scrollView(axis: .horizontal)) ?? frame
            // -0.4...1.6 lets the band enter and leave fully off-card.
            let travel = bounds.width > 0 ? 1 - (frame.midX - bounds.minX) / bounds.width : 0.5
            let sweep = reduceMotion ? 0.55 : min(1.6, max(-0.4, travel * 2 - 0.4))
            return effect.colorEffect(
                ShaderLibrary.bundle(.module).holographicSheen(
                    .float2(proxy.size),
                    .float(sweep),
                    .float(intensity)
                ),
                isEnabled: isEnabled
            )
        }
    }
}
