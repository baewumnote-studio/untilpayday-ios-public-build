import Foundation

public enum PayScheduleError: Error, Equatable {
    case missingAnchor
    case missingRule
    case missingManualPayday
    case invalidDayRule
    case unableToGenerate
}

public enum PayScheduleEngine {
    public static func daysRemaining(
        from date: Date,
        to nextPayday: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: nextPayday)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    public static func nextPayday(
        onOrAfter referenceDate: Date,
        configuration: PayScheduleConfiguration,
        calendar inputCalendar: Calendar = .current
    ) throws -> Date {
        try nextOccurrence(onOrAfter: referenceDate, configuration: configuration, calendar: inputCalendar).adjustedDate
    }

    public static func nextOccurrence(
        onOrAfter referenceDate: Date,
        configuration: PayScheduleConfiguration,
        calendar inputCalendar: Calendar = .current
    ) throws -> PaydayOccurrence {
        var calendar = inputCalendar
        if calendar.timeZone.identifier.isEmpty {
            calendar.timeZone = .current
        }
        let reference = calendar.startOfDay(for: referenceDate)

        let nominal: Date
        switch configuration.type {
        case .weekly:
            nominal = try intervalPayday(onOrAfter: reference, anchor: configuration.anchorPayday, intervalDays: 7, calendar: calendar)
        case .biweekly:
            nominal = try intervalPayday(onOrAfter: reference, anchor: configuration.anchorPayday, intervalDays: 14, calendar: calendar)
        case .monthly:
            guard let rule = configuration.monthlyRule else { throw PayScheduleError.missingRule }
            nominal = try nextMonthlyDate(onOrAfter: reference, rule: rule, calendar: calendar)
        case .semiMonthly:
            guard let first = configuration.semiMonthlyFirstRule, let second = configuration.semiMonthlySecondRule else { throw PayScheduleError.missingRule }
            try validateSemiMonthlyRules(first, second)
            nominal = try nextSemiMonthlyDate(onOrAfter: reference, first: first, second: second, calendar: calendar)
        case .irregular:
            guard let manual = configuration.manualNextPayday else { throw PayScheduleError.missingManualPayday }
            let normalized = calendar.startOfDay(for: manual)
            guard normalized >= reference else { throw PayScheduleError.missingManualPayday }
            nominal = normalized
        }

        let adjusted = applyWeekendAdjustment(to: nominal, adjustment: configuration.weekendAdjustment, calendar: calendar)

        // A previous-weekday adjustment can move a nominal weekend payday
        // before the requested reference date. In that case, that paycheck
        // has already happened, so advance to the next nominal occurrence.
        if adjusted < reference {
            guard let nextReference = calendar.date(byAdding: .day, value: 1, to: nominal) else {
                throw PayScheduleError.unableToGenerate
            }
            return try nextOccurrence(
                onOrAfter: nextReference,
                configuration: configuration,
                calendar: calendar
            )
        }

        return PaydayOccurrence(nominalDate: nominal, adjustedDate: adjusted)
    }

    /// Returns the following nominal occurrence after a completed payday.
    /// Weekend adjustment is applied only to the returned display/payment date; the recurrence anchor never drifts.
    public static func paydayAfterCompletedCycle(
        completedNominalPayday: Date,
        configuration: PayScheduleConfiguration,
        calendar: Calendar = .current
    ) throws -> Date {
        let completed = calendar.startOfDay(for: completedNominalPayday)
        let reference = calendar.date(byAdding: .day, value: 1, to: completed) ?? completed

        var nextConfiguration = configuration
        if configuration.type == .irregular {
            guard let manual = configuration.manualNextPayday,
                  calendar.startOfDay(for: manual) > completed else {
                throw PayScheduleError.missingManualPayday
            }
            nextConfiguration.manualNextPayday = manual
        }
        return try nextPayday(onOrAfter: reference, configuration: nextConfiguration, calendar: calendar)
    }

