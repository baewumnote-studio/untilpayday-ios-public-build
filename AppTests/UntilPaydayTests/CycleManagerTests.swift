import XCTest
import SwiftData
@testable import UntilPayday

@MainActor
final class CycleManagerTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let schema = Schema([
            AppSettingsModel.self,
            PayCycle.self,
            BudgetTransaction.self,
            BillTemplate.self,
            BillOccurrence.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        )
    }

    func testPartialInitialCycleDoesNotOverwriteDefaultPaycheck() throws {
        let container = try container()
        let context = container.mainContext
        let settings = AppSettingsModel(
            currencyCode: "USD",
            defaultPayAmountMinor: 280_000
        )
        context.insert(settings)

        let nextPayday = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        _ = try CycleManager.createInitialCycle(
            settings: settings,
            availableFundsMinor: 75_000,
            nextPayday: nextPayday,
            savingsMinor: 10_000,
            isPartial: true,
            context: context
        )

        XCTAssertEqual(settings.defaultPayAmountMinor, 280_000)
    }

    func testFullInitialCycleStoresDefaultPaycheck() throws {
        let container = try container()
        let context = container.mainContext
        let settings = AppSettingsModel(currencyCode: "USD")
        context.insert(settings)

        let nextPayday = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        _ = try CycleManager.createInitialCycle(
            settings: settings,
            availableFundsMinor: 280_000,
            nextPayday: nextPayday,
            savingsMinor: 30_000,
            isPartial: false,
            context: context
        )

        XCTAssertEqual(settings.defaultPayAmountMinor, 280_000)
        XCTAssertEqual(settings.defaultSavingsMinor, 30_000)
    }
}

extension CycleManagerTests {
    func testMonthlyFixedDayIsNotReinterpretedAsLastDayDuringInitialCycle() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let container = try container()
        let context = container.mainContext
        let settings = AppSettingsModel(
            currencyCode: "USD",
            scheduleType: .monthly,
            monthlyDay: 30,
            monthlyUseLastDay: false
        )
        context.insert(settings)

        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let september30 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!

        _ = try CycleManager.createInitialCycle(
            settings: settings,
            availableFundsMinor: 280_000,
            nextPayday: september30,
            savingsMinor: 30_000,
            isPartial: false,
            context: context,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(settings.monthlyDay, 30)
        XCTAssertFalse(settings.monthlyUseLastDay)
    }

    func testNegativeInitialMoneyIsRejected() throws {
        let container = try container()
        let context = container.mainContext
        let settings = AppSettingsModel(currencyCode: "USD")
        context.insert(settings)

        let nextPayday = Calendar.current.date(byAdding: .day, value: 14, to: .now)!

        XCTAssertThrowsError(
            try CycleManager.createInitialCycle(
                settings: settings,
                availableFundsMinor: -1,
                nextPayday: nextPayday,
                savingsMinor: 0,
                isPartial: false,
                context: context
            )
        )
    }
}
