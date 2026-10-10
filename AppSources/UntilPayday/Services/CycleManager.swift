import Foundation
import SwiftData
import UntilPaydayCore

@MainActor
enum CycleManager {
    static func createInitialCycle(
        settings: AppSettingsModel,
        availableFundsMinor: Int64,
        nextPayday: Date,
        savingsMinor: Int64,
        isPartial: Bool,
        completeOnboarding: Bool = true,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> PayCycle {
        guard availableFundsMinor >= 0, savingsMinor >= 0 else {
            throw CycleError.invalidMoneyAmount
        }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: nextPayday)
        guard end > start else { throw CycleError.paydayMustBeFuture }

        configureScheduleAnchor(settings: settings, nextPayday: end, calendar: calendar)
        if !isPartial {
            settings.defaultPayAmountMinor = availableFundsMinor
        }
        settings.defaultSavingsMinor = savingsMinor
        settings.onboardingCompleted = completeOnboarding
        settings.updatedAt = .now

        let cycle = PayCycle(
            startDate: start,
            endDate: end,
            nominalEndDate: end,
            incomeMinor: availableFundsMinor,
            savingsReserveMinor: savingsMinor,
            currencyCode: settings.currencyCode,
            isPartialCycle: isPartial
        )
        context.insert(cycle)
        try context.save()
        return cycle
    }

