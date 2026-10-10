import Foundation
import UntilPaydayCore

enum TodayStateBuilder {
    static func make(
        cycle: PayCycle,
        budget: CycleBudgetViewModel,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TodayViewState {
        let days = PayScheduleEngine.daysRemaining(
            from: now,
            to: cycle.endDate,
            calendar: calendar
        )

        let upcoming = budget.pendingBills
            .prefix(3)
            .map { bill in
                let dueDay = calendar.startOfDay(for: bill.dueDate)
                let today = calendar.startOfDay(for: now)
                let delta = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
                return UpcomingBillRowState(
                    id: bill.id,
                    name: bill.nameSnapshot,
                    dueDate: bill.dueDate,
                    daysUntilDue: delta,
                    plannedAmountMinor: bill.plannedAmountMinor,
                    currencyCode: bill.currencyCode
                )
            }

        return TodayViewState(
            currencyCode: cycle.currencyCode,
            nextPayday: cycle.endDate,
            daysRemaining: max(0, days),
            leftUntilPaydayMinor: budget.snapshot.leftUntilPaydayMinor,
            safeTodayMinor: budget.snapshot.safeTodayRemainingMinor,
            todayFlexibleSpentMinor: budget.spentTodayMinor,
            dailyPaceMinor: budget.snapshot.safeTodayPlanMinor,
            overTodayPaceMinor: budget.snapshot.overTodayPaceMinor,
            shortByMinor: budget.snapshot.shortByMinor,
            upcomingBills: upcoming,
            isPaydayReady: budget.snapshot.state == .paydayTransition,
            previousCycleLeftoverMinor: budget.snapshot.leftUntilPaydayMinor
        )
    }
}
