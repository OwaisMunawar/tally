import SwiftUI

/// A content card on Liquid Glass.
///
/// Glass is reserved for surfaces that float over content (cards on the home
/// screen, the chat composer, toolbars). Dense lists stay on plain backgrounds
/// so text remains legible, as the Human Interface Guidelines recommend.
public struct GlassCard<Content: View>: View {
    private let tint: Color?
    private let isInteractive: Bool
    private let content: Content

    public init(tint: Color? = nil, interactive: Bool = false, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.isInteractive = interactive
        self.content = content()
    }

    public var body: some View {
        content
            .padding(TallyTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: TallyTheme.Radius.card))
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint.opacity(0.18)) }
        return glass.interactive(isInteractive)
    }
}

/// Section title used above cards and lists.
public struct SectionHeader: View {
    private let title: String
    private let systemImage: String?

    public init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: TallyTheme.Spacing.small) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            }
            Text(title).font(.headline)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
