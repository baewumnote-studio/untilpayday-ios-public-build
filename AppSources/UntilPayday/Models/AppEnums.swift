import Foundation
import UntilPaydayCore

enum TransactionType: String, Codable, CaseIterable {
    case expense
    case extraIncome
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food
    case transport
    case shopping
    case fun
    case household
    case health
    case bills
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: String(localized: "Food")
        case .transport: String(localized: "Transport")
        case .shopping: String(localized: "Shopping")
        case .fun: String(localized: "Fun")
        case .household: String(localized: "Household")
        case .health: String(localized: "Health")
        case .bills: String(localized: "Bills")
        case .other: String(localized: "Other")
        }
    }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .shopping: "bag.fill"
        case .fun: "sparkles"
        case .household: "house.fill"
        case .health: "cross.case.fill"
        case .bills: "doc.text.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

enum BillRecurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "Doesn’t repeat")
        case .weekly: String(localized: "Weekly")
        case .biweekly: String(localized: "Every 2 weeks")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }
}

enum BillStatus: String, Codable, CaseIterable {
    case pending
    case paid
    case skipped
}

extension PayScheduleType: Identifiable {
    public var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: String(localized: "Weekly")
        case .biweekly: String(localized: "Every 2 weeks")
        case .semiMonthly: String(localized: "Twice a month")
        case .monthly: String(localized: "Monthly")
        case .irregular: String(localized: "Irregular")
        }
    }
}

extension WeekendAdjustment: Identifiable {
    public var id: String { rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "No adjustment")
        case .previousWeekday: String(localized: "Previous weekday")
        case .nextWeekday: String(localized: "Next weekday")
        }
    }
}
