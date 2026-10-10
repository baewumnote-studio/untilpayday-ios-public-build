import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsModel]

    var body: some View {
        Group {
            if let settings = settingsRecords.first, settings.onboardingCompleted {
                MainTabView(settings: settings)
            } else {
                OnboardingView()
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .task {
            #if DEBUG
            UITestBootstrap.applyIfNeeded(context: modelContext)
            #endif
            ensureSettingsExists()
        }
    }

    private func ensureSettingsExists() {
        let descriptor = FetchDescriptor<AppSettingsModel>()
        guard (try? modelContext.fetch(descriptor).isEmpty) == true else { return }
        modelContext.insert(AppSettingsModel())
        try? modelContext.save()
    }
}
