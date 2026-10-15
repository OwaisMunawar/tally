import Foundation

public struct Account: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, CaseIterable, Sendable, Codable {
        case cash, bank, card

        public var displayName: String {
            switch self {
            case .cash: "Cash"
            case .bank: "Bank"
            case .card: "Card"
            }
        }

        public var systemImage: String {
            switch self {
            case .cash: "banknote.fill"
            case .bank: "building.columns.fill"
            case .card: "creditcard.fill"
            }
        }
    }

    public var id: UUID
    public var name: String
    public var kind: Kind
    public var currency: CurrencyCode
    public var openingBalance: Money
    public var lastFour: String?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        kind: Kind,
        currency: CurrencyCode,
        openingBalance: Money? = nil,
        lastFour: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.currency = currency
        self.openingBalance = openingBalance ?? .zero(currency)
        self.lastFour = lastFour
        self.sortOrder = sortOrder
    }
}
