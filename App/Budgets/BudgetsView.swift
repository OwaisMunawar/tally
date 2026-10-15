import SwiftUI
import TallyCore
import TallyUI

struct BudgetsView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(PlusStore.self) private var plus
    @Environment(AppRouter.self) private var router
    @State private var editing: Budget?
    @State private var isAdding = false

    private let columns = [GridItem(.flexible(), spacing: TallyTheme.Spacing.medium), GridItem(.flexible(), spacing: TallyTheme.Spacing.medium)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let engine = ledger.engine {
                    let statuses = engine.budgetStatuses()
                    VStack(spacing: TallyTheme.Spacing.large) {
                        summary(engine)
                        if statuses.isEmpty {
                            ContentUnavailableView("No budgets yet", systemImage: "chart.pie",
                                                   description: Text("Set a monthly limit for a category and Tally alerts you if you go over."))
                        }
                        GlassEffectContainer(spacing: TallyTheme.Spacing.medium) {
                            LazyVGrid(columns: columns, spacing: TallyTheme.Spacing.medium) {
                                ForEach(statuses) { status in
                                    Button { editing = status.budget } label: { BudgetTile(status: status) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, TallyTheme.Spacing.xLarge)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budgets")
            .toolbar {
                Button("Add Budget", systemImage: "plus") {
                    if plus.allows(.unlimitedBudgets, existingBudgets: ledger.data.budgets.count) {
                        isAdding = true
                    } else {
                        router.sheet = .store
                    }
                }
            }
            .sheet(isPresented: $isAdding) { BudgetEditor(budget: nil) }
            .sheet(item: $editing) { BudgetEditor(budget: $0) }
        }
    }

    private func summary(_ engine: LedgerQueryEngine) -> some View {
        let totals = engine.totalBudgetRemaining()
        let over = engine.budgetStatuses().filter { $0.state == .over }
        return GlassCard(tint: over.isEmpty ? TallyTheme.positive : TallyTheme.negative) {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.small) {
                Text("Left to spend this month").font(.subheadline).foregroundStyle(.secondary)
                MoneyText(totals.remaining, style: .hero)
                Text("of \(totals.limit.formatted()) across \(engine.data.budgets.count) budgets")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !over.isEmpty {
                    Label("\(over.map(\.budget.category.displayName).joined(separator: ", ")) over budget", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TallyTheme.negative)
                }
                if !plus.isPlus {
                    Text("Free includes \(plus.policy.freeBudgetLimit) budgets. Tally Plus removes the limit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct BudgetTile: View {
    let status: BudgetStatus

    var body: some View {
        VStack(spacing: TallyTheme.Spacing.medium) {
            ProgressRing(progress: status.progress, tint: TallyTheme.color(for: status.state), lineWidth: 11) {
                VStack(spacing: 0) {
                    Image(systemName: status.budget.category.systemImage)
                        .font(.title3)
                        .foregroundStyle(TallyTheme.color(for: status.budget.category))
                    Text(status.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
            }
            .frame(width: 92, height: 92)
            VStack(spacing: 2) {
                Text(status.budget.category.displayName).font(.subheadline.weight(.semibold))
                Text("\(status.spent.formattedWhole()) of \(status.budget.monthlyLimit.formattedWhole())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(status.remaining.isNegative ? "\(status.remaining.magnitude.formatted()) over" : "\(status.remaining.formatted()) left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.state == .over ? TallyTheme.negative : TallyTheme.color(for: status.state))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TallyTheme.Spacing.large)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: TallyTheme.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit budget")
    }
}

struct BudgetEditor: View {
    let budget: Budget?
    @Environment(LedgerStore.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State private var category: TransactionCategory = .dining
    @State private var limit: Decimal?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(availableCategories) { Label($0.displayName, systemImage: $0.systemImage).tag($0) }
                }
                .disabled(budget != nil)
                TextField("Monthly limit (\(ledger.baseCurrency.rawValue))", value: $limit, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                if let budget {
                    Button("Delete Budget", role: .destructive) {
                        Task { await ledger.delete(budget); dismiss() }
                    }
                }
            }
            .navigationTitle(budget == nil ? "New Budget" : "Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .buttonStyle(.glassProminent)
                        .disabled((limit ?? 0) <= 0)
                }
            }
            .onAppear {
                if let budget {
                    category = budget.category
                    limit = budget.monthlyLimit.amount
                } else if let first = availableCategories.first {
                    category = first
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var availableCategories: [TransactionCategory] {
        let used = Set(ledger.data.budgets.map(\.category))
        return TransactionCategory.spendingCases.filter { !used.contains($0) || $0 == budget?.category }
    }

    private func save() async {
        guard let limit, let money = try? Money(limit, currency: ledger.baseCurrency) else { return }
        await ledger.save(Budget(id: budget?.id ?? UUID(), category: category, monthlyLimit: money))
        dismiss()
    }
}
