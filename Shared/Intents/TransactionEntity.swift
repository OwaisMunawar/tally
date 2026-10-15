import AppIntents
import CoreSpotlight
import Foundation
import TallyCore

/// A transaction as Spotlight, Siri and Shortcuts see it.
struct TransactionEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Transaction", numericFormat: "\(placeholder: .int) transactions")
    static let defaultQuery = TransactionEntityQuery()

    let id: UUID
    let payee: String
    let amountText: String
    let categoryName: String
    let date: Date

    init(_ transaction: LedgerTransaction) {
        id = transaction.id
        payee = transaction.payee
        amountText = transaction.amount.formatted()
        categoryName = transaction.category.displayName
        date = transaction.date
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(payee)",
            subtitle: "\(amountText) · \(categoryName) · \(date.formatted(date: .abbreviated, time: .omitted))",
            image: .init(systemName: "creditcard")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.displayName = payee
        attributes.contentDescription = "\(amountText) · \(categoryName) · \(date.formatted(date: .abbreviated, time: .omitted))"
        attributes.keywords = [payee, categoryName, "Tally"]
        attributes.contentCreationDate = date
        return attributes
    }
}

struct TransactionEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [TransactionEntity] {
        let wanted = Set(identifiers)
        return try await SharedLedger.makeRepository().load().transactions
            .filter { wanted.contains($0.id) }
            .map(TransactionEntity.init)
    }

    func entities(matching string: String) async throws -> [TransactionEntity] {
        try await SharedLedger.engine().find(TransactionSearch(text: string, limit: 25)).map(TransactionEntity.init)
    }

    func suggestedEntities() async throws -> [TransactionEntity] {
        try await SharedLedger.engine().find(TransactionSearch(limit: 10)).map(TransactionEntity.init)
    }
}

/// A merchant, with what the user has spent there this year.
struct PayeeEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Payee"
    static let defaultQuery = PayeeEntityQuery()

    let id: String
    let name: String
    let summary: String

    init(_ total: PayeeTotal) {
        id = PayeeNormalizer.normalize(total.payee)
        name = total.payee
        summary = "\(total.total.formatted()) this year · \(total.transactionCount) purchases"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)", image: .init(systemName: "storefront"))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.displayName = name
        attributes.contentDescription = summary
        attributes.keywords = [name, "Tally", "payee"]
        return attributes
    }
}

struct PayeeEntityQuery: EntityStringQuery {
    private func all() async throws -> [PayeeEntity] {
        let engine = try await SharedLedger.engine()
        return engine.topPayees(in: .year(containing: engine.now, calendar: engine.calendar), limit: 200).map(PayeeEntity.init)
    }

    func entities(for identifiers: [String]) async throws -> [PayeeEntity] {
        let wanted = Set(identifiers)
        return try await all().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PayeeEntity] {
        let needle = PayeeNormalizer.normalize(string)
        return try await all().filter { $0.id.contains(needle) }
    }

    func suggestedEntities() async throws -> [PayeeEntity] {
        try await Array(all().prefix(10))
    }
}
