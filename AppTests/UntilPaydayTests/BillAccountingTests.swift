import XCTest
import SwiftData
@testable import UntilPayday

@MainActor
final class BillAccountingTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let schema = Schema([AppSettingsModel.self, PayCycle.self, BudgetTransaction.self, BillTemplate.self, BillOccurrence.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }

    func testPayingReservedBillSameAmountDoesNotChangeLeft() throws {
        let container = try container()
        let context = container.mainContext
        let cycle = PayCycle(startDate: .now, endDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!, incomeMinor: 100_000, currencyCode: "USD")
        let bill = BillOccurrence(originalCycleID: cycle.id, nameSnapshot: "Electric", plannedAmountMinor: 10_000, currencyCode: "USD", dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!)
        context.insert(cycle); context.insert(bill); try context.save()

        let before = BudgetSnapshotFactory.make(cycle: cycle, transactions: [], bills: [bill])
        try CycleManager.markBillPaid(bill, actualAmountMinor: 10_000, cycle: cycle, context: context)
        let descriptor = FetchDescriptor<BudgetTransaction>()
        let txs = try context.fetch(descriptor)
        let after = BudgetSnapshotFactory.make(cycle: cycle, transactions: txs, bills: [bill])

        XCTAssertEqual(before.snapshot.leftUntilPaydayMinor, after.snapshot.leftUntilPaydayMinor)
        XCTAssertEqual(txs.first?.linkedBillOccurrenceID, bill.id)
    }

    func testBillDueExactlyOnPaydayIsNotReservedInCurrentCycle() {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 10, to: calendar.startOfDay(for: .now))!
        let cycle = PayCycle(startDate: calendar.startOfDay(for: .now), endDate: end, incomeMinor: 100_000, currencyCode: "USD")
        let bill = BillOccurrence(originalCycleID: cycle.id, nameSnapshot: "Next cycle bill", plannedAmountMinor: 25_000, currencyCode: "USD", dueDate: end)
        let vm = BudgetSnapshotFactory.make(cycle: cycle, transactions: [], bills: [bill])
        XCTAssertEqual(vm.pendingBillsMinor, 0)
        XCTAssertEqual(vm.snapshot.leftUntilPaydayMinor, 100_000)
    }

    func testOverduePendingBillRemainsReserved() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let cycle = PayCycle(startDate: start, endDate: calendar.date(byAdding: .day, value: 10, to: start)!, incomeMinor: 100_000, currencyCode: "USD")
        let overdue = BillOccurrence(originalCycleID: UUID(), nameSnapshot: "Overdue", plannedAmountMinor: 10_000, currencyCode: "USD", dueDate: calendar.date(byAdding: .day, value: -2, to: start)!)
        let vm = BudgetSnapshotFactory.make(cycle: cycle, transactions: [], bills: [overdue])
        XCTAssertEqual(vm.pendingBillsMinor, 10_000)
        XCTAssertEqual(vm.snapshot.leftUntilPaydayMinor, 90_000)
    }

    func testMonthlyBillOn31ClampsToFebruaryEnd() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let template = BillTemplate(name: "Rent", amountMinor: 100_000, currencyCode: "USD", recurrence: .monthly, anchorDate: anchor, dayOfMonth: 31)
        let start = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let dates = BillOccurrenceEngine.occurrenceDates(for: template, from: start, to: end, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: dates.first!), 28)
    }
}

extension BillAccountingTests {
    func testMonthlyLastDayTemplateFromFebruaryContinuesToMarch31() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let anchor = calendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!
        let template = BillTemplate(
            name: "Month end",
            amountMinor: 10_000,
            currencyCode: "USD",
            recurrence: .monthly,
            anchorDate: anchor,
            dayOfMonth: 28,
            useLastDay: true
        )
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!

        let dates = BillOccurrenceEngine.occurrenceDates(
            for: template,
            from: start,
            to: end,
            calendar: calendar
        )

        XCTAssertEqual(dates.count, 1)
        XCTAssertEqual(calendar.component(.day, from: dates[0]), 31)
    }
}

extension BillAccountingTests {
    func testPayingReservedBillForMoreChangesLeftOnlyByDifference() throws {
        let container = try container()
        let context = container.mainContext
        let end = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let cycle = PayCycle(startDate: .now, endDate: end, incomeMinor: 100_000, currencyCode: "USD")
        let bill = BillOccurrence(
            originalCycleID: cycle.id,
            nameSnapshot: "Electric",
            plannedAmountMinor: 10_000,
            currencyCode: "USD",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        )
        context.insert(cycle)
        context.insert(bill)
        try context.save()

        let before = BudgetSnapshotFactory.make(cycle: cycle, transactions: [], bills: [bill])
        try CycleManager.markBillPaid(bill, actualAmountMinor: 12_000, cycle: cycle, context: context)
        let txs = try context.fetch(FetchDescriptor<BudgetTransaction>())
        let after = BudgetSnapshotFactory.make(cycle: cycle, transactions: txs, bills: [bill])

        XCTAssertEqual(before.snapshot.leftUntilPaydayMinor - after.snapshot.leftUntilPaydayMinor, 2_000)
        XCTAssertEqual(after.spentTodayMinor, 0, "Reserved bill payment must not count as flexible daily spend")
    }

    func testPayingReservedBillForLessRestoresDifference() throws {
        let container = try container()
        let context = container.mainContext
        let end = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let cycle = PayCycle(startDate: .now, endDate: end, incomeMinor: 100_000, currencyCode: "USD")
        let bill = BillOccurrence(
            originalCycleID: cycle.id,
            nameSnapshot: "Electric",
            plannedAmountMinor: 10_000,
            currencyCode: "USD",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        )
        context.insert(cycle)
        context.insert(bill)
        try context.save()

        let before = BudgetSnapshotFactory.make(cycle: cycle, transactions: [], bills: [bill])
        try CycleManager.markBillPaid(bill, actualAmountMinor: 8_000, cycle: cycle, context: context)
        let txs = try context.fetch(FetchDescriptor<BudgetTransaction>())
        let after = BudgetSnapshotFactory.make(cycle: cycle, transactions: txs, bills: [bill])

        XCTAssertEqual(after.snapshot.leftUntilPaydayMinor - before.snapshot.leftUntilPaydayMinor, 2_000)
    }
}
