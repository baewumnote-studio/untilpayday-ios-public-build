import SwiftUI
import SwiftData
import UserNotifications
import UntilPaydayCore

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var cycles: [PayCycle]
    @Query private var transactions: [BudgetTransaction]
    @Query private var bills: [BillOccurrence]
    @Query private var templates: [BillTemplate]

    let settings: AppSettingsModel

    @StateObject private var consent = ConsentManager()
    @State private var showReset = false
    @State private var scheduleError: String?

    var body: some View {
        Form {
            trustSummarySection
            payScheduleSection
            moneySection
            notificationSection
            privacySection
            aboutSection

            Section {
                Button("Reset all data", role: .destructive) {
                    showReset = true
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(AppColor.background)
        .task {
            await consent.refresh()
        }
        .alert(
            "Check the pay schedule",
            isPresented: Binding(
                get: { scheduleError != nil },
                set: { if !$0 { scheduleError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scheduleError ?? "")
        }
        .confirmationDialog(
            "Reset everything?",
            isPresented: $showReset,
            titleVisibility: .visible
        ) {
            Button("Delete all budget data", role: .destructive) {
                resetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var trustSummarySection: some View {
        Section {
            TrustSummaryCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var payScheduleSection: some View {
        Section("Pay schedule") {
            Picker(
                "Frequency",
                selection: Binding(
                    get: { settings.scheduleType },
                    set: { updateScheduleType($0) }
                )
            ) {
                ForEach(PayScheduleType.allCases) {
                    Text($0.title).tag($0)
                }
            }

            if settings.scheduleType == .monthly {
                Toggle(
                    "Use last day of month",
                    isOn: Binding(
                        get: { settings.monthlyUseLastDay },
                        set: {
                            settings.monthlyUseLastDay = $0
                            settings.updatedAt = .now
                            save()
                        }
                    )
                )

                if !settings.monthlyUseLastDay {
                    Stepper(
                        "Payday: day \(settings.monthlyDay)",
                        value: Binding(
                            get: { settings.monthlyDay },
                            set: {
                                settings.monthlyDay = $0
                                settings.updatedAt = .now
                                save()
                            }
                        ),
                        in: 1...31
                    )
                }
            }

            if settings.scheduleType == .semiMonthly {
                Picker("First payday", selection: semiMonthlyRuleBinding(first: true)) {
                    ForEach(1...31, id: \.self) {
                        Text("Day \($0)").tag($0)
                    }
                    Text("Last day").tag(99)
                }

                Picker("Second payday", selection: semiMonthlyRuleBinding(first: false)) {
                    ForEach(1...31, id: \.self) {
                        Text("Day \($0)").tag($0)
                    }
                    Text("Last day").tag(99)
                }
            }

            Picker(
                "Weekend payday",
                selection: Binding(
                    get: { settings.weekendAdjustment },
                    set: {
                        settings.weekendAdjustment = $0
                        save()
                    }
                )
            ) {
                ForEach(WeekendAdjustment.allCases) {
                    Text($0.title).tag($0)
                }
            }

            if let active = activeCycle {
                DatePicker(
                    "Next payday",
                    selection: Binding(
                        get: { active.endDate },
                        set: { newDate in
                            active.endDate = Calendar.current.startOfDay(for: newDate)
                            save()
                            schedule(active.endDate)
                        }
                    ),
                    displayedComponents: .date
                )
            }

            Text("Schedule changes affect future cycles. Editing Next payday changes the current cycle only and does not move the recurrence anchor.")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var moneySection: some View {
        Section("Money") {
            LabeledContent(
                "Currency",
                value: CurrencyMetadata.displayName(for: settings.currencyCode)
            )

            NavigationLink {
                DefaultAmountEditor(settings: settings, field: .paycheck)
            } label: {
                LabeledContent(
                    "Default paycheck",
                    value: MoneyFormatter.string(
                        minorUnits: settings.defaultPayAmountMinor,
                        currencyCode: settings.currencyCode
                    )
                )
            }

            NavigationLink {
                DefaultAmountEditor(settings: settings, field: .savings)
            } label: {
                LabeledContent(
                    "Default savings",
                    value: MoneyFormatter.string(
                        minorUnits: settings.defaultSavingsMinor,
                        currencyCode: settings.currencyCode
                    )
                )
            }

            Text("Currency is fixed for this budget so pay cycles and unpaid bills never mix currencies. Reset all data to choose a different currency. Amounts are never converted automatically.")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var notificationSection: some View {
        Section("Reminders") {
            Toggle(
                "Payday reminders",
                isOn: Binding(
                    get: { settings.paydayNotificationsEnabled },
                    set: { value in
                        settings.paydayNotificationsEnabled = value
                        settings.updatedAt = .now
                        save()

                        if value {
                            Task { @MainActor in
                                let granted = await NotificationManager.shared.requestAuthorization()
                                settings.paydayNotificationsEnabled = granted
                                settings.updatedAt = .now
                                save()

                                if granted, let active = activeCycle {
                                    schedule(active.endDate)
                                }
                            }
                        } else {
                            UNUserNotificationCenter.current().removePendingNotificationRequests(
                                withIdentifiers: ["payday.tomorrow", "payday.today"]
                            )
                        }
                    }
                )
            )
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            if consent.privacyOptionsRequired {
                Button("Privacy choices") {
                    Task { await consent.presentPrivacyOptions() }
                }
            }

            NavigationLink("Privacy policy") {
                AboutInfoView(page: .privacy)
            }

            Text("Budget records stay on this device. Advertising services may process separate device or ad-related information according to your privacy choices.")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("How Payday Left works") {
                AboutInfoView(page: .howItWorks)
            }

            NavigationLink("Planning disclaimer") {
                AboutInfoView(page: .disclaimer)
            }

            LabeledContent("Version", value: versionText)
        }
    }

    private var activeCycle: PayCycle? {
        cycles.first(where: { !$0.isClosed })
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }

    private func updateScheduleType(_ type: PayScheduleType) {
        settings.scheduleType = type

        if let active = activeCycle {
            settings.anchorPayday = active.nominalEndDate

            if type == .monthly {
                settings.monthlyDay = Calendar.current.component(.day, from: active.nominalEndDate)
            }

            if type == .irregular {
                settings.manualNextPayday = active.endDate
            }
        }

        save()
    }

    private func semiMonthlyRuleBinding(first: Bool) -> Binding<Int> {
        Binding(
            get: {
                if first {
                    return settings.semiMonthlyFirstUseLastDay ? 99 : settings.semiMonthlyFirstDay
                }
                return settings.semiMonthlySecondUseLastDay ? 99 : settings.semiMonthlySecondDay
            },
            set: { value in
                let otherValue: Int
                if first {
                    otherValue = settings.semiMonthlySecondUseLastDay ? 99 : settings.semiMonthlySecondDay
                } else {
                    otherValue = settings.semiMonthlyFirstUseLastDay ? 99 : settings.semiMonthlyFirstDay
                }

                guard value != otherValue else {
                    scheduleError = String(localized: "Choose two different paydays.")
                    return
                }

                if first {
                    settings.semiMonthlyFirstUseLastDay = value == 99
                    if value != 99 { settings.semiMonthlyFirstDay = value }
                } else {
                    settings.semiMonthlySecondUseLastDay = value == 99
                    if value != 99 { settings.semiMonthlySecondDay = value }
                }
                settings.updatedAt = .now
                save()
            }
        )
    }

    private func save() {
        try? modelContext.save()
    }

    private func schedule(_ payday: Date) {
        Task {
            await NotificationManager.shared.reschedulePaydayNotifications(
                for: payday,
                enabled: settings.paydayNotificationsEnabled
            )
        }
    }

    private func resetAll() {
        transactions.forEach(modelContext.delete)
        bills.forEach(modelContext.delete)
        templates.forEach(modelContext.delete)
        cycles.forEach(modelContext.delete)

        settings.onboardingCompleted = false
        settings.defaultPayAmountMinor = 0
        settings.defaultSavingsMinor = 0
        settings.updatedAt = .now

        WidgetSnapshotStore.clear()
        try? modelContext.save()
    }
}
