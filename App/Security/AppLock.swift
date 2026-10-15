import Foundation
import LocalAuthentication
import Observation

/// Face ID / passcode lock, re-armed whenever the app goes to the background.
@MainActor
@Observable
final class AppLock {
    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var errorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "appLockEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.key)
        isEnabled = enabled
        isLocked = enabled
    }

    func lock() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        do {
            if try await Self.authenticate(reason: "Unlock your finances") {
                isLocked = false
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Turning the lock on or off requires proving you can unlock it.
    func setEnabled(_ enabled: Bool) async {
        do {
            guard try await Self.authenticate(reason: enabled ? "Turn on App Lock" : "Turn off App Lock") else { return }
            isEnabled = enabled
            defaults.set(enabled, forKey: Self.key)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return switch context.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    /// Device-owner authentication falls back to the passcode when biometrics
    /// fail or aren't enrolled. The context is created here so it never crosses actors.
    nonisolated private static func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? LAError(.passcodeNotSet)
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}
