import Foundation

public enum PayScheduleType: String, Codable, CaseIterable, Sendable {
    case weekly
    case biweekly
    case semiMonthly
    case monthly
    case irregular
}

public enum WeekendAdjustment: String, Codable, CaseIterable, Sendable {
    case none
    case previousWeekday
    case nextWeekday
}

public enum DayRule: Equatable, Codable, Sendable {
    case fixed(Int)
    case lastDay
}

public struct PayScheduleConfiguration: Equatable, Sendable {
    public var type: PayScheduleType
    public var anchorPayday: Date?
    public var monthlyRule: DayRule?
    public var semiMonthlyFirstRule: DayRule?
    public var semiMonthlySecondRule: DayRule?
    public var weekendAdjustment: WeekendAdjustment
    public var manualNextPayday: Date?

    public init(
        type: PayScheduleType,
        anchorPayday: Date? = nil,
        monthlyRule: DayRule? = nil,
        semiMonthlyFirstRule: DayRule? = nil,
        semiMonthlySecondRule: DayRule? = nil,
        weekendAdjustment: WeekendAdjustment = .none,
        manualNextPayday: Date? = nil
    ) {
        self.type = type
        self.anchorPayday = anchorPayday
        self.monthlyRule = monthlyRule
        self.semiMonthlyFirstRule = semiMonthlyFirstRule
        self.semiMonthlySecondRule = semiMonthlySecondRule
        self.weekendAdjustment = weekendAdjustment
        self.manualNextPayday = manualNextPayday
    }
}


public struct PaydayOccurrence: Equatable, Sendable {
    public let nominalDate: Date
    public let adjustedDate: Date

    public init(nominalDate: Date, adjustedDate: Date) {
        self.nominalDate = nominalDate
        self.adjustedDate = adjustedDate
    }
}

public struct BudgetInput: Equatable, Sendable {
    public var baseFundsMinor: Int64
    public var expenseSpentMinor: Int64
    public var pendingBillReserveMinor: Int64
    public var savingsReserveMinor: Int64
    public var todayFlexibleSpentMinor: Int64
    public var daysRemaining: Int

    public init(
        baseFundsMinor: Int64,
        expenseSpentMinor: Int64,
        pendingBillReserveMinor: Int64,
        savingsReserveMinor: Int64,
        todayFlexibleSpentMinor: Int64,
        daysRemaining: Int
    ) {
        self.baseFundsMinor = baseFundsMinor
        self.expenseSpentMinor = expenseSpentMinor
        self.pendingBillReserveMinor = pendingBillReserveMinor
        self.savingsReserveMinor = savingsReserveMinor
        self.todayFlexibleSpentMinor = todayFlexibleSpentMinor
        self.daysRemaining = daysRemaining
    }
}

public enum BudgetState: Equatable, Sendable {
    case active
    case paydayTransition
}

public struct BudgetSnapshot: Equatable, Sendable {
    public var state: BudgetState
    public var leftUntilPaydayMinor: Int64
    public var safeTodayPlanMinor: Int64
    public var safeTodayRemainingMinor: Int64
    public var shortByMinor: Int64
    public var overTodayPaceMinor: Int64

    public init(
        state: BudgetState,
        leftUntilPaydayMinor: Int64,
        safeTodayPlanMinor: Int64,
        safeTodayRemainingMinor: Int64,
        shortByMinor: Int64,
        overTodayPaceMinor: Int64
    ) {
        self.state = state
        self.leftUntilPaydayMinor = leftUntilPaydayMinor
        self.safeTodayPlanMinor = safeTodayPlanMinor
        self.safeTodayRemainingMinor = safeTodayRemainingMinor
        self.shortByMinor = shortByMinor
        self.overTodayPaceMinor = overTodayPaceMinor
    }
}
