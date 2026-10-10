import SwiftUI
import SwiftData
import UntilPaydayCore

private struct OnboardingBillDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var amountMinor: Int64
    var dueDate: Date
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsModel]

    @State private var step = 0
    @State private var schedule: PayScheduleType = .biweekly
    @State private var semiMonthlyPreset = 0
    @State private var monthlyDay = 1
    @State private var monthlyUseLastDay = false
    @State private var semiMonthlyCustomFirstDay = 1
    @State private var semiMonthlyCustomSecondDay = 15
    @State private var nextPayday = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var fundsText = ""
    @State private var savingsText = ""
    @State private var isPartial = false
    @State private var draftBills: [OnboardingBillDraft] = []
    @State private var showAddBill = false
    @State private var showReminderPrompt = false
    @State private var createdCycleEnd: Date?
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var settings: AppSettingsModel? {
        settingsRecords.first
    }

    private var currencyCode: String {
        settings?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                Group {
                    switch step {
                    case 0: welcome
                    case 1: paySchedule
                    case 2: currentFunds
                    default: protectMoney
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .sheet(isPresented: $showAddBill) {
            NavigationStack {
                OnboardingAddBillView(
                    currencyCode: currencyCode,
                    latestDueDate: latestBillDate
                ) { draft in
                    draftBills.append(draft)
                }
            }
        }
        .alert(
            "Couldn’t start your pay cycle",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Payday reminders?", isPresented: $showReminderPrompt) {
            Button("Turn on reminders") {
                completeOnboarding(requestReminders: true)
            }
            Button("Not now", role: .cancel) {
                completeOnboarding(requestReminders: false)
            }
        } message: {
            Text("Get a reminder the day before payday and on payday. The app works normally if you say no.")
        }
    }

    private var progressHeader: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation(.snappy) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            Text("\(step + 1) of 4")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            Spacer(minLength: AppSpacing.xxl)

            SurfaceCard(background: AppColor.surface, cornerRadius: AppRadius.hero) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            SectionEyebrow(text: "LEFT UNTIL PAYDAY")
                            Text(MoneyFormatter.string(minorUnits: 132_700, currencyCode: currencyCode))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(AppColor.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                            Text("13")
                                .font(.title.bold())
                                .monospacedDigit()
                                .foregroundStyle(AppColor.safeStrong)
                            Text("days left")
                                .font(.caption)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }

                    Divider().overlay(AppColor.line)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SAFE TODAY")
                                .font(.caption2.weight(.bold))
                                .tracking(0.6)
                                .foregroundStyle(AppColor.textSecondary)
                            Text(MoneyFormatter.string(minorUnits: 10_200, currencyCode: currencyCode))
                                .font(.title2.bold())
                                .monospacedDigit()
                                .foregroundStyle(AppColor.safeStrong)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColor.safe)
                    }
                }
            }

            Text("Make your money\nlast until payday.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("See what’s left, what’s already spoken for, and what you can safely spend today.")
                .font(.title3)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(4)

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppColor.accent)
                Text("No bank connection · No account · No subscription")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            Button("Get started") {
                withAnimation(.snappy) { step = 1 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(AppSpacing.xl)
    }

    private var paySchedule: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                Text("How do you get paid?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Choose the schedule that determines when each pay cycle ends.")
                    .foregroundStyle(AppColor.textSecondary)

                VStack(spacing: AppSpacing.sm) {
                    ForEach(PayScheduleType.allCases) { item in
                        Button {
                            schedule = item
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: scheduleSymbol(item))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(schedule == item ? .white : AppColor.accent)
                                    .frame(width: 36, height: 36)
                                    .background(schedule == item ? AppColor.accent : AppColor.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body.weight(.semibold))
                                    Text(scheduleSubtitle(item))
                                        .font(.caption)
                                        .foregroundStyle(AppColor.textSecondary)
                                }

                                Spacer()

                                Image(systemName: schedule == item ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(schedule == item ? AppColor.accent : AppColor.textSecondary.opacity(0.65))
                            }
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary)
                            .background(schedule == item ? AppColor.accentSoft.opacity(0.60) : AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                    .stroke(schedule == item ? AppColor.accent.opacity(0.55) : AppColor.line, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if schedule == .monthly {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Monthly payday")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)

                        Toggle("Use last day of month", isOn: $monthlyUseLastDay)
                            .tint(AppColor.accent)
                            .padding(AppSpacing.md)
                            .background(AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                        if !monthlyUseLastDay {
                            HStack {
                                Text("Day of month")
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                Picker("Day of month", selection: $monthlyDay) {
                                    ForEach(1...31, id: \.self) { day in
                                        Text("Day \(day)").tag(day)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        }
                    }
                }

                if schedule == .semiMonthly {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Twice-monthly pattern")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)

                        Picker("Twice-monthly pattern", selection: $semiMonthlyPreset) {
                            Text("1st & 15th").tag(0)
                            Text("15th & last day").tag(1)
                            Text("Custom").tag(2)
                        }
                        .pickerStyle(.segmented)

                        if semiMonthlyPreset == 2 {
                            HStack {
                                Picker("First day", selection: $semiMonthlyCustomFirstDay) {
                                    ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                                }
                                Picker("Second day", selection: $semiMonthlyCustomSecondDay) {
                                    ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(AppSpacing.md)
                            .background(AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        }
                    }
                }

                Button("Continue") {
                    if schedule == .semiMonthly,
                       semiMonthlyPreset == 2 {
                        guard semiMonthlyCustomFirstDay != semiMonthlyCustomSecondDay else {
                            errorMessage = String(localized: "Choose two different paydays.")
                            return
                        }
                        guard min(semiMonthlyCustomFirstDay, 28) != min(semiMonthlyCustomSecondDay, 28) else {
                            errorMessage = String(localized: "Choose paydays that stay different in every month.")
                            return
                        }
                    }
                    applyScheduleToSettings()
                    synchronizeNextPaydayForRuleBasedSchedule()
                    withAnimation(.snappy) { step = 2 }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(AppSpacing.xl)
        }
    }

    private var currentFunds: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                Text("Let’s set up this pay cycle.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textPrimary)

                Text(isPartial
                     ? "Enter what you have available from today. You don’t need to rebuild earlier transactions."
                     : "Enter your next payday and the money available for this cycle.")
                    .foregroundStyle(AppColor.textSecondary)

                if schedule == .monthly || schedule == .semiMonthly {
                    SurfaceCard {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                SectionEyebrow(text: "NEXT PAYDAY")
                                Text(nextPayday.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppColor.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundStyle(AppColor.accent)
                        }

                        Text("This date comes from the pay schedule you chose.")
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.top, AppSpacing.xs)
                    }
                } else {
                    SurfaceCard {
                        DatePicker(
                            "Next payday",
                            selection: $nextPayday,
                            in: tomorrow...,
                            displayedComponents: .date
                        )
                    }
                }

                SurfaceCard {
                    Picker(
                        "Currency",
                        selection: Binding(
                            get: { currencyCode },
                            set: { newCode in
                                settings?.currencyCode = newCode.uppercased()
                                settings?.updatedAt = .now
                                try? modelContext.save()
                                fundsText = ""
                                savingsText = ""
                                draftBills.removeAll()
                            }
                        )
                    ) {
                        ForEach(CurrencyMetadata.supportedCodes, id: \.self) { code in
                            Text(CurrencyMetadata.displayName(for: code)).tag(code)
                        }
                    }

                    Text("Choose the currency for this budget. Amounts are never converted automatically.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }

                MoneyEntryField(
                    title: isPartial ? "Available right now" : "Money available",
                    currencyCode: currencyCode,
                    text: $fundsText
                )

                Toggle("I’m already between paydays", isOn: $isPartial)
                    .tint(AppColor.accent)
                    .padding(AppSpacing.lg)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Button("Continue") {
                    guard let amount = MoneyFormatter.parseMinorUnits(fundsText, currencyCode: currencyCode), amount >= 0 else {
                        errorMessage = String(localized: "Enter a valid amount.")
                        return
                    }
                    withAnimation(.snappy) { step = 3 }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(AppSpacing.xl)
        }
    }

    private var protectMoney: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                Text("Protect money before you spend.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Savings and bills are removed before Safe Today is calculated.")
                    .foregroundStyle(AppColor.textSecondary)

                MoneyEntryField(
                    title: "Savings to protect · optional",
                    currencyCode: currencyCode,
                    text: $savingsText
                )

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        SectionEyebrow(text: "UPCOMING BILLS")
                        Spacer()
                        Button("Add bill") { showAddBill = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.accent)
                    }

                    if draftBills.isEmpty {
                        SurfaceCard {
                            Text("No bills added yet. You can skip this and add them later from Plan.")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    } else {
                        SurfaceCard(padding: AppSpacing.md) {
                            VStack(spacing: 0) {
                                ForEach(Array(draftBills.enumerated()), id: \.element.id) { index, bill in
                                    HStack {
                                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                            Text(bill.name)
                                                .foregroundStyle(AppColor.textPrimary)
                                            Text(bill.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                                                .font(.caption)
                                                .foregroundStyle(AppColor.textSecondary)
                                        }
                                        Spacer()
                                        Text(MoneyFormatter.string(minorUnits: bill.amountMinor, currencyCode: currencyCode))
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, AppSpacing.sm)
                                    .contextMenu {
                                        Button("Remove", role: .destructive) {
                                            draftBills.removeAll { $0.id == bill.id }
                                        }
                                    }

                                    if index < draftBills.count - 1 {
                                        Divider().overlay(AppColor.line)
                                    }
                                }
                            }
                        }
                    }
                }

                previewCard

                Button(isCreating ? "Starting…" : "Start my pay cycle") {
                    finish()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isCreating)
            }
            .padding(AppSpacing.xl)
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        if let funds = MoneyFormatter.parseMinorUnits(fundsText, currencyCode: currencyCode) {
            let savings = max(0, MoneyFormatter.parseMinorUnits(savingsText, currencyCode: currencyCode) ?? 0)
            let reserve = MinorUnitMath.sum(
                draftBills
                    .filter { Calendar.current.startOfDay(for: $0.dueDate) < Calendar.current.startOfDay(for: nextPayday) }
                    .map(\.amountMinor)
            )
            let left = MinorUnitMath.subtracting(
                MinorUnitMath.subtracting(funds, savings),
                reserve
            )
            let days = max(1, Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: .now),
                to: Calendar.current.startOfDay(for: nextPayday)
            ).day ?? 1)
            let safe = max(0, left) / Int64(days)

            SurfaceCard(
                background: left >= 0 ? AppColor.safeSoft : AppColor.dangerSoft,
                cornerRadius: AppRadius.hero
            ) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionEyebrow(text: "YOUR PREVIEW")

                    if left >= 0 {
                        Text(MoneyFormatter.string(minorUnits: left, currencyCode: currencyCode))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppColor.textPrimary)
                        HStack {
                            Text("\(days) days")
                                .foregroundStyle(AppColor.textSecondary)
                            Text("·")
                                .foregroundStyle(AppColor.textSecondary)
                            Text("Safe today \(MoneyFormatter.string(minorUnits: safe, currencyCode: currencyCode))")
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.safeStrong)
                        }
                        .font(.subheadline)
                    } else {
                        Text("Short by \(MoneyFormatter.string(minorUnits: safeAbs(left), currencyCode: currencyCode))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppColor.danger)
                        Text("Reduce protected money or review upcoming bills before starting.")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
        }
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private func scheduleSymbol(_ type: PayScheduleType) -> String {
        switch type {
        case .weekly: "calendar"
        case .biweekly: "calendar.badge.clock"
        case .semiMonthly: "calendar.badge.plus"
        case .monthly: "calendar.circle"
        case .irregular: "calendar.badge.questionmark"
        }
    }

    private func scheduleSubtitle(_ type: PayScheduleType) -> String {
        switch type {
        case .weekly: String(localized: "Every 7 days")
        case .biweekly: String(localized: "Every 14 days")
        case .semiMonthly: String(localized: "Two paydays per month")
        case .monthly: String(localized: "Once a month")
        case .irregular: String(localized: "Set the next payday yourself")
        }
    }

    private var latestBillDate: Date {
        let payday = Calendar.current.startOfDay(for: nextPayday)
        return Calendar.current.date(byAdding: .day, value: -1, to: payday) ?? Calendar.current.startOfDay(for: .now)
    }

    private func applyScheduleToSettings() {
        guard let settings else { return }

        settings.scheduleType = schedule

        if schedule == .monthly {
            settings.monthlyDay = monthlyDay
            settings.monthlyUseLastDay = monthlyUseLastDay
        }

        if schedule == .semiMonthly {
            switch semiMonthlyPreset {
            case 0:
                settings.semiMonthlyFirstDay = 1
                settings.semiMonthlyFirstUseLastDay = false
                settings.semiMonthlySecondDay = 15
                settings.semiMonthlySecondUseLastDay = false
            case 1:
                settings.semiMonthlyFirstDay = 15
                settings.semiMonthlyFirstUseLastDay = false
                settings.semiMonthlySecondDay = 31
                settings.semiMonthlySecondUseLastDay = true
            default:
                let ordered = [semiMonthlyCustomFirstDay, semiMonthlyCustomSecondDay].sorted()
                settings.semiMonthlyFirstDay = ordered[0]
                settings.semiMonthlyFirstUseLastDay = false
                settings.semiMonthlySecondDay = ordered[1]
                settings.semiMonthlySecondUseLastDay = false
            }
        }

        settings.updatedAt = .now
        try? modelContext.save()
    }

    private func synchronizeNextPaydayForRuleBasedSchedule() {
        guard let settings, schedule == .monthly || schedule == .semiMonthly else { return }

        do {
            nextPayday = try CycleManager.nextUpcomingPayday(
                settings: settings,
                after: tomorrow
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        guard !isCreating else { return }
        guard let settings,
              let funds = MoneyFormatter.parseMinorUnits(fundsText, currencyCode: currencyCode),
              funds >= 0 else {
            errorMessage = String(localized: "Enter a valid amount.")
            return
        }

        let savings = max(0, MoneyFormatter.parseMinorUnits(savingsText, currencyCode: currencyCode) ?? 0)
        applyScheduleToSettings()
        isCreating = true

        do {
            let cycle = try CycleManager.createInitialCycle(
                settings: settings,
                availableFundsMinor: funds,
                nextPayday: nextPayday,
                savingsMinor: savings,
                isPartial: isPartial,
                completeOnboarding: false,
                context: modelContext
            )

            for draft in draftBills {
                modelContext.insert(BillOccurrence(
                    originalCycleID: cycle.id,
                    nameSnapshot: draft.name,
                    plannedAmountMinor: draft.amountMinor,
                    currencyCode: currencyCode,
                    dueDate: Calendar.current.startOfDay(for: draft.dueDate),
                    nominalDueDate: Calendar.current.startOfDay(for: draft.dueDate)
                ))
            }

            try modelContext.save()
            createdCycleEnd = cycle.endDate
            showReminderPrompt = true
        } catch {
            isCreating = false
            errorMessage = error.localizedDescription
        }
    }

    private func completeOnboarding(requestReminders: Bool) {
        guard let settings else { return }

        if requestReminders {
            Task { @MainActor in
                let granted = await NotificationManager.shared.requestAuthorization()
                settings.paydayNotificationsEnabled = granted
                settings.onboardingCompleted = true
                settings.updatedAt = .now
                try? modelContext.save()

                if granted, let createdCycleEnd {
                    await NotificationManager.shared.reschedulePaydayNotifications(
                        for: createdCycleEnd,
                        enabled: true
                    )
                }
            }
        } else {
            settings.paydayNotificationsEnabled = false
            settings.onboardingCompleted = true
            settings.updatedAt = .now
            try? modelContext.save()
        }
    }

    private func safeAbs(_ value: Int64) -> Int64 {
        value == .min ? .max : abs(value)
    }
}

private struct OnboardingAddBillView: View {
    @Environment(\.dismiss) private var dismiss

    let currencyCode: String
    let latestDueDate: Date
    let onSave: (OnboardingBillDraft) -> Void

    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Bill") {
                TextField("Name", text: $name)

                MoneyEntryField(
                    title: "Planned amount",
                    currencyCode: currencyCode,
                    text: $amountText
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                DatePicker(
                    "Due date",
                    selection: $dueDate,
                    in: dateRange,
                    displayedComponents: .date
                )
            }

            Section {
                Text("Only bills due before the next payday are reserved in this pay cycle.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .navigationTitle("Add bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            dueDate = min(max(Calendar.current.startOfDay(for: .now), dateRange.lowerBound), dateRange.upperBound)
        }
        .alert(
            "Check this bill",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var dateRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: .now)
        let end = max(start, Calendar.current.startOfDay(for: latestDueDate))
        return start...end
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "Give the bill a name.")
            return
        }

        guard let amount = MoneyFormatter.parseMinorUnits(amountText, currencyCode: currencyCode), amount > 0 else {
            errorMessage = String(localized: "Enter an amount greater than zero.")
            return
        }

        onSave(OnboardingBillDraft(
            id: UUID(),
            name: trimmed,
            amountMinor: amount,
            dueDate: Calendar.current.startOfDay(for: dueDate)
        ))
        dismiss()
    }
}