    static func startNextCycle(
        from oldCycle: PayCycle,
        settings: AppSettingsModel,
        incomeMinor: Int64,
        savingsMinor: Int64,
        rolloverMinor: Int64,
        irregularNextPayday: Date? = nil,
        templates: [BillTemplate],
        existingOccurrences: [BillOccurrence],
        transactions: [BudgetTransaction],
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> PayCycle {
        guard incomeMinor >= 0, savingsMinor >= 0 else {
            throw CycleError.invalidMoneyAmount
        }
        let start = calendar.startOfDay(for: oldCycle.endDate)
        var configuration = settings.scheduleConfiguration
        if settings.scheduleType == .irregular {
            configuration.manualNextPayday = irregularNextPayday
            settings.manualNextPayday = irregularNextPayday
        }

        let reference = calendar.date(byAdding: .day, value: 1, to: oldCycle.nominalEndDate) ?? start
        let nextOccurrence = try PayScheduleEngine.nextOccurrence(
            onOrAfter: reference,
            configuration: configuration,
            calendar: calendar
        )
        let nextEnd = nextOccurrence.adjustedDate

        let closing = BudgetSnapshotFactory.make(
            cycle: oldCycle,
            transactions: transactions,
            bills: existingOccurrences,
            now: oldCycle.endDate
        )
        oldCycle.closedLeftMinor = closing.snapshot.leftUntilPaydayMinor
        oldCycle.closedTotalSpentMinor = closing.totalSpentMinor
        oldCycle.closedBillsReservedMinor = closing.pendingBillsMinor
        oldCycle.isClosed = true
        oldCycle.closedAt = .now

        let next = PayCycle(
            startDate: start,
            endDate: nextEnd,
            nominalEndDate: nextOccurrence.nominalDate,
            incomeMinor: incomeMinor,
            rolloverMinor: rolloverMinor,
            savingsReserveMinor: savingsMinor,
            currencyCode: settings.currencyCode
        )
        context.insert(next)
        settings.defaultPayAmountMinor = incomeMinor
        settings.defaultSavingsMinor = savingsMinor
        settings.updatedAt = .now
        try context.save()

        BillOccurrenceEngine.ensureOccurrences(
            for: next,
            templates: templates,
            existing: existingOccurrences,
            context: context,
            calendar: calendar
        )
        return next
    }

    static func startFreshPartialCycle(
        settings: AppSettingsModel,
        currentFundsMinor: Int64,
        nextPayday: Date,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> PayCycle {
        guard currentFundsMinor >= 0 else { throw CycleError.invalidMoneyAmount }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: nextPayday)
        guard end > start else { throw CycleError.paydayMustBeFuture }
        let cycle = PayCycle(
            startDate: start,
            endDate: end,
            nominalEndDate: end,
            incomeMinor: currentFundsMinor,
            savingsReserveMinor: settings.defaultSavingsMinor,
            currencyCode: settings.currencyCode,
            isPartialCycle: true
        )
        context.insert(cycle)
        try context.save()
        return cycle
    }

    static func nextUpcomingPayday(
        settings: AppSettingsModel,
        after reference: Date,
        irregularNextPayday: Date? = nil,
        calendar: Calendar = .current
    ) throws -> Date {
        var configuration = settings.scheduleConfiguration
        if settings.scheduleType == .irregular { configuration.manualNextPayday = irregularNextPayday ?? settings.manualNextPayday }
        return try PayScheduleEngine.nextPayday(onOrAfter: calendar.startOfDay(for: reference), configuration: configuration, calendar: calendar)
    }

    static func closeAndStartFreshAfterGap(
        oldCycle: PayCycle,
        settings: AppSettingsModel,
        currentFundsMinor: Int64,
        nextPayday: Date,
        savingsMinor: Int64,
        transactions: [BudgetTransaction],
        bills: [BillOccurrence],
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> PayCycle {
        guard currentFundsMinor >= 0, savingsMinor >= 0 else {
            throw CycleError.invalidMoneyAmount
        }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: nextPayday)
        guard end > start else { throw CycleError.paydayMustBeFuture }
        let closing = BudgetSnapshotFactory.make(cycle: oldCycle, transactions: transactions, bills: bills, now: oldCycle.endDate)
        oldCycle.closedLeftMinor = closing.snapshot.leftUntilPaydayMinor
        oldCycle.closedTotalSpentMinor = closing.totalSpentMinor
        oldCycle.closedBillsReservedMinor = closing.pendingBillsMinor
        oldCycle.isClosed = true
        oldCycle.closedAt = .now
        let fresh = PayCycle(
            startDate: start,
            endDate: end,
            nominalEndDate: end,
            incomeMinor: currentFundsMinor,
            savingsReserveMinor: savingsMinor,
            currencyCode: settings.currencyCode,
            isPartialCycle: true
        )
        context.insert(fresh)
        try context.save()
        return fresh
    }

    static func markBillPaid(
        _ bill: BillOccurrence,
        actualAmountMinor: Int64,
        cycle: PayCycle,
        context: ModelContext,
        date: Date = .now
    ) throws {
        guard bill.status == .pending else { return }
        guard actualAmountMinor >= 0 else { throw CycleError.invalidMoneyAmount }
        let transaction = BudgetTransaction(
            cycleID: cycle.id,
            type: .expense,
            amountMinor: actualAmountMinor,
            category: .bills,
            note: bill.nameSnapshot,
            transactionDate: date,
            linkedBillOccurrenceID: bill.id
        )
        context.insert(transaction)
        bill.status = .paid
        bill.actualAmountMinor = actualAmountMinor
        bill.linkedTransactionID = transaction.id
        bill.paidAt = date
        try context.save()
    }

    static func skipBill(_ bill: BillOccurrence, context: ModelContext) throws {
        bill.status = .skipped
        try context.save()
    }

    private static func configureScheduleAnchor(
        settings: AppSettingsModel,
        nextPayday: Date,
        calendar: Calendar
    ) {
        switch settings.scheduleType {
        case .weekly, .biweekly:
            settings.anchorPayday = calendar.startOfDay(for: nextPayday)
            settings.manualNextPayday = nil

        case .irregular:
            settings.manualNextPayday = calendar.startOfDay(for: nextPayday)

        case .monthly, .semiMonthly:
            // These schedules are defined by explicit day rules. Do not infer or
            // mutate those rules from a single upcoming payday; doing so would
            // confuse fixed day 30/31 with a true "last day" schedule.
            settings.manualNextPayday = nil
        }
    }


}

enum CycleError: LocalizedError {
    case paydayMustBeFuture
    case invalidMoneyAmount

    var errorDescription: String? {
        switch self {
        case .paydayMustBeFuture: String(localized: "Choose a payday after today.")
        case .invalidMoneyAmount: String(localized: "Enter a valid non-negative amount.")
        }
    }
}
