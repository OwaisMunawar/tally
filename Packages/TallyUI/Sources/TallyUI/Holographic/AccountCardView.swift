import SwiftUI
import TallyCore

/// A payment-card style tile for one account, finished with the holographic sheen.
public struct AccountCardView: View {
    private let account: Account
    private let balance: Money
    private let baseEquivalent: Money?

    public init(account: Account, balance: Money, baseEquivalent: Money? = nil) {
        self.account = account
        self.balance = balance
        self.baseEquivalent = baseEquivalent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TallyTheme.Spacing.small) {
            HStack {
                Label(account.kind.displayName, systemImage: account.kind.systemImage)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                Spacer()
                Text(account.currency.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: .capsule)
            }
            Spacer(minLength: TallyTheme.Spacing.small)
            Text(balance.formatted())
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let baseEquivalent, baseEquivalent.currency != balance.currency {
                Text("≈ \(baseEquivalent.formatted())")
                    .font(.footnote.weight(.medium))
                    .opacity(0.8)
            }
            HStack {
                Text(account.name).font(.subheadline.weight(.semibold))
                Spacer()
                if let lastFour = account.lastFour {
                    Text("•••• \(lastFour)").font(.subheadline.monospacedDigit())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(TallyTheme.Spacing.large + 2)
        .aspectRatio(1.586, contentMode: .fit)
        .background(TallyTheme.cardGradient(for: account.kind), in: .rect(cornerRadius: TallyTheme.Radius.accountCard))
        .holographicSheen()
        .overlay {
            RoundedRectangle(cornerRadius: TallyTheme.Radius.accountCard)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(account.name), \(account.kind.displayName)")
        .accessibilityValue(balance.formatted())
    }
}
