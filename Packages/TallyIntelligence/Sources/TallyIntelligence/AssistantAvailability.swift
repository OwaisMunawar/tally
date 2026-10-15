import FoundationModels

/// Whether the on-device model can be used right now, in terms the UI can explain.
public enum AssistantAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceOff
    case modelDownloading
    case unsupportedLanguage

    public static var current: AssistantAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? .available : .unsupportedLanguage
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceOff
        case .unavailable(.modelNotReady):
            return .modelDownloading
        case .unavailable:
            return .deviceNotEligible
        }
    }

    public var isAvailable: Bool { self == .available }

    /// What the user sees in place of AI features. Each message says what still works.
    public var explanation: String {
        switch self {
        case .available:
            "On-device Apple Intelligence is ready."
        case .deviceNotEligible:
            "This device doesn't support Apple Intelligence. Rules, budgets and charts work as usual."
        case .appleIntelligenceOff:
            "Turn on Apple Intelligence in Settings to ask questions. Rules, budgets and charts work as usual."
        case .modelDownloading:
            "Apple Intelligence is still downloading. Try again shortly; rules keep categorising meanwhile."
        case .unsupportedLanguage:
            "Apple Intelligence doesn't support your language yet. Rules, budgets and charts work as usual."
        }
    }
}
