import Foundation

struct SharedWidgetBudgetValues: Equatable {
    let leftMinor: Int64
    let safeMinor: Int64
    let shortByMinor: Int64
    let daysRemaining: Int
    let isPayday: Bool
}

enum SharedMinorUnitMath {
    static func adding(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard result.overflow else { return result.partialValue }
        return rhs >= 0 ? .max : .min
    }

    static func subtracting(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.subtractingReportingOverflow(rhs)
        guard result.overflow else { return result.partialValue }
        return rhs >= 0 ? .min : .max
    }

    static func absolute(_ value: Int64) -> Int64 {
        value == .min ? .max : Swift.abs(value)
    }
}

enum WidgetBudgetCalculator {
    static func calculate(
        snapshot: SharedWidgetSnapshot,
        at date: Date,
        calendar: Calendar = .current
    ) -> SharedWidgetBudgetValues {
        let today = calendar.startOfDay(for: date)
        let generatedDay = calendar.startOfDay(for: snapshot.generatedAt)
        let payday = calendar.startOfDay(for: snapshot.nextPayday)
        let days = calendar.dateComponents([.day], from: today, to: payday).day ?? 0
        let shortBy = snapshot.freeNowMinor < 0
            ? SharedMinorUnitMath.absolute(snapshot.freeNowMinor)
            : 0

        guard days > 0 else {
            return SharedWidgetBudgetValues(
                leftMinor: max(0, snapshot.freeNowMinor),
                safeMinor: 0,
                shortByMinor: shortBy,
                daysRemaining: 0,
                isPayday: true
            )
        }

        guard snapshot.freeNowMinor > 0 else {
            return SharedWidgetBudgetValues(
                leftMinor: 0,
                safeMinor: 0,
                shortByMinor: shortBy,
                daysRemaining: days,
                isPayday: false
            )
        }

        let sameDay = calendar.isDate(today, inSameDayAs: generatedDay)
        let todaySpent = sameDay ? max(0, snapshot.todayFlexibleSpentMinor) : 0
        let reconstructedPool = sameDay
            ? max(0, SharedMinorUnitMath.adding(snapshot.freeNowMinor, todaySpent))
            : max(0, snapshot.freeNowMinor)
        let dailyPlan = reconstructedPool / Int64(days)
        let safe = max(0, SharedMinorUnitMath.subtracting(dailyPlan, todaySpent))

        return SharedWidgetBudgetValues(
            leftMinor: snapshot.freeNowMinor,
            safeMinor: safe,
            shortByMinor: 0,
            daysRemaining: days,
            isPayday: false
        )
    }
}
