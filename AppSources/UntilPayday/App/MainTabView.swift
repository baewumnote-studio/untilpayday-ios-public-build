import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    let settings: AppSettingsModel
    @StateObject private var consentManager = ConsentManager()

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            TodayView(settings: settings)
                .tag(AppRouter.Tab.today)
                .tabItem { Label("Today", systemImage: "house.fill") }

            PlanView(settings: settings)
                .tag(AppRouter.Tab.plan)
                .tabItem { Label("Plan", systemImage: "calendar.badge.checkmark") }

            HistoryView()
                .tag(AppRouter.Tab.history)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                SettingsView(settings: settings)
            }
            .tag(AppRouter.Tab.settings)
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(AppColor.accent)
        .onChange(of: router.selectedTab) { oldValue, newValue in
            if oldValue == .history,
               newValue != .history,
               router.consumeHistoryMeaningfulUse() {
                AdManager.shared.presentIfEligible(trigger: .historyExit)
            }
        }
        .task {
            await consentManager.refresh()
            await AdManager.shared.initializeAndPreload(canRequestAds: consentManager.canRequestAds)
        }
    }
}
