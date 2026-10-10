import Foundation

enum AdTrigger {
    case newPayCycle
    case historyExit
}

final class AdFrequencyController {
    private let defaults: UserDefaults
    private let lastShownKey = "ads.lastShown"
    private let shownDatesKey = "ads.shownDates"
    private let historyCountKey = "ads.historyEligibleCount"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func mayShow(for trigger: AdTrigger, now: Date = .now) -> Bool {
        switch trigger {
        case .newPayCycle:
            break
        case .historyExit:
            let next = defaults.integer(forKey: historyCountKey) + 1
            defaults.set(next, forKey: historyCountKey)
            guard next % 4 == 0 else { return false }
        }

        if let last = defaults.object(forKey: lastShownKey) as? Date,
           now.timeIntervalSince(last) < 24 * 60 * 60 {
            return false
        }
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = shownDates().filter { $0 >= sevenDaysAgo }
        return recent.count < 3
    }

    func recordShown(now: Date = .now) {
        defaults.set(now, forKey: lastShownKey)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        var recent = shownDates().filter { $0 >= sevenDaysAgo }
        recent.append(now)
        defaults.set(recent, forKey: shownDatesKey)
    }

    private func shownDates() -> [Date] {
        defaults.array(forKey: shownDatesKey) as? [Date] ?? []
    }
}
