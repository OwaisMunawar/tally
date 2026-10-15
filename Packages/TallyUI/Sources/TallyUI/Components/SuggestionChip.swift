import SwiftUI

/// A tappable prompt suggestion on interactive glass.
public struct SuggestionChip: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    public init(_ title: String, systemImage: String = "sparkles", action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
    }
}
