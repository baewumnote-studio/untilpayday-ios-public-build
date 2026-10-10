import Foundation
import SwiftData

@Model
final class BudgetTransaction {
    @Attribute(.unique) var id: UUID
    var cycleID: UUID
    var typeRaw: String
    var amountMinor: Int64
    var categoryRaw: String
    var note: String
    var transactionDate: Date
    var linkedBillOccurrenceID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        cycleID: UUID,
        type: TransactionType,
        amountMinor: Int64,
        category: ExpenseCategory = .other,
        note: String = "",
        transactionDate: Date = .now,
        linkedBillOccurrenceID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.cycleID = cycleID
        self.typeRaw = type.rawValue
        self.amountMinor = max(0, amountMinor)
        self.categoryRaw = category.rawValue
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transactionDate = transactionDate
        self.linkedBillOccurrenceID = linkedBillOccurrenceID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: TransactionType {
        TransactionType(rawValue: typeRaw) ?? .expense
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .other
    }
}
