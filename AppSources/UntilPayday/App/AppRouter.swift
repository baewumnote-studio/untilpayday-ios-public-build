import Foundation
import Observation

@Observable
final class AppRouter {
    enum Tab: Hashable {
        case today
        case plan
        case history
        case settings
    }

    var selectedTab: Tab = .today
    var showAddExpense = false
    var showAddIncome = false

    private(set) var historyWasMeaningfullyUsed = false

    func markHistoryMeaningfulUse() {
        historyWasMeaningfullyUsed = true
    }

    func consumeHistoryMeaningfulUse() -> Bool {
        let value = historyWasMeaningfullyUsed
        historyWasMeaningfullyUsed = false
        return value
    }

    func handle(_ url: URL) {
        guard url.scheme == AppBrand.deepLinkScheme else { return }
        selectedTab = .today

        switch url.host {
        case "add-expense":
            showAddExpense = true
        case "today":
            break
        default:
            break
        }
    }
}
