import Foundation
import FoundationModels
import TallyCore

public enum AskTallyError: Error, Equatable, Sendable {
    case unavailable(AssistantAvailability)
    case blockedBySafety
    case busy
    case failed(String)

    public var message: String {
        switch self {
        case .unavailable(let availability): availability.explanation
        case .blockedBySafety: "Apple Intelligence declined to answer that. Try rephrasing the question."
        case .busy: "Tally is still answering the previous question."
        case .failed(let detail): "Something went wrong: \(detail)"
        }
    }
}

/// A chat with the on-device model that can only see the ledger through tools.
///
/// The session is rebuilt for every question from the previous transcript, so
/// the conversation keeps its context while the tools always query the latest
/// snapshot of the ledger.
public actor AskTallyConversation {
    private let model: SystemLanguageModel
    private let validator = GroundingValidator()
    private var transcript: Transcript?
    private var isResponding = false

    public init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    public func reset() {
        transcript = nil
    }

    public func ask(_ question: String, engine: LedgerQueryEngine) async throws(AskTallyError) -> AskTallyAnswer {
        let availability = AssistantAvailability.current
        guard availability.isAvailable else { throw .unavailable(availability) }
        guard !isResponding else { throw .busy }
        isResponding = true
        defer { isResponding = false }

        do {
            return try await answer(question, engine: engine, session: makeSession(engine: engine))
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Long chats outgrow the small context window; start fresh rather than fail.
            transcript = nil
            do {
                return try await answer(question, engine: engine, session: makeSession(engine: engine))
            } catch {
                throw Self.map(error)
            }
        } catch {
            throw Self.map(error)
        }
    }

    private func makeSession(engine: LedgerQueryEngine) -> LanguageModelSession {
        let tools = LedgerTools.all(engine: engine)
        if let transcript {
            return LanguageModelSession(model: model, tools: tools, transcript: transcript)
        }
        return LanguageModelSession(model: model, tools: tools, instructions: AskTallyPrompt.instructions(engine: engine))
    }

    private func answer(_ question: String, engine: LedgerQueryEngine, session: LanguageModelSession) async throws -> AskTallyAnswer {
        let options = GenerationOptions(sampling: .greedy)
        var response = try await session.respond(to: question, options: options)
        var calls = Self.invocations(in: response.transcriptEntries)
        var report = validator.validate(answer: response.content, evidence: calls.map(\.output) + [question])
        var repaired = false

        if !report.isGrounded {
            // One repair pass: name the offending figures and ask for a rewrite
            // from the tool output already in the transcript.
            response = try await session.respond(to: AskTallyPrompt.repair(unverified: report.unverified), options: options)
            calls += Self.invocations(in: response.transcriptEntries)
            report = validator.validate(answer: response.content, evidence: calls.map(\.output) + [question])
            repaired = true
        }

        transcript = session.transcript
        return AskTallyAnswer(question: question, text: response.content, toolCalls: calls, grounding: report, wasRepaired: repaired)
    }

    /// Pairs each tool call with its output from the transcript entries of one response.
    static func invocations(in entries: ArraySlice<Transcript.Entry>) -> [ToolInvocation] {
        var calls: [Transcript.ToolCall] = []
        var outputs: [String: String] = [:]
        for entry in entries {
            switch entry {
            case .toolCalls(let toolCalls):
                calls.append(contentsOf: toolCalls)
            case .toolOutput(let output):
                outputs[output.id] = output.segments.map { segment in
                    switch segment {
                    case .text(let text): text.content
                    case .structure(let structure): structure.content.jsonString
                    @unknown default: ""
                    }
                }.joined(separator: "\n")
            default:
                continue
            }
        }
        return calls.map { call in
            ToolInvocation(
                id: call.id,
                toolName: call.toolName,
                arguments: ToolInvocation.arguments(fromJSON: call.arguments.jsonString),
                output: outputs[call.id] ?? ""
            )
        }
    }

    private static func map(_ error: any Error) -> AskTallyError {
        if let error = error as? AskTallyError { return error }
        guard let generation = error as? LanguageModelSession.GenerationError else {
            if let toolError = error as? LanguageModelSession.ToolCallError {
                return .failed("the \(toolError.tool.name) tool failed")
            }
            return .failed(error.localizedDescription)
        }
        switch generation {
        case .guardrailViolation, .refusal:
            return .blockedBySafety
        case .rateLimited, .concurrentRequests:
            return .busy
        case .assetsUnavailable:
            return .unavailable(.modelDownloading)
        case .unsupportedLanguageOrLocale:
            return .unavailable(.unsupportedLanguage)
        default:
            return .failed(generation.localizedDescription)
        }
    }
}

enum AskTallyPrompt {
    static func instructions(engine: LedgerQueryEngine) -> String {
        let today = engine.now.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: Locale(identifier: "en_US"),
                                                          calendar: engine.calendar, timeZone: engine.calendar.timeZone))
        let categories = TransactionCategory.spendingCases.map { "\($0.rawValue) (\($0.definition))" }.joined(separator: "; ")
        return """
        You are Tally, a personal finance assistant running privately on the user's iPhone.
        Today is \(today). Amounts are in \(engine.baseCurrency.rawValue).
        Answer questions about the user's money only by calling the tools. Always call a tool before answering.
        Every amount, count and percentage in your answer must be copied exactly from a tool result.
        Never calculate, estimate or round figures yourself.
        When the question compares two periods, call compareRanges once and quote its totals and difference.
        If the tools don't return what's needed, say so plainly.
        Answer in at most three short sentences, without lists or markdown.
        Spending categories: \(categories). "food" means groceries plus dining.
        """
    }

    static func repair(unverified: [String]) -> String {
        """
        These figures in your answer did not appear in any tool result: \(unverified.joined(separator: ", ")). \
        If you need a difference between periods, call compareRanges. \
        Then rewrite the answer using only figures exactly as the tools returned them.
        """
    }
}
