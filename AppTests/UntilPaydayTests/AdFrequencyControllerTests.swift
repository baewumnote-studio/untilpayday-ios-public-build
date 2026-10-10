import XCTest
@testable import UntilPayday

final class AdFrequencyControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AdFrequencyControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testHistoryBecomesEligibleOnFourthMeaningfulUse() {
        let controller = AdFrequencyController(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertFalse(controller.mayShow(for: .historyExit, now: now))
        XCTAssertFalse(controller.mayShow(for: .historyExit, now: now))
        XCTAssertFalse(controller.mayShow(for: .historyExit, now: now))
        XCTAssertTrue(controller.mayShow(for: .historyExit, now: now))
    }

    func testTwentyFourHourCooldownBlocksOtherwiseEligibleTrigger() {
        let controller = AdFrequencyController(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        controller.recordShown(now: now)

        XCTAssertFalse(
            controller.mayShow(
                for: .newPayCycle,
                now: now.addingTimeInterval(23 * 60 * 60)
            )
        )

        XCTAssertTrue(
            controller.mayShow(
                for: .newPayCycle,
                now: now.addingTimeInterval(24 * 60 * 60 + 1)
            )
        )
    }

    func testRollingSevenDayCapStopsFourthAd() {
        let controller = AdFrequencyController(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        controller.recordShown(now: now.addingTimeInterval(-6 * 86_400))
        controller.recordShown(now: now.addingTimeInterval(-4 * 86_400))
        controller.recordShown(now: now.addingTimeInterval(-2 * 86_400))

        XCTAssertFalse(controller.mayShow(for: .newPayCycle, now: now))
    }

    func testOldAdsFallOutsideSevenDayCap() {
        let controller = AdFrequencyController(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        controller.recordShown(now: now.addingTimeInterval(-8 * 86_400))
        controller.recordShown(now: now.addingTimeInterval(-9 * 86_400))
        controller.recordShown(now: now.addingTimeInterval(-10 * 86_400))

        XCTAssertTrue(controller.mayShow(for: .newPayCycle, now: now))
    }
}
