import Foundation
import Observation
import TallyCore
import TallyIntelligence

/// Chat state for Ask Tally. Each question runs against a fresh query engine
/// from the ledger, so answers reflect edits made mid-conversation.
@MainActor
@Observable
final class AskTallyModel {
    enum Message: Identifiable {
        case question(id: UUID, text: String)
        case answer(AskTallyAnswer)
        case failure(id: UUID, text: String)

        var id: UUID {
            switch self {
            case .question(let id, _), .failure(let id, _): id
            case .answer(let answer): answer.id
            }
        }
    }

    private(set) var messages: [Message] = []
    private(set) var isThinking = false
    var draft = ""

    @ObservationIgnored private let conversation = AskTallyConversation()

    var availability: AssistantAvailability { AssistantAvailability.current }

    static let suggestions = [
        "How much did I spend on food in September vs August?",
        "Who are my top payees this month?",
        "Am I over budget anywhere?",
        "What did I spend at Blue Bottle Coffee last month?",
    ]

    func send(_ text: String, using ledger: LedgerStore) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking, let engine = ledger.engine else { return }
        draft = ""
        messages.append(.question(id: UUID(), text: question))
        isThinking = true
        defer { isThinking = false }
        do {
            messages.append(.answer(try await conversation.ask(question, engine: engine)))
        } catch {
            messages.append(.failure(id: UUID(), text: error.message))
        }
    }

    func reset() async {
        messages.removeAll()
        await conversation.reset()
    }
}
