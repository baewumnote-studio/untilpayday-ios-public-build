import Foundation
import SwiftData

@Model
final class BillTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var amountMinor: Int64
    var currencyCode: String
    var categoryRaw: String
    var recurrenceRaw: String
    var anchorDate: Date?
    var dayOfMonth: Int?
    var monthOfYear: Int?
    var useLastDay: Bool
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amountMinor: Int64,
        currencyCode: String,
        category: ExpenseCategory = .bills,
        recurrence: BillRecurrence,
        anchorDate: Date? = nil,
        dayOfMonth: Int? = nil,
        monthOfYear: Int? = nil,
        useLastDay: Bool = false,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amountMinor = max(0, amountMinor)
        self.currencyCode = currencyCode.uppercased()
        self.categoryRaw = category.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.anchorDate = anchorDate
        self.dayOfMonth = dayOfMonth
        self.monthOfYear = monthOfYear
        self.useLastDay = useLastDay
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var recurrence: BillRecurrence {
        BillRecurrence(rawValue: recurrenceRaw) ?? .none
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .bills
    }
}
