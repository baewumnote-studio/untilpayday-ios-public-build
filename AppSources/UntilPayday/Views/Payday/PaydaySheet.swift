import SwiftUI
import SwiftData
import UntilPaydayCore

struct PaydaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let cycle: PayCycle
    let settings: AppSettingsModel
    let templates: [BillTemplate]
    let occurrences: [BillOccurrence]

    @Query private var transactions: [BudgetTransaction]
    @Query private var allBills: [BillOccurrence]

    @State private var incomeText = ""
    @State private var savingsText = ""
    @State private var rolloverText = ""
    @State private var carryRemainder = true
    @State private var irregularNextPayday = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var errorMessage: String?

    private var currentSnapshot: CycleBudgetViewModel {
        BudgetSnapshotFactory.make(
            cycle: cycle,
            transactions: transactions,
            bills: allBills,
            now: cycle.endDate
        )
    }

    private var immediateFollowingPayday: Date? {
        guard settings.scheduleType != .irregular else { return nil }
        let reference = Calendar.current.date(byAdding: .day, value: 1, to: cycle.nominalEndDate) ?? cycle.endDate
        return try? CycleManager.nextUpcomingPayday(settings: settings, after: reference)
    }

    private var isMultiCycleGap: Bool {
        guard let immediateFollowingPayday else { return false }
        return Calendar.current.startOfDay(for: immediateFollowingPayday)
            <= Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isMultiCycleGap {
                    freshStartContent
                } else {
                    normalPaydayContent
                }
            }
            .background(AppColor.background)
            .navigationTitle(isMultiCycleGap ? "Start fresh" : "New pay cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { seedValues() }
            .alert(
                "Couldn’t start the new cycle",
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
    }

    private var normalPaydayContent: some View {
        LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
            intro
            lastCycleCard
            newPaycheckCard
            carryoverCard
            savingsCard
            nextPaydayCard

            Button("Start new pay cycle") {
                startNormalCycle()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("startNewPayCycleButton")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xxxl)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Payday is here")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)

            Text("Review what’s carrying forward, then start the next cycle.")
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var lastCycleCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionEyebrow(text: "LAST CYCLE")

                summaryRow(
                    label: currentSnapshot.snapshot.leftUntilPaydayMinor >= 0 ? "Left over" : "Short by",
                    value: MoneyFormatter.string(
                        minorUnits: safeAbs(currentSnapshot.snapshot.leftUntilPaydayMinor),
                        currencyCode: cycle.currencyCode
                    ),
                    emphasized: true,
                    tint: currentSnapshot.snapshot.leftUntilPaydayMinor >= 0 ? AppColor.safeStrong : AppColor.danger
                )

                if currentSnapshot.pendingBillsMinor > 0 {
                    Divider().overlay(AppColor.line)

                    summaryRow(
                        label: "Bills still reserved",
                        value: MoneyFormatter.string(
                            minorUnits: currentSnapshot.pendingBillsMinor,
                            currencyCode: cycle.currencyCode
                        )
                    )

                    Text("Unpaid bills remain reserved in the next cycle until you pay or skip them.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }

    private var newPaycheckCard: some View {
        SurfaceCard(background: AppColor.accentSoft) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SectionEyebrow(text: "NEW PAYCHECK")
                LargeMoneyInput(currencyCode: settings.currencyCode, text: $incomeText)
            }
        }
    }

    private var carryoverCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Carry over last balance", isOn: $carryRemainder)
                    .tint(AppColor.accent)

                if carryRemainder {
                    summaryRow(
                        label: "Carry over",
                        value: MoneyFormatter.string(
                            minorUnits: MinorUnitMath.adding(currentSnapshot.snapshot.leftUntilPaydayMinor, currentSnapshot.pendingBillsMinor),
                            currencyCode: cycle.currencyCode
                        ),
                        emphasized: true
                    )

                    Text("This is the cash still on hand. Unpaid bills are reserved again once in the new cycle.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    Divider().overlay(AppColor.line)

                    Text("Custom carryover")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)

                    LargeMoneyInput(currencyCode: settings.currencyCode, text: $rolloverText)
                }
            }
        }
    }

    private var savingsCard: some View {
        SurfaceCard(background: AppColor.safeSoft) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SectionEyebrow(text: "PROTECT FOR SAVINGS")
                LargeMoneyInput(currencyCode: settings.currencyCode, text: $savingsText)
            }
        }
    }

    @ViewBuilder
    private var nextPaydayCard: some View {
        if settings.scheduleType == .irregular {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionEyebrow(text: "NEXT PAYDAY")
                    DatePicker(
                        "Next payday",
                        selection: $irregularNextPayday,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
        } else if let next = predictedNextPayday {
            SurfaceCard {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        SectionEyebrow(text: "NEXT PAYDAY")
                        Text(next.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(AppColor.accent)
                }
            }
        }
    }

    private var predictedNextPayday: Date? {
        let reference = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: cycle.nominalEndDate
        ) ?? cycle.endDate
        return try? CycleManager.nextUpcomingPayday(settings: settings, after: reference)
    }

    private var freshStartContent: some View {
        LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("A few paydays passed")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.textPrimary)

                Text("We won’t invent missing history. Start from what you actually have available today.")
                    .foregroundStyle(AppColor.textSecondary)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    SectionEyebrow(text: "MONEY AVAILABLE NOW")
                    LargeMoneyInput(currencyCode: settings.currencyCode, text: $incomeText)

                    if currentSnapshot.pendingBillsMinor > 0 {
                        Text("Older unpaid bills are still reserved from this amount.")
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }

            savingsCard
            freshNextPaydayCard

            Button("Start fresh from today") {
                startFresh()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("startFreshPayCycleButton")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xxxl)
    }

    @ViewBuilder
    private var freshNextPaydayCard: some View {
        if settings.scheduleType == .irregular {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionEyebrow(text: "NEXT PAYDAY")
                    DatePicker(
                        "Next payday",
                        selection: $irregularNextPayday,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
        } else if let upcoming = try? nextUpcomingAfterToday() {
            SurfaceCard {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        SectionEyebrow(text: "NEXT PAYDAY")
                        Text(upcoming.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(AppColor.accent)
                }
            }
        }
    }

    private func summaryRow(
        label: String,
        value: String,
        emphasized: Bool = false,
        tint: Color = AppColor.textPrimary
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(emphasized ? AppColor.textPrimary : AppColor.textSecondary)
                .font(emphasized ? .body.weight(.semibold) : .subheadline)
            Spacer()
            Text(value)
                .font(emphasized ? .body.weight(.bold) : .subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    private func seedValues() {
        incomeText = decimalInput(settings.defaultPayAmountMinor)
        savingsText = decimalInput(settings.defaultSavingsMinor)
        rolloverText = decimalInput(
            MinorUnitMath.adding(
                currentSnapshot.snapshot.leftUntilPaydayMinor,
                currentSnapshot.pendingBillsMinor
            )
        )
    }

    private func decimalInput(_ minor: Int64) -> String {
        MoneyFormatter.inputString(
            minorUnits: minor,
            currencyCode: settings.currencyCode
        )
    }

    private func parsedBaseValues() -> (Int64, Int64)? {
        guard
            let income = MoneyFormatter.parseMinorUnits(
                incomeText,
                currencyCode: settings.currencyCode
            ), income >= 0,
            let savings = MoneyFormatter.parseMinorUnits(
                savingsText,
                currencyCode: settings.currencyCode
            ), savings >= 0
        else {
            errorMessage = String(localized: "Check the available money and savings amounts.")
            return nil
        }
        return (income, savings)
    }

    private func startNormalCycle() {
        guard let (income, savings) = parsedBaseValues() else { return }

        let rollover: Int64
        if carryRemainder {
            // Carry actual cash-on-hand. Pending bills are still present and therefore
            // become reserved exactly once in the new cycle.
            rollover = MinorUnitMath.adding(
                currentSnapshot.snapshot.leftUntilPaydayMinor,
                currentSnapshot.pendingBillsMinor
            )
        } else {
            guard let parsed = MoneyFormatter.parseMinorUnits(
                rolloverText,
                currencyCode: settings.currencyCode
            ) else {
                errorMessage = String(localized: "Check the carryover amount.")
                return
            }
            rollover = parsed
        }

        do {
            let next = try CycleManager.startNextCycle(
                from: cycle,
                settings: settings,
                incomeMinor: income,
                savingsMinor: savings,
                rolloverMinor: rollover,
                irregularNextPayday: settings.scheduleType == .irregular ? irregularNextPayday : nil,
                templates: templates,
                existingOccurrences: occurrences,
                transactions: transactions,
                context: modelContext
            )
            afterStart(next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startFresh() {
        guard let (funds, savings) = parsedBaseValues() else { return }

        do {
            let nextPayday = settings.scheduleType == .irregular
                ? irregularNextPayday
                : try nextUpcomingAfterToday()

            let next = try CycleManager.closeAndStartFreshAfterGap(
                oldCycle: cycle,
                settings: settings,
                currentFundsMinor: funds,
                nextPayday: nextPayday,
                savingsMinor: savings,
                transactions: transactions,
                bills: allBills,
                context: modelContext
            )

            BillOccurrenceEngine.ensureOccurrences(
                for: next,
                templates: templates,
                existing: occurrences,
                context: modelContext
            )

            afterStart(next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nextUpcomingAfterToday() throws -> Date {
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: .now)
        ) ?? .now

        return try CycleManager.nextUpcomingPayday(
            settings: settings,
            after: tomorrow
        )
    }

    private func afterStart(_ next: PayCycle) {
        Task {
            await NotificationManager.shared.reschedulePaydayNotifications(
                for: next.endDate,
                enabled: settings.paydayNotificationsEnabled
            )
        }

        dismiss()
        AdManager.shared.presentIfEligible(trigger: .newPayCycle)
    }

    private func safeAbs(_ value: Int64) -> Int64 {
        value == .min ? .max : abs(value)
    }
}
