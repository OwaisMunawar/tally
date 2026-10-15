import Foundation
import SwiftData
import TallyCore

// Persistence records mirror the domain types field for field but stay
// internal to this package. Two rules keep them CloudKit-compatible should
// sync be switched on: every attribute has a default, and there are no unique
// constraints or non-optional relationships (rows reference each other by UUID).

@Model
final class AccountRecord {
    var id = UUID()
    var name = ""
    var kindRaw = Account.Kind.bank.rawValue
    var currencyCode = "USD"
    var openingBalanceMinor: Int64 = 0
    var lastFour: String?
    var sortOrder = 0

    init(_ account: Account) {
        update(from: account)
    }

    func update(from account: Account) {
        id = account.id
        name = account.name
        kindRaw = account.kind.rawValue
        currencyCode = account.currency.rawValue
        openingBalanceMinor = account.openingBalance.minorUnits
        lastFour = account.lastFour
        sortOrder = account.sortOrder
    }

    var domain: Account {
        let currency = CurrencyCode(currencyCode)
        return Account(
            id: id,
            name: name,
            kind: Account.Kind(rawValue: kindRaw) ?? .bank,
            currency: currency,
            openingBalance: Money(minorUnits: openingBalanceMinor, currency: currency),
            lastFour: lastFour,
            sortOrder: sortOrder
        )
    }
}

@Model
final class TransactionRecord {
    var id = UUID()
    var accountID = UUID()
    var payee = ""
    var amountMinor: Int64 = 0
    var currencyCode = "USD"
    var categoryRaw = TransactionCategory.other.rawValue
    var sourceKind = "uncategorized"
    var sourceDetail = ""
    var sourceConfidence = 0
    var date = Date.distantPast
    var notes = ""
    var tags: [String] = []
    var recurringID: UUID?

    init(_ transaction: LedgerTransaction) {
        update(from: transaction)
    }

    func update(from transaction: LedgerTransaction) {
        id = transaction.id
        accountID = transaction.accountID
        payee = transaction.payee
        amountMinor = transaction.amount.minorUnits
        currencyCode = transaction.amount.currency.rawValue
        categoryRaw = transaction.category.rawValue
        date = transaction.date
        notes = transaction.notes
        tags = transaction.tags
        recurringID = transaction.recurringID
        switch transaction.categorization {
        case .manual:
            (sourceKind, sourceDetail, sourceConfidence) = ("manual", "", 100)
        case .rule(let keyword, let learned):
            (sourceKind, sourceDetail, sourceConfidence) = (learned ? "learnedRule" : "rule", keyword, 0)
        case .model(let confidence):
            (sourceKind, sourceDetail, sourceConfidence) = ("model", "", confidence)
        case .uncategorized:
            (sourceKind, sourceDetail, sourceConfidence) = ("uncategorized", "", 0)
        }
    }

    var domain: LedgerTransaction {
        let source: CategorizationSource = switch sourceKind {
        case "manual": .manual
        case "rule": .rule(keyword: sourceDetail, learned: false)
        case "learnedRule": .rule(keyword: sourceDetail, learned: true)
        case "model": .model(confidence: sourceConfidence)
        default: .uncategorized
        }
        return LedgerTransaction(
            id: id,
            accountID: accountID,
            payee: payee,
            amount: Money(minorUnits: amountMinor, currency: CurrencyCode(currencyCode)),
            category: TransactionCategory(rawValue: categoryRaw) ?? .other,
            categorization: source,
            date: date,
            notes: notes,
            tags: tags,
            recurringID: recurringID
        )
    }
}

@Model
final class BudgetRecord {
    var id = UUID()
    var categoryRaw = TransactionCategory.other.rawValue
    var limitMinor: Int64 = 0
    var currencyCode = "USD"

    init(_ budget: Budget) {
        update(from: budget)
    }

    func update(from budget: Budget) {
        id = budget.id
        categoryRaw = budget.category.rawValue
        limitMinor = budget.monthlyLimit.minorUnits
        currencyCode = budget.monthlyLimit.currency.rawValue
    }

    var domain: Budget {
        Budget(
            id: id,
            category: TransactionCategory(rawValue: categoryRaw) ?? .other,
            monthlyLimit: Money(minorUnits: limitMinor, currency: CurrencyCode(currencyCode))
        )
    }
}

@Model
final class RecurringRecord {
    var id = UUID()
    var accountID = UUID()
    var payee = ""
    var amountMinor: Int64 = 0
    var currencyCode = "USD"
    var categoryRaw = TransactionCategory.other.rawValue
    var frequencyRaw = RecurrenceRule.Frequency.monthly.rawValue
    var interval = 1
    var startDate = Date.distantPast
    var endDate: Date?

    init(_ recurring: RecurringTransaction) {
        update(from: recurring)
    }

    func update(from recurring: RecurringTransaction) {
        id = recurring.id
        accountID = recurring.accountID
        payee = recurring.payee
        amountMinor = recurring.amount.minorUnits
        currencyCode = recurring.amount.currency.rawValue
        categoryRaw = recurring.category.rawValue
        frequencyRaw = recurring.rule.frequency.rawValue
        interval = recurring.rule.interval
        startDate = recurring.startDate
        endDate = recurring.endDate
    }

    var domain: RecurringTransaction {
        RecurringTransaction(
            id: id,
            accountID: accountID,
            payee: payee,
            amount: Money(minorUnits: amountMinor, currency: CurrencyCode(currencyCode)),
            category: TransactionCategory(rawValue: categoryRaw) ?? .other,
            rule: RecurrenceRule(frequency: RecurrenceRule.Frequency(rawValue: frequencyRaw) ?? .monthly, interval: interval),
            startDate: startDate,
            endDate: endDate
        )
    }
}

@Model
final class CategoryRuleRecord {
    var keyword = ""
    var categoryRaw = TransactionCategory.other.rawValue
    var isLearned = true
    var createdAt = Date.distantPast

    init(_ rule: CategoryRule) {
        update(from: rule)
    }

    func update(from rule: CategoryRule) {
        keyword = rule.keyword
        categoryRaw = rule.category.rawValue
        isLearned = rule.isLearned
        createdAt = rule.createdAt
    }

    var domain: CategoryRule {
        CategoryRule(keyword: keyword, category: TransactionCategory(rawValue: categoryRaw) ?? .other, isLearned: isLearned, createdAt: createdAt)
    }
}

/// Rates are stored as decimal strings: SwiftData has no native Decimal column,
/// and a string round-trips exactly where a Double would not.
@Model
final class ExchangeRateRecord {
    var currencyCode = ""
    var unitsOfBase = "1"
    var isBase = false
    var updatedAt = Date.distantPast

    init(currencyCode: String, unitsOfBase: Decimal, isBase: Bool, updatedAt: Date) {
        self.currencyCode = currencyCode
        self.unitsOfBase = NSDecimalNumber(decimal: unitsOfBase).stringValue
        self.isBase = isBase
        self.updatedAt = updatedAt
    }
}
