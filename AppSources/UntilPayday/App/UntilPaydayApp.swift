import SwiftUI
import SwiftData

@main
struct UntilPaydayApp: App {
    @State private var router = AppRouter()

    private var modelContainer: ModelContainer = {
        let schema = Schema([
            AppSettingsModel.self,
            PayCycle.self,
            BudgetTransaction.self,
            BillTemplate.self,
            BillOccurrence.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { router.handle($0) }
        }
        .modelContainer(modelContainer)
    }
}
