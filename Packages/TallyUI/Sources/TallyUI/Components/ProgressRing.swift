import SwiftUI

/// A circular progress indicator that shows overspend as a second lap.
public struct ProgressRing<Label: View>: View {
    private let progress: Double
    private let tint: Color
    private let lineWidth: CGFloat
    private let label: Label

    public init(progress: Double, tint: Color, lineWidth: CGFloat = 10, @ViewBuilder label: () -> Label) {
        self.progress = progress.isFinite ? max(0, progress) : 0
        self.tint = tint
        self.lineWidth = lineWidth
        self.label = label()
    }

    public var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress > 1 {
                Circle()
                    .trim(from: 0, to: min(progress - 1, 1))
                    .stroke(tint.mix(with: .black, by: 0.25), style: StrokeStyle(lineWidth: lineWidth * 0.55, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            label
        }
        .animation(.smooth, value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

public extension ProgressRing where Label == EmptyView {
    init(progress: Double, tint: Color, lineWidth: CGFloat = 10) {
        self.init(progress: progress, tint: tint, lineWidth: lineWidth) { EmptyView() }
    }
}
