import Foundation

struct UpcomingBillRowState: Identifiable, Equatable {
    let id: UUID
    let name: String
    let dueDate: Date
    let daysUntilDue: Int
    let plannedAmountMinor: Int64
    let currencyCode: String
}

struct TodayViewState: Equatable {
    let currencyCode: String
    let nextPayday: Date
    let daysRemaining: Int
    let leftUntilPaydayMinor: Int64
    let safeTodayMinor: Int64
    let todayFlexibleSpentMinor: Int64
    let dailyPaceMinor: Int64
    let overTodayPaceMinor: Int64
    let shortByMinor: Int64
    let upcomingBills: [UpcomingBillRowState]
    let isPaydayReady: Bool
    let previousCycleLeftoverMinor: Int64

    var visibleLeftUntilPaydayMinor: Int64 {
        max(0, leftUntilPaydayMinor)
    }

    var isShort: Bool {
        shortByMinor > 0
    }

    var isOverTodayPace: Bool {
        !isShort && overTodayPaceMinor > 0
    }
}
