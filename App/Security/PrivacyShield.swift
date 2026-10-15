import SwiftUI
import TallyUI

/// Covers the app in the app switcher and while locked, so balances never
/// appear in a snapshot.
struct PrivacyShield: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: TallyTheme.Spacing.large) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(TallyTheme.accent.gradient)
                Text("Tally is locked").font(.title2.weight(.semibold))
                if lock.isLocked {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Unlock with \(AppLock.biometryName)", systemImage: "faceid")
                            .padding(.horizontal, TallyTheme.Spacing.small)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    if let message = lock.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
        }
        .ignoresSafeArea()
        .task {
            if lock.isLocked { await lock.unlock() }
        }
    }
}
