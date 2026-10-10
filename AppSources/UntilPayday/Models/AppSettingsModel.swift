import Foundation
import SwiftData
import UntilPaydayCore

@Model
final class AppSettingsModel {
    @Attribute(.unique) var id: UUID
    var currencyCode: String
    var scheduleTypeRaw: String
    var anchorPayday: Date?
    var monthlyDay: Int
    var monthlyUseLastDay: Bool
    var semiMonthlyFirstDay: Int
    var semiMonthlyFirstUseLastDay: Bool
    var semiMonthlySecondDay: Int
    var semiMonthlySecondUseLastDay: Bool
    var weekendAdjustmentRaw: String
    var manualNextPayday: Date?
    var defaultPayAmountMinor: Int64
    var defaultSavingsMinor: Int64
    var onboardingCompleted: Bool
    var paydayNotificationsEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        scheduleType: PayScheduleType = .biweekly,
        anchorPayday: Date? = nil,
        monthlyDay: Int = 1,
        monthlyUseLastDay: Bool = false,
        semiMonthlyFirstDay: Int = 1,
        semiMonthlyFirstUseLastDay: Bool = false,
        semiMonthlySecondDay: Int = 15,
        semiMonthlySecondUseLastDay: Bool = false,
        weekendAdjustment: WeekendAdjustment = .none,
        manualNextPayday: Date? = nil,
        defaultPayAmountMinor: Int64 = 0,
        defaultSavingsMinor: Int64 = 0,
        onboardingCompleted: Bool = false,
        paydayNotificationsEnabled: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.currencyCode = currencyCode.uppercased()
        self.scheduleTypeRaw = scheduleType.rawValue
        self.anchorPayday = anchorPayday
        self.monthlyDay = monthlyDay
        self.monthlyUseLastDay = monthlyUseLastDay
        self.semiMonthlyFirstDay = semiMonthlyFirstDay
        self.semiMonthlyFirstUseLastDay = semiMonthlyFirstUseLastDay
        self.semiMonthlySecondDay = semiMonthlySecondDay
        self.semiMonthlySecondUseLastDay = semiMonthlySecondUseLastDay
        self.weekendAdjustmentRaw = weekendAdjustment.rawValue
        self.manualNextPayday = manualNextPayday
        self.defaultPayAmountMinor = max(0, defaultPayAmountMinor)
        self.defaultSavingsMinor = max(0, defaultSavingsMinor)
        self.onboardingCompleted = onboardingCompleted
        self.paydayNotificationsEnabled = paydayNotificationsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var scheduleType: PayScheduleType {
        get { PayScheduleType(rawValue: scheduleTypeRaw) ?? .biweekly }
        set { scheduleTypeRaw = newValue.rawValue; updatedAt = .now }
    }

    var weekendAdjustment: WeekendAdjustment {
        get { WeekendAdjustment(rawValue: weekendAdjustmentRaw) ?? .none }
        set { weekendAdjustmentRaw = newValue.rawValue; updatedAt = .now }
    }

    var scheduleConfiguration: PayScheduleConfiguration {
        let monthlyRule: DayRule = monthlyUseLastDay ? .lastDay : .fixed(monthlyDay)
        let first: DayRule = semiMonthlyFirstUseLastDay ? .lastDay : .fixed(semiMonthlyFirstDay)
        let second: DayRule = semiMonthlySecondUseLastDay ? .lastDay : .fixed(semiMonthlySecondDay)
        return PayScheduleConfiguration(
            type: scheduleType,
            anchorPayday: anchorPayday,
            monthlyRule: monthlyRule,
            semiMonthlyFirstRule: first,
            semiMonthlySecondRule: second,
            weekendAdjustment: weekendAdjustment,
            manualNextPayday: manualNextPayday
        )
    }
}
