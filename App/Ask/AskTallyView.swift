import SwiftUI
import TallyCore
import TallyIntelligence
import TallyUI

struct AskTallyView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(PlusStore.self) private var plus
    @Environment(AppRouter.self) private var router
    @State private var model = AskTallyModel()
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TallyTheme.Spacing.large) {
                        intro
                        ForEach(model.messages) { message in
                            MessageView(message: message).id(message.id)
                        }
                        if model.isThinking {
                            ThinkingIndicator().id("thinking")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) {
                    // Keep the question in view above its answer rather than scrolling it away.
                    let question = model.messages.last { if case .question = $0 { true } else { false } }
                    withAnimation { proxy.scrollTo(question?.id, anchor: .top) }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ask Tally")
            .toolbar {
                if !model.messages.isEmpty {
                    Button("New Chat", systemImage: "square.and.pencil") { Task { await model.reset() } }
                }
            }
            .task(id: ledger.isLoaded) { await askPendingQuestion() }
        }
    }

    private var canAsk: Bool {
        plus.allows(.askTally) && model.availability.isAvailable
    }

    @ViewBuilder
    private var intro: some View {
        if model.messages.isEmpty {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                Label("Private by design", systemImage: "lock.iphone")
                    .font(.headline)
                Text("""
                    Ask about your money in plain English. Apple Intelligence answers on this iPhone by calling \
                    Tally's own calculations, and every figure is checked against them.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !model.availability.isAvailable {
                    Label(model.availability.explanation, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(TallyTheme.warning)
                } else if !plus.allows(.askTally) {
                    Button("Unlock Ask Tally with Plus", systemImage: "sparkles") { router.sheet = .store }
                        .buttonStyle(.glassProminent)
                } else {
                    GlassEffectContainer(spacing: TallyTheme.Spacing.small) {
                        VStack(alignment: .leading, spacing: TallyTheme.Spacing.small) {
                            ForEach(AskTallyModel.suggestions, id: \.self) { suggestion in
                                SuggestionChip(suggestion) { Task { await model.send(suggestion, using: ledger) } }
                            }
                        }
                    }
                }
            }
            .padding(.top, TallyTheme.Spacing.small)
        }
    }

    private var composer: some View {
        @Bindable var model = model
        return HStack(spacing: TallyTheme.Spacing.small) {
            TextField("Ask about your spending", text: $model.draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit { Task { await model.send(model.draft, using: ledger) } }
                .padding(.horizontal, TallyTheme.Spacing.large)
                .padding(.vertical, TallyTheme.Spacing.medium)
                .glassEffect(.regular.interactive(), in: .capsule)
            Button {
                Task { await model.send(model.draft, using: ledger) }
            } label: {
                Image(systemName: "arrow.up").font(.body.weight(.bold)).frame(width: 28, height: 28)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty || model.isThinking)
            .accessibilityLabel("Send")
        }
        .disabled(!canAsk)
        .padding(.horizontal)
        .padding(.bottom, TallyTheme.Spacing.small)
    }

    private func askPendingQuestion() async {
        guard ledger.isLoaded, let question = router.pendingQuestion else { return }
        router.pendingQuestion = nil
        await model.send(question, using: ledger)
    }
}

private struct MessageView: View {
    let message: AskTallyModel.Message

    var body: some View {
        switch message {
        case .question(_, let text):
            Text(text)
                .padding(.horizontal, TallyTheme.Spacing.large)
                .padding(.vertical, TallyTheme.Spacing.medium)
                .foregroundStyle(.white)
                .background(TallyTheme.accent.gradient, in: .rect(cornerRadius: 20))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 48)
        case .answer(let answer):
            AnswerCard(answer: answer)
        case .failure(_, let text):
            Label(text, systemImage: "exclamationmark.bubble")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// The model's answer, a grounding badge, and the tool trace behind it.
private struct AnswerCard: View {
    let answer: AskTallyAnswer
    @State private var showsTrace = true

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                Label("Tally · on device", systemImage: "apple.intelligence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
                Text(answer.text).font(.body).textSelection(.enabled)
                GroundingBadge(report: answer.grounding, wasRepaired: answer.wasRepaired)
                if !answer.toolCalls.isEmpty {
                    DisclosureGroup(isExpanded: $showsTrace) {
                        VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                            ForEach(answer.toolCalls) { ToolCallView(call: $0) }
                        }
                        .padding(.top, TallyTheme.Spacing.small)
                    } label: {
                        Label("How Tally got this · \(answer.toolCalls.count) tool \(answer.toolCalls.count == 1 ? "call" : "calls")",
                              systemImage: "wrench.and.screwdriver")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        .padding(.trailing, TallyTheme.Spacing.large)
    }
}

private struct GroundingBadge: View {
    let report: GroundingReport
    let wasRepaired: Bool

    var body: some View {
        if report.isGrounded {
            Label(report.verified.isEmpty ? "No figures to check" : "\(report.verified.count) \(report.verified.count == 1 ? "figure matches" : "figures match") Tally's data",
                  systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TallyTheme.positive)
        } else {
            Label("Unverified: \(report.unverified.joined(separator: ", ")). Check the tool results below.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TallyTheme.warning)
        }
    }
}

private struct ToolCallView: View {
    let call: ToolInvocation

    var body: some View {
        VStack(alignment: .leading, spacing: TallyTheme.Spacing.xSmall) {
            Text(signature)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(TallyTheme.accent)
            Text(call.output)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TallyTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var signature: String {
        let arguments = call.arguments.map { "\($0.name): \"\($0.value)\"" }.joined(separator: ", ")
        return "\(call.toolName)(\(arguments))"
    }
}

private struct ThinkingIndicator: View {
    var body: some View {
        Label("Checking your ledger…", systemImage: "ellipsis")
            .symbolEffect(.variableColor.iterative, options: .repeating)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(TallyTheme.Spacing.medium)
            .glassEffect(.regular, in: .capsule)
    }
}
