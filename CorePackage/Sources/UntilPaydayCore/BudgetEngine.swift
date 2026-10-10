import Foundation

public enum BudgetEngine {
    public static func calculate(_ input: BudgetInput) -> BudgetSnapshot {
        var left = input.baseFundsMinor
        left = MinorUnitMath.subtracting(left, input.expenseSpentMinor)
        left = MinorUnitMath.subtracting(left, input.pendingBillReserveMinor)
        left = MinorUnitMath.subtracting(left, input.savingsReserveMinor)

        let shortBy = left < 0 ? MinorUnitMath.absolute(left) : 0

        guard input.daysRemaining > 0 else {
            return BudgetSnapshot(
                state: .paydayTransition,
                leftUntilPaydayMinor: left,
                safeTodayPlanMinor: 0,
                safeTodayRemainingMinor: 0,
                shortByMinor: shortBy,
                overTodayPaceMinor: 0
            )
        }

        guard left > 0 else {
            return BudgetSnapshot(
                state: .active,
                leftUntilPaydayMinor: left,
                safeTodayPlanMinor: 0,
                safeTodayRemainingMinor: 0,
                shortByMinor: shortBy,
                overTodayPaceMinor: max(0, input.todayFlexibleSpentMinor)
            )
        }

        // Flexible spending made today has already been subtracted from `left`.
        // Add it back to reconstruct the flexible pool that existed at the start of today.
        let reconstructed = MinorUnitMath.adding(left, max(0, input.todayFlexibleSpentMinor))
        let startOfTodayFlexiblePool = max(0, reconstructed)
        let dailyPlan = startOfTodayFlexiblePool / Int64(input.daysRemaining)
        let remainingToday = max(
            0,
            MinorUnitMath.subtracting(dailyPlan, max(0, input.todayFlexibleSpentMinor))
        )
        let overPace = max(
            0,
            MinorUnitMath.subtracting(max(0, input.todayFlexibleSpentMinor), dailyPlan)
        )

        return BudgetSnapshot(
            state: .active,
            leftUntilPaydayMinor: left,
            safeTodayPlanMinor: dailyPlan,
            safeTodayRemainingMinor: remainingToday,
            shortByMinor: shortBy,
            overTodayPaceMinor: overPace
        )
    }
}
