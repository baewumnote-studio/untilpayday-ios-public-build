import Foundation
import UntilPaydayCore

struct CycleBudgetViewModel: Equatable {
    let snapshot: BudgetSnapshot
    let spentTodayMinor: Int64
    let totalSpentMinor: Int64
    let extraIncomeMinor: Int64
    let pendingBillsMinor: Int64
    let pendingBills: [BillOccurrence]
}

enum BudgetSnapshotFactory {
    static func make(
        cycle: PayCycle,
        transactions: [BudgetTransaction],
        bills: [BillOccurrence],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CycleBudgetViewModel {
        let cycleTransactions = transactions.filter { $0.cycleID == cycle.id }
        let expenses = cycleTransactions.filter { $0.type == .expense }
        let extraIncome = cycleTransactions.filter { $0.type == .extraIncome }

        let expenseSpent = MinorUnitMath.sum(expenses.map(\.amountMinor))
        let extraIncomeTotal = MinorUnitMath.sum(extraIncome.map(\.amountMinor))

        let cutoff = calendar.startOfDay(for: cycle.endDate)
        let pending = bills
            .filter { occurrence in
                occurrence.status == .pending && calendar.startOfDay(for: occurrence.dueDate) < cutoff
            }
            .sorted { $0.dueDate < $1.dueDate }
        let pendingReserve = MinorUnitMath.sum(pending.map(\.plannedAmountMinor))

        let todayFlexibleSpent = expenses
            .filter { $0.linkedBillOccurrenceID == nil && calendar.isDate($0.transactionDate, inSameDayAs: now) }
            .map(\.amountMinor)
            .reduce(Int64(0), MinorUnitMath.adding)

        // The Safe Today card's “Spent today” metric is flexible spending only.
        // A linked bill payment was already reserved before payment, so including it here
        // would make the visible pace metric contradict the Safe Today calculation.
        let spentToday = todayFlexibleSpent

        let baseFunds = MinorUnitMath.adding(
            MinorUnitMath.adding(cycle.incomeMinor, cycle.rolloverMinor),
            extraIncomeTotal
        )
        let days = PayScheduleEngine.daysRemaining(from: now, to: cycle.endDate, calendar: calendar)
        let snapshot = BudgetEngine.calculate(.init(
            baseFundsMinor: baseFunds,
            expenseSpentMinor: expenseSpent,
            pendingBillReserveMinor: pendingReserve,
            savingsReserveMinor: cycle.savingsReserveMinor,
            todayFlexibleSpentMinor: todayFlexibleSpent,
            daysRemaining: days
        ))

        return CycleBudgetViewModel(
            snapshot: snapshot,
            spentTodayMinor: spentToday,
            totalSpentMinor: expenseSpent,
            extraIncomeMinor: extraIncomeTotal,
            pendingBillsMinor: pendingReserve,
            pendingBills: pending
        )
    }
}