    public static func date(
        inMonthContaining monthDate: Date,
        rule: DayRule,
        calendar: Calendar = .current
    ) throws -> Date {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            throw PayScheduleError.unableToGenerate
        }
        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)
        let day: Int
        switch rule {
        case .lastDay:
            day = range.count
        case .fixed(let requested):
            guard (1...31).contains(requested) else { throw PayScheduleError.invalidDayRule }
            day = min(requested, range.count)
        }
        guard let result = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            throw PayScheduleError.unableToGenerate
        }
        return calendar.startOfDay(for: result)
    }

    public static func applyWeekendAdjustment(
        to nominal: Date,
        adjustment: WeekendAdjustment,
        calendar: Calendar = .current
    ) -> Date {
        guard adjustment != .none else { return calendar.startOfDay(for: nominal) }
        var result = calendar.startOfDay(for: nominal)
        let weekday = calendar.component(.weekday, from: result)
        guard weekday == 1 || weekday == 7 else { return result }

        switch adjustment {
        case .none:
            return result
        case .previousWeekday:
            let delta = weekday == 7 ? -1 : -2
            result = calendar.date(byAdding: .day, value: delta, to: result) ?? result
        case .nextWeekday:
            let delta = weekday == 7 ? 2 : 1
            result = calendar.date(byAdding: .day, value: delta, to: result) ?? result
        }
        return result
    }


    private static func validateSemiMonthlyRules(_ first: DayRule, _ second: DayRule) throws {
        guard first != second else { throw PayScheduleError.invalidDayRule }

        func resolvedDay(_ rule: DayRule, monthLength: Int) throws -> Int {
            switch rule {
            case .lastDay:
                return monthLength
            case .fixed(let requested):
                guard (1...31).contains(requested) else { throw PayScheduleError.invalidDayRule }
                return min(requested, monthLength)
            }
        }

        // A twice-monthly schedule must remain two distinct paydays even in
        // February and in 30/31-day months. Rules such as 30th + 31st would
        // otherwise collapse to a single Feb 28/29 occurrence.
        for monthLength in [28, 29, 30, 31] {
            guard try resolvedDay(first, monthLength: monthLength) != resolvedDay(second, monthLength: monthLength) else {
                throw PayScheduleError.invalidDayRule
            }
        }
    }

    private static func intervalPayday(
        onOrAfter reference: Date,
        anchor: Date?,
        intervalDays: Int,
        calendar: Calendar
    ) throws -> Date {
        guard let anchor else { throw PayScheduleError.missingAnchor }
        let normalizedAnchor = calendar.startOfDay(for: anchor)
        if reference <= normalizedAnchor { return normalizedAnchor }

        let elapsed = calendar.dateComponents([.day], from: normalizedAnchor, to: reference).day ?? 0
        let intervals = (elapsed + intervalDays - 1) / intervalDays
        guard let result = calendar.date(byAdding: .day, value: intervals * intervalDays, to: normalizedAnchor) else {
            throw PayScheduleError.unableToGenerate
        }
        return result
    }

    private static func nextMonthlyDate(
        onOrAfter reference: Date,
        rule: DayRule,
        calendar: Calendar
    ) throws -> Date {
        let currentCandidate = try date(inMonthContaining: reference, rule: rule, calendar: calendar)
        if currentCandidate >= reference { return currentCandidate }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: reference) else {
            throw PayScheduleError.unableToGenerate
        }
        return try date(inMonthContaining: nextMonth, rule: rule, calendar: calendar)
    }

    private static func nextSemiMonthlyDate(
        onOrAfter reference: Date,
        first: DayRule,
        second: DayRule,
        calendar: Calendar
    ) throws -> Date {
        let candidates = try [
            date(inMonthContaining: reference, rule: first, calendar: calendar),
            date(inMonthContaining: reference, rule: second, calendar: calendar)
        ].sorted()
        if let candidate = candidates.first(where: { $0 >= reference }) {
            return candidate
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: reference) else {
            throw PayScheduleError.unableToGenerate
        }
        return try [
            date(inMonthContaining: nextMonth, rule: first, calendar: calendar),
            date(inMonthContaining: nextMonth, rule: second, calendar: calendar)
        ].min() ?? { throw PayScheduleError.unableToGenerate }()
    }
}
