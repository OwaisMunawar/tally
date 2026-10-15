import SwiftUI
import TallyCore
import TallyUI

struct ActivityView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(AppRouter.self) private var router
    @Environment(PlusStore.self) private var plus
    @State private var searchText = ""
    @State private var category: TransactionCategory?
    @State private var path: [LedgerTransaction] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(sections, id: \.day) { section in
                    Section {
                        ForEach(section.transactions) { transaction in
                            NavigationLink(value: transaction) {
                                TransactionRow(transaction: transaction)
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task { await ledger.delete(transaction) }
                                }
                            }
                        }
                    } header: {
                        Text(section.day, format: .dateTime.weekday(.wide).day().month(.wide))
                    }
                }
            }
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Activity")
            .navigationDestination(for: LedgerTransaction.self) { transaction in
                TransactionDetailView(transactionID: transaction.id)
            }
            .searchable(text: $searchText, prompt: "Payee, note or tag")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Filter", systemImage: category == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") {
                        Picker("Category", selection: $category) {
                            Text("All categories").tag(TransactionCategory?.none)
                            ForEach(TransactionCategory.allCases) { category in
                                Label(category.displayName, systemImage: category.systemImage).tag(Optional(category))
                            }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Import CSV", systemImage: "square.and.arrow.down") {
                        router.sheet = plus.allows(.csvImport) ? .importCSV : .store
                    }
                    Button("Add Expense", systemImage: "plus") { router.sheet = .quickAdd }
                }
            }
            .task(id: ledger.isLoaded) { openFocusedPayee() }
        }
    }

    private struct DaySection {
        let day: Date
        let transactions: [LedgerTransaction]
    }

    private var sections: [DaySection] {
        guard let engine = ledger.engine else { return [] }
        let matches = engine.find(TransactionSearch(
            text: searchText.isEmpty ? nil : searchText,
            categories: category.map { [$0] },
            limit: 400
        ))
        return Dictionary(grouping: matches) { ledger.calendar.startOfDay(for: $0.date) }
            .map { DaySection(day: $0.key, transactions: $0.value) }
            .sorted { $0.day > $1.day }
    }

    private func openFocusedPayee() {
        guard let payee = router.focusedPayee, let engine = ledger.engine,
              let match = engine.find(TransactionSearch(text: payee, limit: 1)).first else { return }
        router.focusedPayee = nil
        path = [match]
    }
}
