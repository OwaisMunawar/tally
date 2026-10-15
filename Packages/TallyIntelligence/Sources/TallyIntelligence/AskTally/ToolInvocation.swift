import Foundation

/// One tool call as it appeared in the session transcript, for the
/// "How Tally got this" disclosure under every answer.
public struct ToolInvocation: Identifiable, Hashable, Sendable {
    public let id: String
    public let toolName: String
    /// Arguments as `key: value` pairs in a stable order.
    public let arguments: [Argument]
    public let output: String

    public struct Argument: Hashable, Sendable {
        public let name: String
        public let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    public init(id: String, toolName: String, arguments: [Argument], output: String) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.output = output
    }

    /// Flattens the JSON the framework records for tool arguments.
    static func arguments(fromJSON json: String) -> [Argument] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return json.isEmpty ? [] : [Argument(name: "arguments", value: json)]
        }
        return object.keys.sorted().map { key in
            Argument(name: key, value: object[key].map { "\($0)" } ?? "")
        }
    }
}

/// The answer to one Ask Tally question, with the evidence behind it.
public struct AskTallyAnswer: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let question: String
    public let text: String
    public let toolCalls: [ToolInvocation]
    public let grounding: GroundingReport
    /// True when the first draft quoted an unverified figure and was rewritten.
    public let wasRepaired: Bool

    public init(id: UUID = UUID(), question: String, text: String, toolCalls: [ToolInvocation], grounding: GroundingReport, wasRepaired: Bool) {
        self.id = id
        self.question = question
        self.text = text
        self.toolCalls = toolCalls
        self.grounding = grounding
        self.wasRepaired = wasRepaired
    }
}
