import Foundation
import SwiftData

#if DEBUG
@MainActor
enum UITestBootstrap {
    static func applyIfNeeded(context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-ui-testing-reset") {
            reset(context: context)
            return
        }

        if arguments.contains("-ui-testing-payday") {
            reset(context: context)
            seedActive(context: context, paydayOffsetDays: 0)
            return
        }

        if arguments.contains("-ui-testing-history") {
            reset(context: context)
            seedHistory(context: context)
            return
        }

        if arguments.contains("-ui-testing-visual-master") {
            reset(context: context)
            seedVisualMaster(context: context)
            return
        }

        if arguments.contains("-ui-testing-seeded") {
            reset(context: context)
            seedActive(context: context, paydayOffsetDays: 13)
        }
    }

    private static func reset(context: ModelContext) {
        if let items = try? context.fetch(FetchDescriptor<BudgetTransaction>()) {
            items.forEach(context.delete)
        }
        if let items = try? context.fetch(FetchDescriptor<BillOccurrence>()) {
            items.forEach(context.delete)
        }
        if let items = try? context.fetch(FetchDescriptor<BillTemplate>()) {
            items.forEach(context.delete)
        }
        if let items = try? context.fetch(FetchDescriptor<PayCycle>()) {
            items.forEach(context.delete)
        }
        if let items = try? context.fetch(FetchDescriptor<AppSettingsModel>()) {
            items.forEach(context.delete)
        }
        try? context.save()
    }

    private static func seedActive(context: ModelContext, paydayOffsetDays: Int) {
        let today = Calendar.current.startOfDay(for: .now)
        guard let payday = Calendar.current.date(
            byAdding: .day,
            value: paydayOffsetDays,
            to: today
        ) else { return }

        let settings = AppSettingsModel(
            currencyCode: "USD",
            defaultPayAmountMinor: 280_000,
            defaultSavingsMinor: 30_000,
            onboardingCompleted: true,
            paydayNotificationsEnabled: false
        )
        settings.anchorPayday = payday

        let cycle = PayCycle(
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
            endDate: payday,
            nominalEndDate: payday,
            incomeMinor: 280_000,
            savingsReserveMinor: 30_000,
            currencyCode: "USD"
        )

        context.insert(settings)
        context.insert(cycle)

        if paydayOffsetDays > 0 {
            context.insert(BillOccurrence(
                originalCycleID: cycle.id,
                nameSnapshot: "Electricity",
                plannedAmountMinor: 120_000,
                currencyCode: "USD",
                dueDate: Calendar.current.date(
                    byAdding: .day,
                    value: min(4, max(1, paydayOffsetDays - 1)),
                    to: today
                ) ?? today
            ))
        }

        try? context.save()
    }


    /// Deterministic, internally consistent sample data for App Store screenshots
    /// and visual-regression checks. The generated promotional reference contains
    /// illustrative numbers; this seed follows the real Safe Today math instead.
    ///
    /// Result at launch:
    /// - 13 days until payday
    /// - $1,252 left until payday
    /// - $52 Safe Today
    /// - $48 flexible spending today
    /// - $100 daily pace
    /// - $900 Rent already paid (and therefore not double-counted)
    /// - $300 of pending bills before payday
    private static func seedVisualMaster(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let payday = calendar.date(byAdding: .day, value: 13, to: today) else { return }

        let settings = AppSettingsModel(
            currencyCode: "USD",
            defaultPayAmountMinor: 280_000,
            defaultSavingsMinor: 30_000,
            onboardingCompleted: true,
            paydayNotificationsEnabled: false
        )
        settings.scheduleType = .biweekly
        settings.anchorPayday = payday

        let cycle = PayCycle(
            startDate: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            endDate: payday,
            nominalEndDate: payday,
            incomeMinor: 280_000,
            savingsReserveMinor: 30_000,
            currencyCode: "USD"
        )

        context.insert(settings)
        context.insert(cycle)

        let rentID = UUID()
        let rentTransactionID = UUID()
        let rent = BillOccurrence(
            id: rentID,
            originalCycleID: cycle.id,
            nameSnapshot: "Rent",
            plannedAmountMinor: 90_000,
            actualAmountMinor: 90_000,
            currencyCode: "USD",
            dueDate: today,
            status: .paid,
            linkedTransactionID: rentTransactionID,
            paidAt: today
        )
        context.insert(rent)
        context.insert(BudgetTransaction(
            id: rentTransactionID,
            cycleID: cycle.id,
            type: .expense,
            amountMinor: 90_000,
            category: .bills,
            note: "Rent",
            transactionDate: today,
            linkedBillOccurrenceID: rentID
        ))

        let pending: [(String, Int64, Int)] = [
            ("Electricity", 8_600, 3),
            ("Internet", 5_500, 5),
            ("Phone", 7_000, 8),
            ("Car Insurance", 8_900, 11)
        ]

        for (name, amount, offset) in pending {
            guard let due = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            context.insert(BillOccurrence(
                originalCycleID: cycle.id,
                nameSnapshot: name,
                plannedAmountMinor: amount,
                currencyCode: "USD",
                dueDate: due
            ))
        }

        // $48 flexible spend today. With $300 pending bills + $900 paid Rent +
        // $300 savings, this produces exactly $1,252 free now. Reconstructing
        // start-of-day flexible funds gives $1,300 / 13 = $100 daily pace,
        // therefore Safe Today is exactly $52.
        context.insert(BudgetTransaction(
            cycleID: cycle.id,
            type: .expense,
            amountMinor: 4_800,
            category: .food,
            note: "Groceries",
            transactionDate: today
        ))

        let recurring: [(String, Int64, Int)] = [
            ("Rent", 90_000, 1),
            ("Electricity", 8_600, 10),
            ("Internet", 5_500, 15),
            ("Phone", 7_000, 20)
        ]
        for (name, amount, day) in recurring {
            context.insert(BillTemplate(
                name: name,
                amountMinor: amount,
                currencyCode: "USD",
                recurrence: .monthly,
                dayOfMonth: day
            ))
        }

        try? context.save()
    }

    private static func seedHistory(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        guard
            let oldStart = Calendar.current.date(byAdding: .day, value: -28, to: today),
            let oldEnd = Calendar.current.date(byAdding: .day, value: -14, to: today),
            let nextPayday = Calendar.current.date(byAdding: .day, value: 14, to: today)
        else { return }

        let settings = AppSettingsModel(
            currencyCode: "USD",
            defaultPayAmountMinor: 280_000,
            defaultSavingsMinor: 30_000,
            onboardingCompleted: true,
            paydayNotificationsEnabled: false
        )
        settings.anchorPayday = nextPayday

        let closed = PayCycle(
            startDate: oldStart,
            endDate: oldEnd,
            incomeMinor: 280_000,
            savingsReserveMinor: 30_000,
            currencyCode: "USD",
            isClosed: true,
            closedLeftMinor: 14_200,
            closedTotalSpentMinor: 123_100,
            createdAt: oldStart,
            closedAt: oldEnd
        )

        let active = PayCycle(
            startDate: today,
            endDate: nextPayday,
            incomeMinor: 280_000,
            savingsReserveMinor: 30_000,
            currencyCode: "USD"
        )

        context.insert(settings)
        context.insert(closed)
        context.insert(active)

        context.insert(BudgetTransaction(
            cycleID: closed.id,
            type: .expense,
            amountMinor: 2_400,
            category: .food,
            note: "Lunch",
            transactionDate: Calendar.current.date(byAdding: .day, value: -20, to: today) ?? oldStart
        ))
        context.insert(BudgetTransaction(
            cycleID: closed.id,
            type: .expense,
            amountMinor: 1_800,
            category: .transport,
            note: "Train",
            transactionDate: Calendar.current.date(byAdding: .day, value: -19, to: today) ?? oldStart
        ))

        try? context.save()
    }
}
#endif
